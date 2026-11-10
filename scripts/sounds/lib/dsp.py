"""Signal processing: resample, trim, loop baking, soft clip and true-peak limiting.

Everything is deterministic (no randomness, fixed filters) so a rebuild reproduces the
same samples.
"""
from dataclasses import dataclass
from math import gcd
from typing import Optional

import numpy as np
from scipy.ndimage import minimum_filter1d, uniform_filter1d
from scipy.signal import resample_poly

from . import measure


def resample(x, rate_in, rate_out):
    """Polyphase resample (scipy.signal.resample_poly, default Kaiser window)."""
    if rate_in == rate_out:
        return x
    g = gcd(int(rate_in), int(rate_out))
    return resample_poly(np.asarray(x, dtype=np.float64), rate_out // g, rate_in // g, axis=0)


def is_dual_mono(x, threshold=0.999):
    """True for a stereo signal whose channels are (nearly) identical."""
    x = np.asarray(x)
    if x.ndim != 2 or x.shape[1] != 2:
        return False
    l, r = x[:, 0], x[:, 1]
    if not l.any() or not r.any():
        return False
    return float(np.corrcoef(l, r)[0, 1]) > threshold


def trim_quiet(x, rate, win_s=0.25, below_median_db=25.0):
    """Drop quiet windows (more than 25 dB under the median 250 ms level) from the head and
    the tail. Interior quiet stretches are never touched."""
    w = int(round(win_s * rate))
    flags = measure.quiet_flags(x, rate, win_s, below_median_db)
    loud = np.flatnonzero(~flags)
    if len(loud) == 0:
        return x
    a, b = int(loud[0]), int(loud[-1])
    end = len(x) if b == len(flags) - 1 else (b + 1) * w
    return x[a * w:end]


def bake_loop(x, crossfade_samples):
    """Make `x` loop seamlessly. Returns y of length N - L (exactly).

    y = x[L:], with its last L samples replaced by tail*cos + head*sin (equal-power
    crossfade; tail = x[N-L:], head = x[:L]). The crossfade ends on x[L-1], so the wrap
    y[-1] -> y[0] continues x[L-1] -> x[L] untouched."""
    x = np.asarray(x, dtype=np.float64)
    n, l = len(x), int(crossfade_samples)
    if not 0 < l <= n // 2:
        raise ValueError(f"crossfade {l} samples does not fit a {n}-sample signal")
    theta = np.linspace(0.0, np.pi / 2, l)
    shape = (l,) + (1,) * (x.ndim - 1)
    fade_out, fade_in = np.cos(theta).reshape(shape), np.sin(theta).reshape(shape)
    y = x[l:].copy()
    y[-l:] = x[n - l:] * fade_out + x[:l] * fade_in
    return y


def sdr_db(reference, y):
    """Signal-to-distortion ratio of `y` against `reference`, dB."""
    err = float(np.sum((np.asarray(reference) - np.asarray(y)) ** 2))
    sig = float(np.sum(np.asarray(reference) ** 2))
    return 200.0 if err <= 0 else float(10 * np.log10(sig / err))


def soft_clip(x, ceiling_lin, knee=0.7):
    """4x-oversampled soft-knee clipper. Linear below knee*ceiling, then a tanh curve that
    saturates at the ceiling. Returns the signal at the original rate."""
    x = np.asarray(x, dtype=np.float64)
    th = knee * ceiling_lin
    over = measure.oversampled(x, 4)
    mag = np.abs(over)
    hot = mag > th
    out = over.copy()
    out[hot] = np.sign(over[hot]) * (th + (ceiling_lin - th) * np.tanh((mag[hot] - th) / (ceiling_lin - th)))
    return resample_poly(out, 1, 4, axis=0)


def _window_min(a, back, fwd):
    """out[i] = min(a[i-back .. i+fwd]); gain 1.0 outside the array."""
    size = back + fwd + 1
    padded = np.pad(a, (back, fwd), constant_values=1.0)
    f = minimum_filter1d(padded, size=size, mode="constant", cval=1.0)
    return f[size // 2:size // 2 + len(a)]


def tp_limiter(x, ceiling_lin, rate, lookahead_ms=5.0, release_ms=100.0):
    """Look-ahead true-peak limiter. The per-sample gain requirement comes from the 4x
    oversampled envelope; it is held for `release_ms` after a peak, applied `lookahead_ms`
    early, and smoothed over the look-ahead window, so the gain is never above what any
    nearby peak needs."""
    x = np.asarray(x, dtype=np.float64)
    x2 = x[:, None] if x.ndim == 1 else x
    n = len(x2)
    over = np.max(np.abs(measure.oversampled(x2, 4)), axis=1)
    env = over[:n * 4].reshape(n, 4).max(axis=1)
    need = np.minimum(1.0, ceiling_lin / np.maximum(env, 1e-12))
    la = max(1, int(round(lookahead_ms * rate / 1000.0)))
    rel = max(1, int(round(release_ms * rate / 1000.0)))
    gain = uniform_filter1d(_window_min(need, rel, la), size=la + 1, mode="nearest")
    gain = np.minimum(gain, 1.0)
    y = x2 * gain[:, None]
    return y[:, 0] if x.ndim == 1 else y


@dataclass
class LimitInfo:
    limited: bool
    sdr_db: Optional[float]


def apply_gain_limited(x, gain, rate, ceiling_db):
    """x * gain, kept under `ceiling_db` dBTP.

    If plain gain already fits, the result is exactly x * gain (no processing).
    Otherwise: oversampled soft clip, then the true-peak limiter. `info.sdr_db` is the
    distortion this caused against plain gain: a report, never a reason to change levels."""
    y = np.asarray(x, dtype=np.float64) * gain
    if measure.true_peak_db(y, rate) <= ceiling_db:
        return y, LimitInfo(False, None)
    c = 10 ** (ceiling_db / 20)
    limited = tp_limiter(soft_clip(y, c), c, rate)
    return limited, LimitInfo(True, sdr_db(y, limited))
