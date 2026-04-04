#!/usr/bin/env python3
"""Audio processing pipeline for Auraninja.

Pipeline:
  1. Normalize: Apply loudness normalization (-16 LUFS EBU R128)
  2. Optimize: Compress to target specs

Usage:
    python audio_pipeline.py                          # Full pipeline (normalize + optimize)
    python audio_pipeline.py --mode normalize        # Only normalize
    python audio_pipeline.py --mode optimize         # Only compress
    python audio_pipeline.py --dry-run               # Preview without making changes
"""

import subprocess
import os
import sys
import shutil
import argparse
from pathlib import Path

AUDIO_EXTENSIONS = {".ogg", ".mp3", ".wav", ".flac", ".m4a", ".aac"}

NORMALIZE_TARGET = "-16"
NORMALIZE_FILTER = f"loudnorm=I={NORMALIZE_TARGET}:TP=-1.5:LRA=11"

BINAURAL_DIR = "assets/sounds/binaural"
BINAURAL_DURATION = 10

AMBIENT_SAMPLE_RATE = "22050"
BINAURAL_SAMPLE_RATE = "44100"
BITRATE = "64k"

FFMPEG_PATHS = [
    "ffmpeg",
    r"C:\Users\giuli\AppData\Local\Microsoft\WinGet\Links\ffmpeg.exe",
    r"C:\yt-dlp\ffmpeg.exe",
]


def find_ffmpeg():
    for path in FFMPEG_PATHS:
        try:
            result = subprocess.run(
                [path, "-version"], capture_output=True, timeout=10
            )
            if result.returncode == 0:
                return path
        except (FileNotFoundError, subprocess.TimeoutExpired):
            continue

    result = shutil.which("ffmpeg")
    if result:
        return result

    raise FileNotFoundError("ffmpeg not found. Install with: winget install ffmpeg")


def get_size_mb(path):
    return os.path.getsize(path) / (1024 * 1024)


def normalize_audio(audio_path, ffmpeg):
    suffix = audio_path.suffix
    temp_path = audio_path.with_suffix(f".temp{suffix}")

    cmd = [
        ffmpeg, "-y", "-i", str(audio_path),
        "-af", NORMALIZE_FILTER,
        "-c:a", "libvorbis", "-q:a", "6",
        str(temp_path)
    ]
    result = subprocess.run(cmd, capture_output=True)

    if temp_path.exists() and temp_path.stat().st_size > 0:
        os.replace(temp_path, audio_path)
        return True
    if result.stderr:
        print(result.stderr.decode()[:500])
    return False


def optimize_audio(audio_path, ffmpeg, is_binaural):
    suffix = audio_path.suffix
    temp_path = audio_path.with_suffix(f".temp{suffix}")

    sample_rate = BINAURAL_SAMPLE_RATE if is_binaural else AMBIENT_SAMPLE_RATE
    duration = f"-t {BINAURAL_DURATION}" if is_binaural else ""

    cmd = [
        ffmpeg, "-y", "-i", str(audio_path),
        "-ar", sample_rate,
        "-b:a", BITRATE,
    ]
    if is_binaural:
        cmd.extend(["-t", str(BINAURAL_DURATION)])
    cmd.append(str(temp_path))

    result = subprocess.run(cmd, capture_output=True)

    if temp_path.exists() and temp_path.stat().st_size > 0:
        os.replace(temp_path, audio_path)
        return True
    if result.stderr:
        print(result.stderr.decode()[:500])
    return False


def find_audio_files(path, exclude_dirs=None):
    exclude_dirs = exclude_dirs or []
    path = Path(path)
    if path.is_file():
        return [path] if path.suffix.lower() in AUDIO_EXTENSIONS else []
    if path.is_dir():
        files = []
        for p in path.rglob("*"):
            if p.suffix.lower() in AUDIO_EXTENSIONS:
                if any(excl in str(p) for excl in exclude_dirs):
                    continue
                files.append(p)
        return sorted(files)
    return []


def process_file(audio_path, ffmpeg, mode, is_binaural):
    size_before = get_size_mb(audio_path)
    success = True

    if mode in ("full", "normalize"):
        if not normalize_audio(audio_path, ffmpeg):
            return size_before, False

    if mode in ("full", "optimize"):
        if not optimize_audio(audio_path, ffmpeg, is_binaural):
            return size_before, False

    size_after = get_size_mb(audio_path)
    return size_after, True


def main():
    parser = argparse.ArgumentParser(description="Audio processing pipeline")
    parser.add_argument(
        "--mode",
        choices=["full", "normalize", "optimize"],
        default="full",
        help="Processing mode (default: full)"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Preview without making changes"
    )
    args = parser.parse_args()

    ffmpeg = find_ffmpeg()
    print(f"Using ffmpeg: {ffmpeg}")
    print()

    base_path = Path(__file__).parent

    ambient_files = find_audio_files(
        base_path / "assets/sounds",
        exclude_dirs=[BINAURAL_DIR]
    )
    binaural_files = find_audio_files(base_path / BINAURAL_DIR)

    total_before = 0
    total_after = 0
    success = 0
    failed = 0

    mode_name = {
        "full": "FULL PIPELINE (normalize + optimize)",
        "normalize": "NORMALIZE (loudness -16 LUFS)",
        "optimize": "OPTIMIZE (compress)"
    }[args.mode]

    print("=" * 60)
    print(mode_name)
    print("=" * 60)

    for audio_path in ambient_files:
        rel_path = audio_path.relative_to(base_path)
        size_before = get_size_mb(audio_path)

        if args.dry_run:
            print(f"[DRY RUN] {rel_path}")
            continue

        print(f"Processing: {rel_path} ... ", end="", flush=True)
        size, ok = process_file(audio_path, ffmpeg, args.mode, is_binaural=False)

        if ok:
            print(f"{size_before:.2f} MB -> {size:.2f} MB")
            total_before += size_before
            total_after += size
            success += 1
        else:
            print("FAILED")
            total_before += size_before
            total_after += size_before
            failed += 1

    for audio_path in binaural_files:
        rel_path = audio_path.relative_to(base_path)
        size_before = get_size_mb(audio_path)

        if args.dry_run:
            print(f"[DRY RUN] {rel_path}")
            continue

        print(f"Processing: {rel_path} ... ", end="", flush=True)
        size, ok = process_file(audio_path, ffmpeg, args.mode, is_binaural=True)

        if ok:
            print(f"{size_before:.2f} MB -> {size:.2f} MB")
            total_before += size_before
            total_after += size
            success += 1
        else:
            print("FAILED")
            total_before += size_before
            total_after += size_before
            failed += 1

    print()
    print("=" * 60)
    print("SUMMARY")
    print("=" * 60)
    print(f"Files: {success} success | {failed} failed")

    if args.dry_run:
        print("DRY RUN - no files were modified.")
        return

    if total_before > 0:
        print(f"Total: {total_before:.2f} MB -> {total_after:.2f} MB")
        print(f"Saved: {total_before - total_after:.2f} MB")


if __name__ == "__main__":
    main()
