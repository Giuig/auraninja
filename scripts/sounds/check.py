#!/usr/bin/env python3
"""Check the shipped sound assets. Exit code 1 if anything fails.

    python scripts/sounds/check.py                    # assets/sounds vs scripts/sounds/levels.json
    python scripts/sounds/check.py DIR                # a build.py --out DIR (DIR/levels.json)
    python scripts/sounds/check.py --against-today    # assets/sounds as they are, no levels.json

Every file is decoded with ffmpeg and measured. Checks (the name is what a failure reports):
  length      decoded samples == N, rate 44100, channel count as recorded
  codec       the stream is Vorbis
  gap         no run of quiet 250 ms windows >= max_quiet_s; first/last window not quiet
  seam        played twice: 20 ms RMS step at the wrap <= max(1 dB, 2x the file's median
              step), and click ratio |x[0]-x[-1]| / p99.9|dx| <= 2.5 (lib/measure.CLICK_LIMIT)
  loudness    integrated LUFS within T +-0.5 LU (body-rule sounds: median short-term within
              R + offset +-0.5 as well)
  true_peak   <= -1.0 dBTP
  separation  binaural: each tone's own channel vs the other >= 40 dB
  staleness   file bytes and sha256 equal levels.json
  missing     a row without a file
  size        total bytes <= budget (16,000,000)
  coverage    every pubspec sound asset has a row (full builds only)
  measure     the python measurement disagrees with ffmpeg's ebur128 (should never happen)

Mono files are measured as played on both channels (see lib/measure.py MONO_CONVENTION).
"""
import argparse
import json
import re
import sys
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass, field
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from lib import codec, measure, sources  # noqa: E402

REPO_ROOT = sources.REPO_ROOT
DEFAULT_SOUNDS_DIR = REPO_ROOT / "assets" / "sounds"
DEFAULT_LEVELS = sources.SOUNDS_DIR / "levels.json"
CROSSCHECK_LU = 0.2  # python vs ffmpeg ebur128 (ffmpeg prints one decimal)


@dataclass
class Finding:
    key: str
    check: str
    message: str = ""

    def __str__(self):
        return f"FAIL {self.check:<10} {self.key}: {self.message}"


@dataclass
class RowReport:
    key: str
    rule: str
    T: float = None
    lufs: float = None
    tp: float = None
    median_st: float = None
    N: int = None
    rate: int = None
    channels: int = None
    bytes: int = 0
    seam_step: float = None
    seam_limit: float = None
    click: float = None
    quiet_run: float = None
    separation: float = None
    failed: list = field(default_factory=list)


@dataclass
class CheckResult:
    failures: list = field(default_factory=list)
    reports: list = field(default_factory=list)
    notes: list = field(default_factory=list)
    mode: str = "levels"

    @property
    def ok(self):
        return not self.failures


@dataclass
class Options:
    budget_bytes: int = None
    crosscheck: bool = True
    skip: frozenset = frozenset()
    jobs: int = 4


def pubspec_sound_assets():
    text = (REPO_ROOT / "pubspec.yaml").read_text(encoding="utf-8")
    return sorted(set(re.findall(r"^\s*-\s*(assets/sounds/\S+\.ogg)\s*$", text, re.M)))


