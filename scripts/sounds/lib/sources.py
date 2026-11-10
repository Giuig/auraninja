"""Manifest loading and original-recording sources.

Originals are never committed. A source is either a Moodist file at the pinned commit
(`moodist:<path>`, verified by sha256) or synthesised (`synth:<name>`, handled by build.py).
"""
import hashlib
import tempfile
import tomllib
import urllib.request
from pathlib import Path

import numpy as np
import soundfile as sf

from . import codec

SOUNDS_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = SOUNDS_DIR.parents[1]
MANIFEST_PATH = SOUNDS_DIR / "sounds.toml"
DEFAULT_CACHE = REPO_ROOT / "build" / "sound_src"  # gitignored (/build/)


class SourceHashMismatch(Exception):
    pass


class SourceNotFound(Exception):
    pass


def load_manifest(path=None):
    """Parse sounds.toml. Returns {'meta': {...}, 'sound': [row, ...]} with [defaults]
    already applied to every row."""
    with open(path or MANIFEST_PATH, "rb") as f:
        doc = tomllib.load(f)
    defaults = doc.get("defaults", {})
    rows = []
    for r in doc["sound"]:
        merged = {**defaults, **r}
        rows.append(merged)
    return {"meta": doc["meta"], "sound": rows}


def sha256_hex(data):
    return hashlib.sha256(data).hexdigest()


def verify_sha256(data, expected, label):
    got = sha256_hex(data)
    if got != expected:
        raise SourceHashMismatch(f"{label}: sha256 {got} != expected {expected}")


def _moodist_filename(row):
    """File name used in a --src-dir / the cache: <category>__<key><ext>, e.g.
    nature__fire.mp3 (named after the app asset, not Moodist's own path)."""
    category = Path(row["asset"]).parent.name
    ext = Path(row["source"].split(":", 1)[1]).suffix
    return f"{category}__{row['key']}{ext}"


def fetch_original(row, meta, src_dir=None, cache_dir=None):
    """Bytes of the original recording for `row`, verified against its sha256."""
    kind, _, rest = row["source"].partition(":")
    label = row["key"]
    if kind == "moodist":
        name = _moodist_filename(row)
        cache_dir = Path(cache_dir or DEFAULT_CACHE)
        candidates = [Path(src_dir) / name] if src_dir else []
        candidates.append(cache_dir / name)
        data = None
        for cand in candidates:
            if cand.exists():
                data = cand.read_bytes()
                verify_sha256(data, row["sha256"], f"{label} ({cand})")
                break
        if data is None:
            url = (f"https://raw.githubusercontent.com/{meta['moodist_repo']}/"
                   f"{meta['moodist_commit']}/{rest}")
            with urllib.request.urlopen(url, timeout=120) as resp:
                data = resp.read()
            verify_sha256(data, row["sha256"], f"{label} ({url})")
            cache_dir.mkdir(parents=True, exist_ok=True)
            (cache_dir / name).write_bytes(data)
        return data
    raise SourceNotFound(f"{label}: no original for source kind '{kind}'")


def decode_original(data, suffix, cache_dir=None):
    """Decode original bytes to float64 samples at their native rate: (x, rate).
    Results are cached by content hash so repeated builds skip the ffmpeg decode."""
    cache = Path(cache_dir or DEFAULT_CACHE) / "decoded"
    key = sha256_hex(data)
    hit = cache / f"{key}.npz"
    if hit.exists():
        z = np.load(hit)
        return z["x"].astype(np.float64), int(z["rate"])
    with tempfile.TemporaryDirectory() as td:
        src = Path(td) / f"src{suffix}"
        src.write_bytes(data)
        wav = Path(td) / "out.wav"
        r = codec.run_ffmpeg(["-y", "-v", "error", "-i", str(src), "-c:a", "pcm_f32le", str(wav)])
        if r.returncode != 0:
            raise codec.CodecError(r.stderr.decode(errors="replace"))
        x, rate = sf.read(wav, dtype="float32", always_2d=False)
    cache.mkdir(parents=True, exist_ok=True)
    np.savez(hit, x=x, rate=rate)
    return x.astype(np.float64), int(rate)
