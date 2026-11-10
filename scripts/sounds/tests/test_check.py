"""check.py must pass a good set and name each defect it is built to catch.
Fixtures are generated at test time (ffmpeg + libvorbis); nothing binary is committed."""
import numpy as np

import check
from helpers import (RATE, FixtureSet, binaural_pair, good_loop, needs_ffmpeg,
                     periodic_noise, scale_to_lufs, write_ogg)

pytestmark = needs_ffmpeg


def failed_checks(result):
    return {f.check for f in result.failures}


def expect_detected(tmp_path, name, *extra_args):
    result = check.run_check(tmp_path, *extra_args)
    assert name in failed_checks(result), (
        f"expected failure '{name}', got {sorted(failed_checks(result))}")
    assert check.main([str(tmp_path), *extra_args]) == 1


def test_good_loop_passes(tmp_path):
    fx = FixtureSet(tmp_path)
    fx.add("noise", good_loop())
    fx.add("beat", binaural_pair(), rule="binaural", target=-24.0)
    fx.finish()
    result = check.run_check(tmp_path)
    assert result.failures == [], [str(f) for f in result.failures]
    assert check.main([str(tmp_path)]) == 0


def test_detects_gap(tmp_path):
    x = good_loop()
    x[8 * RATE:11 * RATE] = 0.0  # 3 s of digital silence inside the loop
    fx = FixtureSet(tmp_path)
    fx.add("gappy", x)
    fx.finish()
    expect_detected(tmp_path, "gap")


def test_detects_hard_cut_seam_level_step(tmp_path):
    # Decaying loop: loud start, quiet end. The wrap jumps 12 dB.
    n = 20 * RATE
    ramp = 10 ** (np.linspace(0, -12, n) / 20)
    x = scale_to_lufs(periodic_noise(20, 3) * ramp, -20.0)
    fx = FixtureSet(tmp_path)
    fx.add("cut", x)
    fx.finish()
    expect_detected(tmp_path, "seam")


def test_detects_hard_cut_seam_click(tmp_path):
    # 441 Hz is exactly 100 samples per cycle; 37 samples cut off the end = phase jump.
    n = 10 * RATE - 37
    t = np.arange(n) / RATE
    x = scale_to_lufs(np.sin(2 * np.pi * 441 * t), -20.0)
    fx = FixtureSet(tmp_path)
    fx.add("click", x)
    fx.finish()
    expect_detected(tmp_path, "seam")


def test_detects_loudness_off_by_2db(tmp_path):
    fx = FixtureSet(tmp_path)
    fx.add("loud", good_loop(target=-18.0), target=-20.0)
    fx.finish()
    expect_detected(tmp_path, "loudness")


def test_detects_true_peak_at_0dbtp(tmp_path):
    x = good_loop()
    n = int(0.02 * RATE)
    t = np.arange(n) / RATE
    x[5 * RATE:5 * RATE + n] = 0.99 * np.sin(2 * np.pi * 1000 * t)  # 20 ms burst at ~0 dBFS
    fx = FixtureSet(tmp_path)
    fx.add("peaky", x)
    fx.finish()
    expect_detected(tmp_path, "true_peak")


def test_detects_truncated_length(tmp_path):
    x = good_loop()
    fx = FixtureSet(tmp_path)
    fx.add("short", x[:-1000], row_over={"N": len(x)})  # row still claims the full length
    fx.finish()
    expect_detected(tmp_path, "length")


def test_detects_binaural_separation_30db(tmp_path):
    fx = FixtureSet(tmp_path)
    fx.add("leaky", binaural_pair(leak_db=-30.0), rule="binaural", target=-24.0)
    fx.finish()
    expect_detected(tmp_path, "separation")


def test_detects_size_over_budget(tmp_path):
    fx = FixtureSet(tmp_path)
    fx.add("noise", good_loop())
    fx.finish(budget_bytes=1000)
    expect_detected(tmp_path, "size")


def test_detects_stale_file(tmp_path):
    fx = FixtureSet(tmp_path)
    fx.add("noise", good_loop(), row_over={"sha256": "0" * 64})
    fx.finish()
    expect_detected(tmp_path, "staleness")


def test_detects_missing_file(tmp_path):
    fx = FixtureSet(tmp_path)
    fx.add("noise", good_loop())
    fx.finish()
    (tmp_path / "noise.ogg").unlink()
    expect_detected(tmp_path, "missing")


def test_against_today_needs_no_levels_json(tmp_path):
    # --against-today assumes T=-20 (binaural -24), skips length/staleness, and still
    # flags a file 2 dB hot.
    write_ogg(tmp_path / "hot.ogg", good_loop(target=-18.0))
    result = check.run_check_against_today(tmp_path)
    assert "loudness" in failed_checks(result)
    assert "length" not in failed_checks(result)
    assert "staleness" not in failed_checks(result)
