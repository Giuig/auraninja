"""build.process_signal: the closed loop (gain -> clip/limit -> encode -> decode -> measure)."""
import numpy as np

import build
from lib import measure
from helpers import RATE, binaural_pair, needs_ffmpeg, periodic_noise

pytestmark = needs_ffmpeg


def noise_with_pops(seed=1):
    x = 0.2 * periodic_noise(20, seed)
    rng = np.random.default_rng(seed)
    for pos in rng.integers(RATE, len(x) - RATE, 12):
        x[pos:pos + 40] += rng.uniform(-3, 3, 40) * np.hanning(40)
    return x


def test_integrated_rule_converges_to_target_and_peak_ceiling(tmp_path):
    out = build.process_signal(noise_with_pops(), RATE, rule="integrated", target=-20.0,
                               q=0, ceiling_db=-1.0, tmp_dir=tmp_path)
    assert abs(out.lufs - (-20.0)) <= 0.5
    assert out.tp <= -1.0
    assert out.iterations <= 8


def test_body_rule_matches_median_short_term_to_reference(tmp_path):
    out = build.process_signal(noise_with_pops(2), RATE, rule="body", target=None,
                               q=0, ceiling_db=-1.0, tmp_dir=tmp_path,
                               reference_st=-24.0, offset_db=0.0)
    dec, rate = measure.read_audio(out.path)
    assert abs(measure.median_short_term(dec, rate) - (-24.0)) <= 0.5
    assert out.tp <= -1.0


def test_binaural_rule_keeps_stereo_untouched_apart_from_gain(tmp_path):
    x = binaural_pair(target=-30.0)
    out = build.process_signal(x, RATE, rule="binaural", target=-24.0, q=0,
                               ceiling_db=-1.0, tmp_dir=tmp_path)
    assert abs(out.lufs - (-24.0)) <= 0.5
    assert out.channels == 2 and out.N == len(x)


def test_large_post_decode_overshoot_converges_within_eight_iterations(tmp_path):
    # fire-like: quiet bed, pops ~30 dB above it. After clipping, the decoded file overshoots
    # the ceiling by several dB, so the ceiling has to be pulled far down.
    rng = np.random.default_rng(7)
    x = 0.01 * periodic_noise(30, 5)
    for pos in rng.integers(RATE, len(x) - RATE, 60):
        x[pos:pos + 25] += rng.uniform(-0.6, 0.6, 25) * np.hanning(25)
    out = build.process_signal(x, RATE, rule="body", target=None, q=1, ceiling_db=-1.0,
                               tmp_dir=tmp_path, reference_st=-24.0, offset_db=0.0)
    assert out.iterations <= 8
    assert out.tp <= -1.0
    assert out.ceiling_db < -2.0  # the pre-encode ceiling really did have to drop
