#!/usr/bin/env python3
"""Rebuild the app's sounds from the original recordings.

    python scripts/sounds/build.py [--only key,key] [--src-dir DIR] [--out DIR]
                                   [--export-wav DIR] [--check]

Per sound: decode the original, resample to 44.1 kHz, trim quiet head/tail, cap and bake a
seamless loop, set the level by the sound's rule, then close the loop: encode with
libvorbis, decode with ffmpeg, measure, adjust, until the DECODED file is on target.
Writes the .ogg files and levels.json (the record check.py verifies against).

Without --out the files go to assets/sounds and levels.json to scripts/sounds/levels.json.
With --out DIR both go to DIR (files at DIR/<category>/<name>.ogg).
"""
import argparse
import json
import statistics
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path

import numpy as np
import soundfile as sf

sys.path.insert(0, str(Path(__file__).resolve().parent))

from lib import codec, dsp, measure, sources, synth  # noqa: E402

REPO_ROOT = sources.REPO_ROOT
DEFAULT_SOUNDS_DIR = REPO_ROOT / "assets" / "sounds"
DEFAULT_LEVELS = sources.SOUNDS_DIR / "levels.json"
SDR_WARN_DB = 12.0
LEVEL_TOL_LU = 0.25      # closed loop aims inside half of the +-0.5 LU gate
FFMPEG_AGREE_LU = 0.15   # python measure vs ffmpeg ebur128 on the final file
MAX_ITERATIONS = 8


class BuildError(RuntimeError):
    pass


@dataclass
class Processed:
    path: Path
    lufs: float
    tp: float
    median_st: float
    N: int
    rate: int
    channels: int
    bytes: int
    sha256: str
    q: int
    iterations: int
    sdr_db: float
    gain_db: float
    ceiling_db: float


def process_signal(x, rate, *, rule, target, q, ceiling_db, tmp_dir, reference_st=None,
                   offset_db=0.0, out_path=None, max_iter=MAX_ITERATIONS, tol=LEVEL_TOL_LU, log=None):
    """Level `x` by `rule` and encode it, closing the loop on the decoded output.

    rule 'integrated' / 'binaural': decoded integrated LUFS -> `target`.
    rule 'body': decoded median short-term loudness -> reference_st + offset_db.
    The true-peak ceiling is lowered if the decoded file ends up above `ceiling_db`.
    Returns a Processed; raises BuildError if it does not converge in `max_iter`."""
    import hashlib

    x = np.asarray(x, dtype=np.float64)
    out_path = Path(out_path) if out_path else Path(tmp_dir) / "out.ogg"
    out_path.parent.mkdir(parents=True, exist_ok=True)

    if rule == "body":
        if reference_st is None:
            raise ValueError("body rule needs reference_st")
        goal = reference_st + offset_db
        g_db = goal - measure.median_short_term(x, rate)
    else:
        goal = target
        g_db = goal - measure.lufs(x, rate)

    ceil = ceiling_db
    history = []  # (g_db, error) pairs for the secant step
    sdr = None
    for it in range(1, max_iter + 1):
        y, info = dsp.apply_gain_limited(x, 10 ** (g_db / 20), rate, ceil)
        sdr = info.sdr_db
        codec.encode_vorbis(y, rate, q, out_path)
        dec, dec_rate = codec.decode(out_path)
        got_lufs = measure.lufs(dec, dec_rate)
        got_st = measure.median_short_term(dec, dec_rate)
        ff_lufs, ff_tp = measure.ffmpeg_loudness(out_path)
        # gate on the higher of the python and ffmpeg ebur128 true peaks (they differ by a
        # few tenths of a dB on spiky material)
        got_tp = max(measure.true_peak_db(dec, dec_rate), ff_tp)
        err = (got_st if rule == "body" else got_lufs) - goal
        level_ok = abs(err) <= tol
        tp_ok = got_tp <= ceiling_db
        if log:
            log(f"  it {it}: gain {g_db:+.2f} dB, ceiling {ceil:+.2f}, LUFS {got_lufs:.2f}, "
                f"median ST {got_st:.2f}, TP {got_tp:.2f}, error {err:+.2f}, "
                f"SDR {'-' if sdr is None else format(sdr, '.1f')}")
        if level_ok and tp_ok:
            if abs(ff_lufs - got_lufs) > FFMPEG_AGREE_LU:
                raise BuildError(f"python LUFS {got_lufs:.2f} vs ffmpeg ebur128 {ff_lufs:.2f}")
            data = out_path.read_bytes()
            return Processed(
                path=out_path, lufs=got_lufs, tp=got_tp, median_st=got_st,
                N=int(dec.shape[0]), rate=int(dec_rate),
                channels=1 if dec.ndim == 1 else int(dec.shape[1]),
                bytes=len(data), sha256=hashlib.sha256(data).hexdigest(), q=q, iterations=it,
                sdr_db=sdr, gain_db=g_db, ceiling_db=ceil)
        if not tp_ok:
            ceil -= (got_tp - ceiling_db) * (1.0 if it == 1 else 1.6) + 0.1
        history.append((g_db, err))
        if not level_ok:
            if len(history) >= 2 and abs(history[-1][0] - history[-2][0]) > 1e-9:
                (g0, e0), (g1, e1) = history[-2], history[-1]
                slope = (e1 - e0) / (g1 - g0)
                step = -err / slope if 0.2 < slope < 1.5 else -err
            else:
                step = -err
            g_db += step
    raise BuildError(f"no convergence in {max_iter} iterations (last error {err:+.2f} dB, "
                     f"TP {got_tp:+.2f} dBTP, gain {g_db:+.2f} dB)")


