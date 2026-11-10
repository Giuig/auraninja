"""Loudness and structure measurements.

Loudness is ITU-R BS.1770-4 / EBU R128 integrated loudness with the standard K-weighting
and two-stage gating. The K-weighting filters come from pyloudnorm (pinned); the block
and gating arithmetic here is vectorised. `ffmpeg_loudness()` runs ffmpeg's `ebur128`
filter on a file and `check.py` cross-checks every file against it.

Mono files: see MONO_CONVENTION below (measured as played on both channels).
"""
import re
from collections import namedtuple

import numpy as np
import pyloudnorm
from scipy.signal import resample_poly

from . import codec

MONO_CONVENTION = (
    "A mono file is measured as if it were played on both channels at full level "
    "(L = R = x): BS.1770 on a stereo pair of identical channels, which reads 3.01 dB "
    "louder than a 1-channel BS.1770 measurement of the same samples (and is what "
    "ffmpeg's ebur128 gives after pan=stereo|c0=c0|c1=c0). "
    "Why this is the convention that matches the listener: "
    "WEB: a 1-channel AudioBuffer feeding the stereo destination is up-mixed by Web Audio "
    "as L = R = x, full level on both channels, so the played loudness is exactly this "
    "measurement. "
    "ANDROID (SoLoud, third_party/flutter_soloud): play() runs setVoicePan_internal with "
    "pan 0 (src/soloud/src/core/soloud_core_voiceops.cpp:76-79: l = cos((pan+1)*pi/4), "
    "r = sin((pan+1)*pi/4), no sqrt(2) makeup), and panAndExpand's 1->2 path "
    "(soloud.cpp:1213 ff.) outputs s*l to the left and s*r to the right: a mono source "
    "plays at L = R = x * 0.7071 (-3.01 dB per channel, constant power). The 2->2 path "
    "multiplies a stereo source by the same l and r, so stereo files are also -3.01 dB. "
    "The Android offset is therefore uniform across mono and stereo files: every sound is "
    "3.01 dB lower on Android than on web, and the balance between sounds is identical "
    "(a 1-channel convention would be wrong by 3 dB for mono files against stereo ones on "
    "both platforms). The absolute -3.01 dB is a platform constant, not per-file; "
    "targets are relative, so it never enters the +-0.5 LU tolerance."
)

_ABS_GATE = -70.0


def read_audio(path):
    """Decode a file with ffmpeg. Returns (float64 samples, rate)."""
    return codec.decode(path)


def as_play_channels(x):
    """(n, 2) float64: a mono signal is duplicated onto both channels (see MONO_CONVENTION)."""
    x = np.asarray(x, dtype=np.float64)
    if x.ndim == 1:
        return np.stack([x, x], axis=1)
    if x.shape[1] == 1:
        return np.repeat(x, 2, axis=1)
    if x.shape[1] == 2:
        return x
    raise ValueError(f"unsupported channel count {x.shape[1]}")


def _k_weight(x2, rate):
    meter = pyloudnorm.Meter(rate)
    y = np.empty_like(x2)
    for ch in range(x2.shape[1]):
        v = x2[:, ch]
        for stage in meter._filters.values():
            v = stage.apply_filter(v)
        y[:, ch] = v
    return y


def _block_ms(y, win, hop):
    """Mean square of each window, per channel: (blocks, channels)."""
    cs = np.concatenate([np.zeros((1, y.shape[1])), np.cumsum(y * y, axis=0)])
    starts = np.arange(0, len(y) - win + 1, hop)
    return (cs[starts + win] - cs[starts]) / win


def _to_lufs(z_sum):
    with np.errstate(divide="ignore"):
        return -0.691 + 10.0 * np.log10(z_sum)


