"""sounds.toml sanity: one row per pubspec sound asset, pinned and hashed sources."""
import re
from pathlib import Path

import pytest

from lib import sources

ROOT = Path(__file__).resolve().parents[3]


def pubspec_sound_assets():
    text = (ROOT / "pubspec.yaml").read_text(encoding="utf-8")
    return sorted(set(re.findall(r"^\s*-\s*(assets/sounds/\S+\.ogg)\s*$", text, re.M)))


def test_one_row_per_pubspec_sound_asset():
    m = sources.load_manifest()
    assets = sorted(r["asset"] for r in m["sound"])
    assert assets == pubspec_sound_assets()
    assert len(assets) == 48
    keys = [r["key"] for r in m["sound"]]
    assert len(set(keys)) == len(keys)


def test_sources_are_pinned_and_hashed():
    m = sources.load_manifest()
    assert re.fullmatch(r"[0-9a-f]{40}", m["meta"]["moodist_commit"])
    kinds = {"moodist": 0, "synth": 0}
    for r in m["sound"]:
        kind = r["source"].split(":", 1)[0]
        kinds[kind] += 1
        if kind == "moodist":
            assert re.fullmatch(r"[0-9a-f]{64}", r["sha256"]), r["key"]
    assert kinds == {"moodist": 41, "synth": 7}  # 41 recordings, green noise, 6 binaurals


def test_rules_and_body_set():
    m = sources.load_manifest()
    body = {r["key"] for r in m["sound"] if r["rule"] == "body"}
    assert body == {"fire", "office", "keyboard", "typewriter", "clock"}
    binaural = [r for r in m["sound"] if r["rule"] == "binaural"]
    assert len(binaural) == 6
    assert all(r["asset"].startswith("assets/sounds/binaural/") for r in binaural)
    # binaurals are synthesised from carriers (DECISIONS 14), L/R in whole Hz, 10 s
    carriers = {r["key"]: (r["synth"]["left_hz"], r["synth"]["right_hz"]) for r in binaural}
    assert carriers == {
        "alpha-8hz": (200, 208), "delta-1hz": (100, 101), "delta-2hz": (100, 102),
        "focus-10hz": (200, 210), "theta-4hz": (150, 154), "theta-5hz": (200, 205)}
    for r in binaural:
        assert r["source"] == "synth:binaural" and r["synth"]["seconds"] == 10 and r["q"] == 8
    for r in m["sound"]:
        assert r["rule"] in ("integrated", "body", "binaural")
        assert 0 <= r.get("q", 0) <= 10


def test_per_sound_quality_per_decisions_13():
    m = sources.load_manifest()
    q1 = {"clock", "fire", "light-rain", "thunder", "rain-on-umbrella",
          "droplets", "birds", "crickets", "whale"}
    # DECISIONS 13's optional upgrade, applied in P3: the arm64 APK left over 1 MB under 30 MB.
    q2 = {"frog", "walk-in-snow"}
    for r in m["sound"]:
        want = (8 if r["rule"] == "binaural" else 2 if r["key"] in q2
                else 1 if r["key"] in q1 else 0)
        assert r["q"] == want, (r["key"], r["q"], want)


def test_tampered_source_is_rejected():
    with pytest.raises(sources.SourceHashMismatch):
        sources.verify_sha256(b"not the original", "0" * 64, "x")
