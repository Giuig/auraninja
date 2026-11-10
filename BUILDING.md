# Building Auraninja

## Prerequisites

- Flutter SDK 3.41.5 (see `flutter-version` file)
- Android SDK with command-line tools
- JDK 17

## Build

```bash
flutter pub get
flutter build apk --release --split-per-abi
```

Output APKs will be in:
- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk`
- `build/app/outputs/flutter-apk/app-x86_64-release.apk`

## CI/CD

This project uses a shared GitHub workflow from [ninja_material](https://github.com/Giuig/ninja_material) for building releases.

## Regenerating sounds

The 48 files in `assets/sounds/` are generated from the original recordings by `scripts/sounds/`
(the old `audio_pipeline.py` is gone). Nothing in the sound files is edited by hand.

Requirements: Python 3.11+, `pip install -r scripts/sounds/requirements.txt`, and an ffmpeg with
**libvorbis** (found through the `FFMPEG` environment variable, then `PATH`, then
`C:\yt-dlp\ffmpeg.exe`; the build stops if libvorbis is missing, it never falls back to ffmpeg's
native Vorbis encoder).

```bash
# Rebuild everything into assets/sounds + scripts/sounds/levels.json (several minutes)
python scripts/sounds/build.py

# Rebuild a few sounds into a scratch folder, then check them
python scripts/sounds/build.py --only white-noise,fire,alpha-8hz --out /tmp/sounds
python scripts/sounds/check.py /tmp/sounds

# Check the shipped assets against scripts/sounds/levels.json (exit code 1 on any failure)
python scripts/sounds/check.py

# Measure today's assets against the targets without a levels.json (expected to fail)
python scripts/sounds/check.py --against-today

# Unit tests (need ffmpeg; they generate their own fixtures)
python -m pytest scripts/sounds/tests
```

How it works:

- `scripts/sounds/sounds.toml` has one row per asset: source, loudness rule, Vorbis quality `q`,
  loop points. Originals come from [Moodist](https://github.com/remvze/moodist) at the commit pinned
  in the file and are verified by sha256. They are never committed: they are downloaded into
  `build/sound_src/` (gitignored), or taken from a folder given with `--src-dir` (files named
  `<category>__<name>.<ext>`, e.g. `nature__fire.mp3`). Green noise and the six binaural beats are
  generated, not recorded.
- Each sound is resampled to 44.1 kHz, trimmed, capped at 90 s and baked into a seamless loop
  (equal-power crossfade), then levelled: -20 LUFS integrated (binaural beats -24), or, for the five
  transient sounds (fire, office, keyboard, typewriter, clock), from the median short-term loudness
  of their steady body. The build is closed-loop: it encodes with libvorbis, decodes with ffmpeg and
  measures the decoded file (loudness within the half tolerance, true peak at or below -1 dBTP),
  adjusting gain and ceiling until both hold (at most 8 iterations, otherwise the build fails).
- `levels.json` records what was built (loudness, true peak, length, size, sha256, ffmpeg and
  libvorbis versions). `check.py` decodes every shipped file and fails on gaps, loop seams, loudness
  more than 0.5 LU from target, true peak above -1 dBTP, binaural channel separation under 40 dB, a
  wrong length, a file that no longer matches `levels.json`, or a sounds total over 16,000,000 bytes.
- Mono files are measured as if played on both channels (this matches the web player and SoLoud on
  Android, see `scripts/sounds/lib/measure.py`).
- The Python tests are local only: CI does not run Python.
