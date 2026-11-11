import numpy as np
from scipy.signal import welch

import pytest

from lib import sources, synth
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


# --- noise colours generated from the manifest (green, brown, pink, white) ---------------

COLOURS = ("green", "brown-noise", "pink-noise", "white-noise")


def manifest_noise(key):
    row = next(r for r in sources.load_manifest()["sound"] if r["key"] == key)
    assert row["source"].startswith("synth:"), f"{key} is not generated in the repo"
    return row["synth"]


def noise_for(key, seed=None):
    sp = manifest_noise(key)
    return synth.noise(sp["shape"], sp["seed"] if seed is None else seed, RATE, sp["seconds"])


def test_noise_is_the_green_generator_under_a_general_name():
    assert np.array_equal(synth.noise(SHAPE, 1, RATE, 10), synth.green(SHAPE, 1, RATE, 10))


@pytest.mark.parametrize("key", COLOURS)
def test_manifest_noise_is_mono_ten_seconds_and_exactly_periodic(key):
    x = noise_for(key)
    assert x.ndim == 1 and len(x) == 10 * RATE
    spec = np.fft.rfft(np.tile(x, 2))
    assert np.sum(np.abs(spec[1::2]) ** 2) < 1e-12 * np.sum(np.abs(spec) ** 2)


@pytest.mark.parametrize("key", COLOURS)
def test_manifest_noise_loop_wrap_is_as_smooth_as_its_interior(key):
    x = noise_for(key)
    w = int(0.1 * RATE)
    around_wrap = np.diff(np.concatenate([x[-w:], x[:w]]))
    assert abs(rms_diff_db(around_wrap) - rms_diff_db(np.diff(x))) <= 0.5


@pytest.mark.parametrize("key", COLOURS)
def test_manifest_noise_is_deterministic_per_seed(key):
    seed = manifest_noise(key)["seed"]
    assert np.array_equal(noise_for(key), noise_for(key))
    assert not np.array_equal(noise_for(key), noise_for(key, seed + 1))


@pytest.mark.parametrize("key", COLOURS[1:])
def test_manifest_noise_follows_its_stored_shape_within_3db(key):
    shape = manifest_noise(key)["shape"]
    lo, hi = shape[0][0], shape[-1][0]
    x = noise_for(key)
    f, p = welch(x, RATE, nperseg=32768)
    target = np.interp(np.log(np.maximum(f, 1.0)), np.log([s[0] for s in shape]),
                       [s[1] for s in shape], left=-60, right=-60)
    pt = 10 ** (target / 10)
    centres = [c for c in (25 * 2 ** (i / 3) for i in range(30)) if lo * 1.3 <= c <= hi / 1.3]
    assert len(centres) >= 15
    got = np.array([band_power_db(f, p, c / 2 ** (1 / 6), c * 2 ** (1 / 6)) for c in centres])
    want = np.array([band_power_db(f, pt, c / 2 ** (1 / 6), c * 2 ** (1 / 6)) for c in centres])
    dev = (got - want) - np.mean(got - want)
    assert np.max(np.abs(dev)) <= 3.0, dev


def test_noise_colours_have_their_colour():
    """brown falls ~6 dB/octave, pink ~3, white is flat (power spectrum, 100 Hz to 8 kHz)."""
    slopes = {}
    for key in COLOURS[1:]:
        f, p = welch(noise_for(key), RATE, nperseg=32768)
        lo = band_power_db(f, p / np.maximum(f, 1), 100, 200)   # per-Hz level
        hi = band_power_db(f, p / np.maximum(f, 1), 6400, 12800)
        octaves = np.log2(9600 / 141)
        slopes[key] = (hi - lo) / octaves
    assert -7.0 <= slopes["brown-noise"] <= -5.0, slopes
    assert -4.0 <= slopes["pink-noise"] <= -2.0, slopes
    assert abs(slopes["white-noise"]) <= 1.0, slopes