# --- per-sound preparation ---------------------------------------------------------------

def prepare_signal(row, meta, src_dir=None, cache_dir=None):
    """The sound before level and encoding: decoded, 44.1 kHz, trimmed, loop baked.
    Returns (x, rate, source_sha256 or None)."""
    rate = meta["sample_rate"]
    kind = row["source"].split(":", 1)[0]
    if kind == "synth":
        name, sp = row["source"].split(":", 1)[1], row["synth"]
        if name in ("green", "brown", "pink", "white"):
            return synth.noise(sp["shape"], sp["seed"], rate, sp["seconds"]), rate, None
        if name == "binaural":
            return synth.binaural(sp["left_hz"], sp["right_hz"], sp["seconds"], rate), rate, None
        raise BuildError(f"{row['key']}: unknown synth source {name}")

    data = sources.fetch_original(row, meta, src_dir, cache_dir)
    suffix = Path(row["source"].split(":")[-1]).suffix
    x, src_rate = sources.decode_original(data, suffix, cache_dir)
    if x.ndim == 2 and x.shape[1] == 1:
        x = x[:, 0]
    if x.ndim == 2 and dsp.is_dual_mono(x):
        x = x.mean(axis=1)
    x = dsp.resample(x, src_rate, rate)
    src_sha = row.get("sha256")
    if "loop_start_s" in row or "loop_end_s" in row:
        a = int(round(row.get("loop_start_s", 0.0) * rate))
        b = int(round(row["loop_end_s"] * rate)) if "loop_end_s" in row else len(x)
        seg = x[a:b]
    else:
        seg = dsp.trim_quiet(x, rate)
    seg = seg[:int(round(row["cap_s"] * rate))]
    xfade = row.get("xfade_s", 2.0 if len(seg) / rate >= 15.0 else 0.5)
    length = min(int(round(xfade * rate)), len(seg) // 4)
    return dsp.bake_loop(seg, length), rate, src_sha


def target_for(row, meta):
    return meta["binaural_lufs"] if row["rule"] == "binaural" else meta["target_lufs"]


def compute_reference(manifest, src_dir=None, cache_dir=None, log=print):
    """R: median, over the integrated-rule sounds at their target, of their median
    short-term loudness. Measured on the processed signals before encoding."""
    meta = manifest["meta"]
    vals = []
    for row in manifest["sound"]:
        if row["rule"] != "integrated":
            continue
        x, rate, _ = prepare_signal(row, meta, src_dir, cache_dir)
        shift = target_for(row, meta) - measure.lufs(x, rate)
        vals.append(measure.median_short_term(x, rate) + shift)
    r = statistics.median(vals)
    log(f"reference R (median of {len(vals)} integrated-rule sounds' median short-term) "
        f"= {r:.2f} LUFS")
    return r


def build_one(row, manifest, reference, out_dir, src_dir, cache_dir, tmp_dir, wav_dir=None, log=None):
    meta = manifest["meta"]
    x, rate, src_sha = prepare_signal(row, meta, src_dir, cache_dir)
    rel = Path(row["asset"]).relative_to("assets/sounds")
    res = process_signal(
        x, rate, rule=row["rule"], target=target_for(row, meta), q=row["q"],
        ceiling_db=meta["true_peak_ceiling_dbtp"], tmp_dir=tmp_dir,
        reference_st=reference, offset_db=row["level_offset_db"], out_path=Path(out_dir) / rel, log=log)
    if wav_dir:
        dec, r = codec.decode(res.path)
        Path(wav_dir).mkdir(parents=True, exist_ok=True)
        sf.write(Path(wav_dir) / f"{row['key']}.wav", dec, r, subtype="FLOAT")
    is_body = row["rule"] == "body"
    target = round(res.lufs, 2) if is_body else target_for(row, meta)  # body: published, measured
    levels = {
        "key": row["key"],
        "path": rel.as_posix(),
        "rule": row["rule"],
        "T": target,
        "lufs": round(res.lufs, 3),
        "tp": round(res.tp, 3),
        "median_st": round(res.median_st, 3),
        "offset_db": row["level_offset_db"],
        "N": res.N,
        "rate": res.rate,
        "channels": res.channels,
        "bytes": res.bytes,
        "sha256": res.sha256,
        "q": res.q,
        "iterations": res.iterations,
        "sdr_db": None if res.sdr_db is None else round(res.sdr_db, 2),
        "gain_db": round(res.gain_db, 3),
        "max_quiet_s": row["max_quiet_s"],
        "loop": {k: row[k] for k in ("loop_start_s", "loop_end_s", "xfade_s", "cap_s") if k in row},
        "source_sha256": src_sha,
    }
    return levels, res


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawTextHelpFormatter)
    ap.add_argument("--only", help="comma-separated sound keys (default: all 48)")
    ap.add_argument("--src-dir", help="folder with cached Moodist originals "
                                      "(<category>__<name>.<ext>), verified by sha256")
    ap.add_argument("--out", help="output folder (default: assets/sounds + scripts/sounds/levels.json)")
    ap.add_argument("--export-wav", help="also write the decoded result of each sound as float WAV here")
    ap.add_argument("-v", "--verbose", action="store_true", help="print every closed-loop iteration")
    ap.add_argument("--check", action="store_true", help="do not build; run check.py on the output")
    args = ap.parse_args(argv)

    out_dir = Path(args.out) if args.out else DEFAULT_SOUNDS_DIR
    levels_path = (out_dir / "levels.json") if args.out else DEFAULT_LEVELS

    if args.check:
        import check
        return check.main([str(out_dir)] if args.out else [])

    manifest = sources.load_manifest()
    rows = manifest["sound"]
    keys = [r["key"] for r in rows]
    if args.only:
        wanted = [k.strip() for k in args.only.split(",") if k.strip()]
        unknown = sorted(set(wanted) - set(keys))
        if unknown:
            print(f"unknown sound keys: {', '.join(unknown)}", file=sys.stderr)
            return 2
        rows = [r for r in rows if r["key"] in wanted]

    codec.assert_libvorbis()
    info = codec.ffmpeg_info()
    cache_dir = sources.DEFAULT_CACHE
    reference = None
    if any(r["rule"] == "body" for r in rows):
        reference = compute_reference(manifest, args.src_dir, cache_dir)

    existing = {}
    if levels_path.exists():
        old = json.loads(levels_path.read_text(encoding="utf-8"))
        existing = {r["key"]: r for r in old.get("sounds", [])}
        if reference is None:
            reference = old.get("header", {}).get("R")

    new_rows = {}
    with tempfile.TemporaryDirectory() as td:
        for row in rows:
            levels, res = build_one(row, manifest, reference, out_dir, args.src_dir, cache_dir,
                                    td, args.export_wav, log=print if args.verbose else None)
            new_rows[row["key"]] = levels
            sdr = "" if res.sdr_db is None else f" sdr {res.sdr_db:.1f} dB"
            warn = "  WARNING: SDR < 12 dB" if res.sdr_db is not None and res.sdr_db < SDR_WARN_DB else ""
            print(f"{row['key']:<18} {row['rule']:<10} {res.lufs:7.2f} LUFS  tp {res.tp:6.2f}  "
                  f"{res.bytes:>9,} B  {res.iterations} it{sdr}{warn}", flush=True)

    merged = {**existing, **new_rows}
    ordered = [merged[k] for k in keys if k in merged]
    doc = {
        "header": {
            "ffmpeg_version": info["ffmpeg_version"],
            "libvorbis_version": info["libvorbis_version"],
            "moodist_commit": manifest["meta"]["moodist_commit"],
            "sample_rate": manifest["meta"]["sample_rate"],
            "R": None if reference is None else round(reference, 3),
            "budget_bytes": manifest["meta"]["size_budget_bytes"],
            "partial": len(ordered) < len(keys),
        },
        "sounds": ordered,
    }
    levels_path.parent.mkdir(parents=True, exist_ok=True)
    levels_path.write_text(json.dumps(doc, indent=1) + "\n", encoding="utf-8", newline="\n")
    total = sum(r["bytes"] for r in ordered)
    print(f"{len(new_rows)} built, {len(ordered)}/{len(keys)} recorded in {levels_path}; "
          f"total {total:,} bytes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