def check_row(row, sounds_dir, meta, header, opts):
    """Measure one file and compare it with its row. Returns (RowReport, [Finding])."""
    key = row["key"]
    rep = RowReport(key=key, rule=row["rule"], T=row.get("T"))
    fails = []

    def fail(check, msg):
        if check not in opts.skip:
            fails.append(Finding(key, check, msg))
            rep.failed.append(check)

    path = Path(sounds_dir) / row["path"]
    if not path.exists():
        fail("missing", f"{path} does not exist")
        return rep, fails
    raw = path.read_bytes()
    rep.bytes = len(raw)

    if "bytes" in row and (len(raw) != row["bytes"] or
                           sources.sha256_hex(raw) != row.get("sha256")):
        fail("staleness", "file differs from levels.json (bytes or sha256); rebuild it")

    info = codec.probe(path)
    if info["codec"] != "vorbis":
        fail("codec", f"codec is {info['codec']}, not vorbis")
    dec, rate = measure.read_audio(path)
    n = dec.shape[0]
    channels = 1 if dec.ndim == 1 else dec.shape[1]
    rep.N, rep.rate, rep.channels = n, rate, channels
    if "N" in row and n != row["N"]:
        fail("length", f"decoded {n} samples, recorded {row['N']}")
    if "N" in row and rate != meta["sample_rate"]:
        fail("length", f"rate {rate}, expected {meta['sample_rate']}")
    if "channels" in row and channels != row["channels"]:
        fail("length", f"{channels} channels, recorded {row['channels']}")

    # gaps
    rep.quiet_run = measure.max_quiet_run_s(dec, rate)
    max_quiet = row.get("max_quiet_s", 2.0)
    if rep.quiet_run >= max_quiet:
        fail("gap", f"{rep.quiet_run:.2f} s quiet run (limit {max_quiet} s)")
    first, last = measure.edge_quiet(dec, rate)
    if first or last:
        fail("gap", f"{'first' if first else 'last'} 250 ms window is quiet (trim it)")

    # seam
    m = measure.seam_metrics(dec, rate)
    rep.seam_step, rep.seam_limit, rep.click = m.step_db, m.limit_db, m.click_ratio
    if m.step_db > m.limit_db:
        fail("seam", f"{m.step_db:.2f} dB level step at the wrap (limit {m.limit_db:.2f} dB)")
    if m.click_ratio > measure.CLICK_LIMIT:
        fail("seam", f"click ratio {m.click_ratio:.2f} at the wrap (limit {measure.CLICK_LIMIT})")

    # loudness and true peak
    rep.lufs = measure.lufs(dec, rate)
    rep.tp = measure.true_peak_db(dec, rate)
    rep.median_st = measure.median_short_term(dec, rate)
    tol = meta["tolerance_lu"]
    if row.get("T") is not None and abs(rep.lufs - row["T"]) > tol:
        fail("loudness", f"{rep.lufs:.2f} LUFS vs target {row['T']:.2f} "
                         f"({rep.lufs - row['T']:+.2f} LU, limit +-{tol})")
    if row["rule"] == "body":
        ref = header.get("R")
        if ref is None:
            fail("loudness", "body rule but levels.json has no reference R")
        else:
            goal = ref + row.get("offset_db", 0.0)
            if abs(rep.median_st - goal) > tol:
                fail("loudness", f"median short-term {rep.median_st:.2f} vs R+offset {goal:.2f} "
                                 f"({rep.median_st - goal:+.2f} LU, limit +-{tol})")
    if opts.crosscheck:
        ff_lufs, ff_tp = measure.ffmpeg_loudness(path)
        if abs(ff_lufs - rep.lufs) > CROSSCHECK_LU:
            fail("measure", f"python {rep.lufs:.2f} LUFS vs ffmpeg ebur128 {ff_lufs:.1f}")
        # ffmpeg's resampler can read a few tenths of a dB higher on spiky material: gate on
        # the higher of the two so the file is under the ceiling in both.
        rep.tp = max(rep.tp, ff_tp)
    ceiling = meta["true_peak_ceiling_dbtp"]
    if rep.tp > ceiling:
        fail("true_peak", f"{rep.tp:.2f} dBTP (ceiling {ceiling})")

    # binaural separation
    if row["rule"] == "binaural" and channels == 2:
        rep.separation = measure.binaural_separation_db(dec, rate)
        floor = meta["binaural_min_separation_db"]
        if rep.separation < floor:
            fail("separation", f"{rep.separation:.1f} dB channel separation (min {floor})")
    return rep, fails


def _run(rows, sounds_dir, meta, header, opts, mode):
    result = CheckResult(mode=mode)
    with ThreadPoolExecutor(max_workers=opts.jobs) as pool:
        outs = list(pool.map(lambda r: check_row(r, sounds_dir, meta, header, opts), rows))
    for rep, fails in outs:
        result.reports.append(rep)
        result.failures.extend(fails)
    budget = opts.budget_bytes or header.get("budget_bytes") or meta["size_budget_bytes"]
    total = sum(r.bytes for r in result.reports)
    result.notes.append(f"total {total:,} bytes (budget {budget:,})")
    result.notes.append("loudness: mono files are measured as played on both channels "
                        "(+3.01 dB vs a 1-channel BS.1770 reading; see lib/measure.MONO_CONVENTION)")
    if total > budget and "size" not in opts.skip:
        result.failures.append(Finding("*", "size", f"{total:,} bytes > budget {budget:,}"))
    return result


