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
    kinds = {"moodist": 0, "git": 0, "synth": 0}
    for r in m["sound"]:
        kind = r["source"].split(":", 1)[0]
        kinds[kind] += 1
        if kind in ("moodist", "git"):
            assert re.fullmatch(r"[0-9a-f]{64}", r["sha256"]), r["key"]
    assert kinds == {"moodist": 41, "git": 6, "synth": 1}


def test_rules_and_body_set():
    m = sources.load_manifest()
    body = {r["key"] for r in m["sound"] if r["rule"] == "body"}
    assert body == {"fire", "office", "keyboard", "typewriter", "clock"}
    binaural = [r for r in m["sound"] if r["rule"] == "binaural"]
    assert len(binaural) == 6
    assert all(r["asset"].startswith("assets/sounds/binaural/") for r in binaural)
    assert all(r["source"].startswith("git:891d256:assets/sounds/binaural/") for r in binaural)
    for r in m["sound"]:
        assert r["rule"] in ("integrated", "body", "binaural")
        assert r.get("q", 0) in (0, 1, 2)


def test_tampered_source_is_rejected():
    with pytest.raises(sources.SourceHashMismatch):
        sources.verify_sha256(b"not the original", "0" * 64, "x")
