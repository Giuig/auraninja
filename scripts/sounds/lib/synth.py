"""Synthesised sounds. Only green noise today."""
import numpy as np

FLOOR_DB = -60.0


def green(shape, seed, rate=44100, seconds=10):
    """Green noise: random-phase inverse FFT shaped to `shape`.

    shape: [[frequency_hz, relative_dB], ...] (power spectrum, dB relative to its peak),
    interpolated linearly in dB over log-frequency and floored at -60 dB outside the listed
    range. The result is mono, `seconds` long, EXACTLY periodic in its own length (a spectrum
    on the 1/length grid), so it loops with no seam at all, and deterministic for a given
    seed. Scaled to RMS 0.1; the build applies the loudness rule afterwards."""
    n = int(round(seconds * rate))
    freqs = np.fft.rfftfreq(n, 1.0 / rate)
    pts_f = np.log([float(p[0]) for p in shape])
    pts_db = [float(p[1]) for p in shape]
    db = np.interp(np.log(np.maximum(freqs, 1.0)), pts_f, pts_db, left=FLOOR_DB, right=FLOOR_DB)
    mag = 10 ** (db / 20)
    mag[0] = 0.0   # no DC
    mag[-1] = 0.0  # no Nyquist component (keeps the spectrum real for even n)
    phase = np.random.default_rng(seed).uniform(0.0, 2 * np.pi, len(freqs))
    x = np.fft.irfft(mag * np.exp(1j * phase), n)
    return x * (0.1 / np.sqrt(np.mean(x ** 2)))


def binaural(left_hz, right_hz, seconds=10, rate=44100):
    """Binaural-beat pair: a pure sine per channel (left_hz on L, right_hz on R), unit
    amplitude, phase 0. Whole-Hz carriers over whole seconds hold an integer number of
    cycles per channel, so the loop is seamless by construction. Returns (n, 2)."""
    if left_hz != int(left_hz) or right_hz != int(right_hz) or seconds != int(seconds):
        raise ValueError("carriers and length must be whole Hz / whole seconds for an exact loop")
    n = int(round(seconds * rate))
    t = np.arange(n) / rate
    return np.stack([np.sin(2 * np.pi * left_hz * t), np.sin(2 * np.pi * right_hz * t)], axis=1)
