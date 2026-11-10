import numpy as np
from scipy.signal import welch

from lib import synth
from helpers import RATE

SHAPE = [[100, -23], [200, -10], [300, -3], [420, 0], [600, -4.5], [800, -10.5],
         [1000, -11.5], [1200, -13], [1600, -25], [2000, -29], [3000, -48], [4000, -58]]


def make(seed=1):
    return synth.green(SHAPE, seed=seed, rate=RATE, seconds=10)


def test_green_loop_is_exactly_periodic():
    x = make()
    assert x.ndim == 1 and len(x) == 10 * RATE
    # A signal periodic in N has spectral lines on the 1/N grid only: tiled twice, the odd
    # bins of the double-length FFT are empty.
    spec = np.fft.rfft(np.tile(x, 2))
    odd = np.sum(np.abs(spec[1::2]) ** 2)
    assert odd < 1e-12 * np.sum(np.abs(spec) ** 2)


def rms_diff_db(d):
    return 10 * np.log10(np.mean(d ** 2))


def test_wrap_step_equals_interior_step_within_half_db():
    x = make()
    w = int(0.1 * RATE)
    around_wrap = np.diff(np.concatenate([x[-w:], x[:w]]))
    interior = np.diff(x)
    assert abs(rms_diff_db(around_wrap) - rms_diff_db(interior)) <= 0.5


def band_power_db(f, p, lo, hi):
    m = (f >= lo) & (f < hi)
    return 10 * np.log10(np.sum(p[m]) + 1e-30)


def test_spectrum_follows_the_target_band_shape_within_2db():
    x = make()
    f, p = welch(x, RATE, nperseg=16384)
    target = np.interp(np.log(np.maximum(f, 1.0)), np.log([s[0] for s in SHAPE]),
                       [s[1] for s in SHAPE], left=-60, right=-60)
    pt = 10 ** (target / 10)
    centres = [250, 315, 400, 500, 630, 800, 1000, 1250]
    got = np.array([band_power_db(f, p, c / 2 ** (1 / 6), c * 2 ** (1 / 6)) for c in centres])
    want = np.array([band_power_db(f, pt, c / 2 ** (1 / 6), c * 2 ** (1 / 6)) for c in centres])
    dev = (got - want) - np.mean(got - want)
    assert np.max(np.abs(dev)) <= 2.0, dev


def test_deterministic_for_fixed_seed():
    assert np.array_equal(make(1), make(1))
    assert not np.array_equal(make(1), make(2))


def test_binaural_is_exact_sines_with_integer_cycles_per_channel():
    x = synth.binaural(200, 208, seconds=10, rate=RATE)
    assert x.shape == (10 * RATE, 2)
    t = np.arange(10 * RATE) / RATE
    assert np.allclose(x[:, 0], np.sin(2 * np.pi * 200 * t), atol=1e-12)
    assert np.allclose(x[:, 1], np.sin(2 * np.pi * 208 * t), atol=1e-12)
    # looping: the sample after the last one continues the sine (the step across the wrap
    # equals the interior step), which is what integer cycles buy
    for c in (0, 1):
        wrap = abs(x[0, c] - x[-1, c])
        assert wrap <= np.max(np.abs(np.diff(x[:, c]))) + 1e-12


def test_binaural_channels_are_separated_by_more_than_the_40db_gate():
    from lib import measure
    x = synth.binaural(100, 101, seconds=10, rate=RATE)
    assert measure.binaural_separation_db(x, RATE) >= 60