def lufs(x, rate):
    """Integrated loudness (LUFS), BS.1770-4 gating, mono played on both channels."""
    y = _k_weight(as_play_channels(x), rate)
    win = int(round(0.4 * rate))
    if len(y) < win:
        raise ValueError("signal shorter than one 400 ms block")
    z = _block_ms(y, win, win // 4).sum(axis=1)
    l = _to_lufs(z)
    keep = l > _ABS_GATE
    if not keep.any():
        return float("-inf")
    gamma_r = _to_lufs(z[keep].mean()) - 10.0
    keep &= l > gamma_r
    if not keep.any():
        return float("-inf")
    return float(_to_lufs(z[keep].mean()))


def short_term_series(x, rate, window_s=3.0, hop_s=1.0):
    """Short-term loudness (3 s windows, 1 s hop) in LUFS; windows below -70 are dropped.
    A signal shorter than one window is measured as a single window."""
    y = _k_weight(as_play_channels(x), rate)
    win = min(int(round(window_s * rate)), len(y))
    hop = max(1, int(round(hop_s * rate)))
    l = _to_lufs(_block_ms(y, win, hop).sum(axis=1))
    return l[l > _ABS_GATE]


def median_short_term(x, rate):
    s = short_term_series(x, rate)
    return float(np.median(s)) if len(s) else float("-inf")


_TP_CHUNK = 1 << 20
_TP_PAD = 512


def oversampled(x, factor=4):
    """Polyphase-oversampled copy (n*factor, ch); used for true-peak estimation."""
    return resample_poly(np.asarray(x, dtype=np.float64), factor, 1, axis=0, window=("kaiser", 8.0))


def true_peak_db(x, rate=None, oversample=4):
    """True peak (dBTP) by 4x oversampling (BS.1770-4 Annex 2). `rate` is unused: the
    oversampling ratio, not the rate, defines the method."""
    x = np.asarray(x, dtype=np.float64)
    if x.ndim == 1:
        x = x[:, None]
    n = len(x)
    peak = float(np.max(np.abs(x))) if n else 0.0
    for s in range(0, n, _TP_CHUNK):
        a, b = max(0, s - _TP_PAD), min(n, s + _TP_CHUNK + _TP_PAD)
        y = oversampled(x[a:b], oversample)
        lo, hi = (s - a) * oversample, (min(s + _TP_CHUNK, n) - a) * oversample
        peak = max(peak, float(np.max(np.abs(y[lo:hi]))))
    return float(20 * np.log10(max(peak, 1e-10)))


_FF_I = re.compile(r"\bI:\s+(-?inf|-?[\d.]+)\s+LUFS")
_FF_PEAK = re.compile(r"\bPeak:\s+(-?inf|-?[\d.]+)\s+dBFS")


def ffmpeg_loudness(path):
    """(integrated LUFS, true peak dBTP) from ffmpeg's ebur128 filter, mono duplicated onto
    both channels. ffmpeg prints one decimal place."""
    chans = codec.probe(path)["channels"]
    flt = "ebur128=peak=true:framelog=quiet"
    if chans == 1:
        flt = "pan=stereo|c0=c0|c1=c0," + flt
    r = codec.run_ffmpeg(["-nostats", "-i", str(path), "-af", flt, "-f", "null", "-"], text=True)
    tail = r.stderr[r.stderr.rfind("Summary:"):]
    mi, mp = _FF_I.search(tail), _FF_PEAK.search(tail)
    if not (mi and mp):
        raise RuntimeError(f"cannot parse ebur128 output for {path}:\n{r.stderr[-600:]}")
    return float(mi.group(1)), float(mp.group(1))


# --- structure: gaps, seams, binaural separation ---------------------------------------

def _power(x):
    """Per-sample mean-square across the played channels."""
    return np.mean(as_play_channels(x) ** 2, axis=1)


def window_levels_db(x, rate, win_s):
    pw = _power(x)
    w = max(1, int(round(win_s * rate)))
    n = len(pw) // w
    ms = pw[:n * w].reshape(n, w).mean(axis=1)
    return 10 * np.log10(ms + 1e-12)


def quiet_flags(x, rate, win_s=0.25, below_median_db=25.0):
    """Windows (250 ms) more than 25 dB below the median window level."""
    lv = window_levels_db(x, rate, win_s)
    if len(lv) == 0:
        return np.zeros(0, dtype=bool)
    return lv < np.median(lv) - below_median_db


def max_quiet_run_s(x, rate, win_s=0.25, below_median_db=25.0):
    """Longest run of consecutive quiet windows, in seconds."""
    best = run = 0
    for q in quiet_flags(x, rate, win_s, below_median_db):
        run = run + 1 if q else 0
        best = max(best, run)
    return best * win_s


def edge_quiet(x, rate, win_s=0.25, below_median_db=25.0):
    """(first window quiet, last window quiet)."""
    f = quiet_flags(x, rate, win_s, below_median_db)
    return (bool(f[0]), bool(f[-1])) if len(f) else (False, False)


CLICK_LIMIT = 2.5  # see seam_metrics
SeamMetrics = namedtuple("SeamMetrics", "step_db median_step_db limit_db click_ratio")


def seam_metrics(x, rate):
    """How the file sounds when played twice back to back.

    step_db: |20 ms RMS after the wrap - 20 ms RMS before it|; limit_db = max(1 dB, 2x the
    file's own median step between adjacent 20 ms windows). click_ratio: the sample jump
    |x[0] - x[-1]| over the 99.9th percentile of |sample-to-sample difference| (worst channel).
    For a pure tone the wrap step of a perfect loop equals the tone's own largest sample step,
    so the ratio sits near 1 and codec noise lifts it to ~2 (measured on exact sines at q8);
    CLICK_LIMIT is set above that."""
    w = max(1, int(round(0.02 * rate)))
    pw = _power(x)
    tail = 10 * np.log10(pw[-w:].mean() + 1e-12)
    head = 10 * np.log10(pw[:w].mean() + 1e-12)
    lv = window_levels_db(x, rate, 0.02)
    med = float(np.median(np.abs(np.diff(lv)))) if len(lv) > 1 else 0.0
    xs = np.asarray(x, dtype=np.float64)
    xs = xs[:, None] if xs.ndim == 1 else xs
    ratio = 0.0
    for ch in range(xs.shape[1]):
        c = xs[:, ch]
        jump = abs(c[0] - c[-1])
        p = float(np.percentile(np.abs(np.diff(c)), 99.9))
        ratio = max(ratio, jump / p if p > 0 else (np.inf if jump > 0 else 0.0))
    return SeamMetrics(abs(head - tail), med, max(1.0, 2 * med), float(ratio))


def _band_power(spec, k, half=3):
    return float(np.sum(np.abs(spec[max(0, k - half):k + half + 1]) ** 2))


def binaural_separation_db(x, rate):
    """Channel separation of a binaural pair: for each channel's carrier tone (its spectral
    peak), its power in its own channel over its power in the other channel. Returns the
    worse of the two, in dB. Hann window, +-3 bins around each peak."""
    x = np.asarray(x, dtype=np.float64)
    if x.ndim != 2 or x.shape[1] != 2:
        raise ValueError("binaural separation needs a stereo signal")
    win = np.hanning(len(x))
    spec = [np.fft.rfft(x[:, c] * win) for c in (0, 1)]
    mag = [np.abs(s) for s in spec]
    for m in mag:
        m[:5] = 0  # ignore DC and sub-0.5 Hz leakage
    k = [int(np.argmax(m)) for m in mag]
    sep_l = 10 * np.log10(_band_power(spec[0], k[0]) / max(_band_power(spec[1], k[0]), 1e-30))
    sep_r = 10 * np.log10(_band_power(spec[1], k[1]) / max(_band_power(spec[0], k[1]), 1e-30))
    return float(min(sep_l, sep_r))