def _parse(extra):
    ap = argparse.ArgumentParser(prog="check.py", description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("dir", nargs="?", help="a build.py --out folder (default: the repo's assets)")
    ap.add_argument("--against-today", action="store_true",
                    help="assume T=-20 (binaurals -24); skip length/staleness; no levels.json needed")
    ap.add_argument("--levels", help="levels.json to compare with (default: DIR/levels.json, "
                                     "or scripts/sounds/levels.json without DIR)")
    ap.add_argument("--budget-bytes", type=int, help="override the size budget")
    ap.add_argument("--no-crosscheck", action="store_true", help="skip the ffmpeg ebur128 cross-check")
    ap.add_argument("--jobs", type=int, default=4)
    return ap.parse_args(extra)


def _options(args, skip=()):
    return Options(budget_bytes=args.budget_bytes, crosscheck=not args.no_crosscheck,
                   skip=frozenset(skip), jobs=args.jobs)


def run_check(directory, *extra):
    """Check `directory` (sounds + levels.json) against levels.json."""
    args = _parse([str(directory), *extra])
    return _check_levels(args)


def _check_levels(args):
    meta = sources.load_manifest()["meta"]
    if args.dir:
        sounds_dir = Path(args.dir)
        levels_path = Path(args.levels) if args.levels else sounds_dir / "levels.json"
    else:
        sounds_dir = DEFAULT_SOUNDS_DIR
        levels_path = Path(args.levels) if args.levels else DEFAULT_LEVELS
    if not levels_path.exists():
        raise SystemExit(f"{levels_path} not found: build the sounds first "
                         f"(scripts/sounds/build.py), or use --against-today")
    doc = json.loads(levels_path.read_text(encoding="utf-8"))
    header, rows = doc.get("header", {}), doc["sounds"]
    result = _run(rows, sounds_dir, meta, header, _options(args), "levels")
    if not header.get("partial", False):
        have = {"assets/sounds/" + r["path"] for r in rows}
        want = set(pubspec_sound_assets())
        for a in sorted(want - have):
            result.failures.append(Finding(a, "coverage", "pubspec sound asset has no row"))
        for a in sorted(have - want):
            result.failures.append(Finding(a, "coverage", "row for an asset pubspec does not list"))
    else:
        result.notes.append("partial build: coverage not checked")
    return result


def run_check_against_today(directory=None, *extra):
    """Measure the assets as they are, with no levels.json: T = -20 (binaurals -24)."""
    args = _parse(([str(directory)] if directory else []) + list(extra))
    return _check_today(args)


def _check_today(args):
    meta = sources.load_manifest()["meta"]
    sounds_dir = Path(args.dir) if args.dir else DEFAULT_SOUNDS_DIR
    rows = []
    for p in sorted(sounds_dir.rglob("*.ogg")):
        rel = p.relative_to(sounds_dir)
        binaural = "binaural" in rel.parts
        rows.append({
            "key": p.stem, "path": rel.as_posix(),
            "rule": "binaural" if binaural else "integrated",
            "T": meta["binaural_lufs"] if binaural else meta["target_lufs"],
            "max_quiet_s": 2.0,
        })
    result = _run(rows, sounds_dir, meta, {}, _options(args, skip=("length", "staleness")),
                  "against-today")
    result.notes.extend(summarize_today(result.reports, meta))
    return result


def summarize_today(reports, meta):
    t = lambda r: r.T  # noqa: E731
    off3 = [r for r in reports if r.lufs is not None and abs(r.lufs - t(r)) > 3]
    off6 = [r for r in reports if r.lufs is not None and abs(r.lufs - t(r)) > 6]
    off05 = [r for r in reports if r.lufs is not None and abs(r.lufs - t(r)) > meta["tolerance_lu"]]
    tp0 = [r for r in reports if r.tp is not None and r.tp > 0]
    tpc = [r for r in reports if r.tp is not None and r.tp > meta["true_peak_ceiling_dbtp"]]
    seam1 = [r for r in reports if r.seam_step is not None and r.seam_step > 1.0]
    seam_fail = [r for r in reports if "seam" in r.failed]
    gaps = [r for r in reports if "gap" in r.failed]
    n = len(reports)
    return [
        f"--- against today ({n} files; mono counted as played on both channels) ---",
        f"loudness off target by more than {meta['tolerance_lu']} LU: {len(off05)}/{n}; "
        f"more than 3 LU: {len(off3)}; more than 6 LU: {len(off6)}",
        f"true peak above 0 dBTP: {len(tp0)}/{n}; above {meta['true_peak_ceiling_dbtp']} dBTP: {len(tpc)}",
        f"loop seam: level step above 1 dB: {len(seam1)}/{n}; failing the seam check "
        f"(step or click): {len(seam_fail)}",
        f"gap check failures (quiet run or quiet edge): {len(gaps)}",
    ]


def print_report(result, out=sys.stdout):
    p = lambda *a: print(*a, file=out)  # noqa: E731
    p(f"{'key':<18}{'rule':<11}{'T':>7}{'LUFS':>8}{'TP':>7}{'seam':>13}{'click':>7}{'quiet':>7}  status")
    for r in result.reports:
        T = "" if r.T is None else f"{r.T:.1f}"
        lufs = "" if r.lufs is None else f"{r.lufs:.2f}"
        tp = "" if r.tp is None else f"{r.tp:.2f}"
        seam = "" if r.seam_step is None else f"{r.seam_step:.2f}/{r.seam_limit:.2f}"
        click = "" if r.click is None else f"{r.click:.2f}"
        quiet = "" if r.quiet_run is None else f"{r.quiet_run:.2f}"
        status = "ok" if not r.failed else "FAIL " + ",".join(sorted(set(r.failed)))
        p(f"{r.key:<18}{r.rule:<11}{T:>7}{lufs:>8}{tp:>7}{seam:>13}{click:>7}{quiet:>7}  {status}")
    for note in result.notes:
        p(note)
    if result.failures:
        p(f"\n{len(result.failures)} failure(s):")
        by_check = {}
        for f in result.failures:
            by_check.setdefault(f.check, []).append(f)
        for f in result.failures:
            p(str(f))
        p("by check: " + ", ".join(f"{c} {len(v)}" for c, v in sorted(by_check.items())))
        p("RESULT: FAIL")
    else:
        p("RESULT: OK")


def main(argv=None):
    args = _parse(sys.argv[1:] if argv is None else list(argv))
    result = _check_today(args) if args.against_today else _check_levels(args)
    print_report(result)
    return 0 if result.ok else 1


if __name__ == "__main__":
    sys.exit(main())
