import numpy as np

from lib import dsp
from helpers import RATE, true_peak_db


def rms_db(x):
    return 10 * np.log10(np.mean(np.square(x)) + 1e-30)


def test_bake_loop_length_is_n_minus_l_exactly():
    rng = np.random.default_rng(0)
    for n, l in [(441000, 88200), (30001, 777), (100000, 1)]:
        x = rng.standard_normal(n)
        assert len(dsp.bake_loop(x, l)) == n - l
    stereo = rng.standard_normal((50000, 2))
    assert dsp.bake_loop(stereo, 4410).shape == (50000 - 4410, 2)


def test_bake_loop_wraps_continuously_into_the_source():
    # y[0] = x[L] follows y[-1] = x[L-1] (the head's last sample), by construction.
    rng = np.random.default_rng(1)
    x = rng.standard_normal(20000)
    y = dsp.bake_loop(x, 2000)
    assert np.isclose(y[-1], x[1999], atol=1e-9)
    assert np.array_equal(y[:-2000], x[2000:-2000])


def test_equal_power_crossfade_on_white_noise_has_no_audible_seam_step():
    rng = np.random.default_rng(2)
    x = rng.standard_normal(30 * RATE)
    y = dsp.bake_loop(x, 2 * RATE)
    w = int(0.02 * RATE)  # 20 ms
    looped = np.concatenate([y, y])
    n = len(y)
    step = abs(rms_db(looped[n:n + w]) - rms_db(looped[n - w:n]))
    assert step <= 1.0, step
    # the crossfade region itself keeps its level (equal power on uncorrelated noise)
    assert abs(rms_db(y[-2 * RATE:]) - rms_db(y[:RATE])) <= 0.5


def test_limiter_keeps_oversampled_true_peak_under_ceiling():
    rng = np.random.default_rng(3)
    x = 0.05 * rng.standard_normal(10 * RATE)
    for pos in range(2000, len(x) - 2000, 22050):  # pulse train, well over full scale
        x[pos:pos + 3] += np.array([2.0, 3.5, 2.0])
    y, info = dsp.apply_gain_limited(x, 1.0, RATE, -1.0)
    assert info.limited is True
    assert true_peak_db(y) <= -1.0 + 0.05, true_peak_db(y)
    assert info.sdr_db is not None


def test_linear_path_is_bit_identical_to_gain():
    rng = np.random.default_rng(4)
    x = 0.1 * rng.standard_normal(RATE)
    y, info = dsp.apply_gain_limited(x, 0.5, RATE, -1.0)
    assert info.limited is False
    assert np.array_equal(y, x * 0.5)


def test_resample_is_deterministic_and_length_exact():
    x = np.random.default_rng(5).standard_normal(44100)
    a = dsp.resample(x, 44100, 48000)
    b = dsp.resample(x, 44100, 48000)
    assert len(a) == 48000 and np.array_equal(a, b)
    assert np.array_equal(dsp.resample(x, 44100, 44100), x)


def test_trim_quiet_removes_silent_head_and_tail():
    rng = np.random.default_rng(6)
    body = 0.1 * rng.standard_normal(10 * RATE)
    x = np.concatenate([np.zeros(RATE), body, np.zeros(2 * RATE)])
    y = dsp.trim_quiet(x, RATE)
    assert 9.5 * RATE <= len(y) <= 10.5 * RATE
