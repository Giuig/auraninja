"""Fixture helpers. Deliberately independent of the code under test (own ffmpeg lookup,
own loudness scaling via pyloudnorm) so the tests stay meaningful when the
implementation is a stub or changes."""
import hashlib
import json
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

import numpy as np
import pyloudnorm
import pytest
import soundfile as sf

RATE = 44100


def find_ffmpeg():
    env = os.environ.get("FFMPEG")
    for cand in (env, shutil.which("ffmpeg"), r"C:\yt-dlp\ffmpeg.exe"):
        if cand and (Path(cand).exists() or shutil.which(cand)):
            return cand
    return None


FFMPEG = find_ffmpeg()
needs_ffmpeg = pytest.mark.skipif(FFMPEG is None, reason="ffmpeg not found")


def lufs_dup(x, rate=RATE):
    """Integrated loudness, mono played on both channels (the app's convention)."""
    x = np.asarray(x, dtype=np.float64)
    if x.ndim == 1:
        x = np.stack([x, x], axis=1)
    return pyloudnorm.Meter(rate).integrated_loudness(x)


def scale_to_lufs(x, target, rate=RATE):
    return x * 10 ** ((target - lufs_dup(x, rate)) / 20)


def periodic_noise(seconds, seed=1, rate=RATE, channels=1):
    """Exactly periodic ambient-like noise (random-phase inverse FFT), peak-normalised."""
    n = int(round(seconds * rate))
    rng = np.random.default_rng(seed)
    out = []
    for _ in range(channels):
        f = np.fft.rfftfreq(n, 1 / rate)
        mag = 1 / np.sqrt(np.maximum(f, 300.0))  # flat below 300 Hz, pink above
        mag[0] = 0
        ph = rng.uniform(0, 2 * np.pi, len(f))
        x = np.fft.irfft(mag * np.exp(1j * ph), n)
        out.append(x / np.max(np.abs(x)))
    y = np.stack(out, axis=1)
    return y[:, 0] if channels == 1 else y


def write_ogg(path, x, rate=RATE, q=0):
    path = Path(path)
    with tempfile.TemporaryDirectory() as td:
        wav = Path(td) / "in.wav"
        sf.write(wav, np.asarray(x, dtype=np.float32), rate, subtype="FLOAT")
        subprocess.run(
            [FFMPEG, "-y", "-v", "error", "-i", str(wav), "-c:a", "libvorbis",
             "-q:a", str(q), "-map_metadata", "-1", "-fflags", "+bitexact", str(path)],
            check=True)


def decode(path):
    with tempfile.TemporaryDirectory() as td:
        wav = Path(td) / "out.wav"
        subprocess.run([FFMPEG, "-y", "-v", "error", "-i", str(path), "-c:a", "pcm_f32le", str(wav)],
                       check=True)
        x, r = sf.read(wav, dtype="float64", always_2d=False)
    return x, r


def true_peak_db(x, rate=RATE):
    from scipy.signal import resample_poly
    x = np.asarray(x, dtype=np.float64)
    y = resample_poly(x, 4, 1, axis=0)
    return 20 * np.log10(max(np.max(np.abs(y)), 1e-12))


class FixtureSet:
    """A directory of .ogg files plus a levels.json that describes them, in the schema
    check.py reads. `add()` encodes, decodes, and records what is really in the file;
    overrides let a test make the row disagree with the file."""

    def __init__(self, root):
        self.root = Path(root)
        self.rows = []

    def add(self, key, x, rule="integrated", target=-20.0, q=0, row_over=None, max_quiet_s=2.0):
        path = self.root / f"{key}.ogg"
        write_ogg(path, x, q=q)
        dec, rate = decode(path)
        row = {
            "key": key,
            "path": f"{key}.ogg",
            "rule": rule,
            "T": target,
            "lufs": float(lufs_dup(dec, rate)),
            "tp": float(true_peak_db(dec, rate)),
            "median_st": 0.0,
            "N": int(dec.shape[0]),
            "rate": int(rate),
            "channels": 1 if dec.ndim == 1 else int(dec.shape[1]),
            "bytes": path.stat().st_size,
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "q": q,
            "max_quiet_s": max_quiet_s,
        }
        if row_over:
            row.update(row_over)
        self.rows.append(row)
        return row

    def finish(self, budget_bytes=16_000_000):
        doc = {
            "header": {"R": -20.0, "budget_bytes": budget_bytes, "partial": True},
            "sounds": self.rows,
        }
        (self.root / "levels.json").write_text(json.dumps(doc, indent=1))
        return self.root


def good_loop(seconds=20, seed=1, target=-20.0):
    return scale_to_lufs(periodic_noise(seconds, seed), target)


def binaural_pair(leak_db=-60.0, f1=200.0, f2=208.0, seconds=10, target=-24.0):
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    leak = 10 ** (leak_db / 20)
    s1, s2 = np.sin(2 * np.pi * f1 * t), np.sin(2 * np.pi * f2 * t)
    x = np.stack([s1 + leak * s2, s2 + leak * s1], axis=1)
    return scale_to_lufs(x, target)
