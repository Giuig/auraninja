import numpy as np

from lib import measure
from helpers import RATE, binaural_pair, needs_ffmpeg, periodic_noise, scale_to_lufs, write_ogg


def sine(db, secs=20, f=997.0, channels=2):
    t = np.arange(int(secs * RATE)) / RATE
    s = 10 ** (db / 20) * np.sin(2 * np.pi * f * t)
    return s if channels == 1 else np.stack([s] * channels, axis=1)


def test_ebu_reference_997hz_minus23dbfs_both_channels_reads_minus23():
    assert abs(measure.lufs(sine(-23.0), RATE) - (-23.0)) <= 0.1


def test_mono_is_measured_as_played_on_both_channels():
    mono = sine(-23.0, channels=1)
    assert abs(measure.lufs(mono, RATE) - measure.lufs(sine(-23.0), RATE)) <= 0.01
    assert "both channels" in measure.MONO_CONVENTION


def test_median_short_term_on_stationary_signal_matches_integrated():
    x = scale_to_lufs(periodic_noise(30, 7), -20.0)
    assert abs(measure.median_short_term(x, RATE) - measure.lufs(x, RATE)) <= 0.3


def test_true_peak_sees_the_intersample_peak():
    # fs/4 sine at 45 degrees: every sample is +-0.707 (-3.0 dBFS) but the waveform peaks at 1.0
    n = 4410
    x = np.sin(2 * np.pi * (RATE / 4) * np.arange(n) / RATE + np.pi / 4)
    assert abs(20 * np.log10(np.max(np.abs(x))) - (-3.01)) < 0.05
    # (the abrupt start of the test signal adds ~0.1 dB of edge ringing, so slightly high is fine)
    assert -0.05 <= measure.true_peak_db(x, RATE) <= 0.15


@needs_ffmpeg
def test_matches_ffmpeg_ebur128_on_mono_and_stereo(tmp_path):
    for ch, name in [(1, "mono"), (2, "stereo")]:
        x = scale_to_lufs(periodic_noise(15, 11, channels=ch), -21.0)
        p = tmp_path / f"{name}.ogg"
        write_ogg(p, x)
        lufs_ff, tp_ff = measure.ffmpeg_loudness(p)
        dec, rate = measure.read_audio(p)
        assert abs(measure.lufs(dec, rate) - lufs_ff) <= 0.1, name
        assert abs(measure.true_peak_db(dec, rate) - tp_ff) <= 0.15, name


def test_quiet_run_and_seam_metrics():
    rng = np.random.default_rng(8)
    x = 0.1 * rng.standard_normal(20 * RATE)
    assert measure.max_quiet_run_s(x, RATE) == 0.0
    x[8 * RATE:11 * RATE] = 0.0
    assert measure.max_quiet_run_s(x, RATE) >= 2.75
    m = measure.seam_metrics(periodic_noise(10, 9), RATE)
    assert m.step_db <= m.limit_db and m.click_ratio <= measure.CLICK_LIMIT


def test_binaural_separation_of_clean_pair_is_large():
    assert measure.binaural_separation_db(binaural_pair(leak_db=-60.0), RATE) >= 55
    assert 27 <= measure.binaural_separation_db(binaural_pair(leak_db=-30.0), RATE) <= 33
