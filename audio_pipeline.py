#!/usr/bin/env python3
"""Audio processing pipeline for Auraninja.

Pipeline:
  1. Optimize: Compress to target specs (64kbps, 22.05kHz)
  
NOTE: Normalization is NOT applied - use volumeMultiplier in app code instead.

Usage:
    python audio_pipeline.py                          # Optimize all sounds
    python audio_pipeline.py --dry-run               # Preview without making changes
    python audio_pipeline.py --limit 10               # Limit number of files
    python audio_pipeline.py --skip-processed         # Skip already optimized files
"""

import subprocess
import os
import sys
import shutil
import argparse
from pathlib import Path

AUDIO_EXTENSIONS = {".ogg", ".mp3", ".wav", ".flac", ".m4a", ".aac"}

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


def is_optimized(audio_path, ffmpeg, is_binaural):
    """Check if file already meets target specs."""
    try:
        cmd = [ffmpeg, "-i", str(audio_path), "-hide_banner"]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        
        output = result.stderr
        
        sample_rate = BINAURAL_SAMPLE_RATE if is_binaural else AMBIENT_SAMPLE_RATE
        
        if sample_rate not in output:
            return False
        
        if "64k" not in output.lower() and "64 kb" not in output.lower():
            return False
            
        return True
    except Exception:
        return False


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
        "--dry-run",
        action="store_true",
        help="Preview without making changes"
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=0,
        help="Limit number of files to process (0 = all)"
    )
    parser.add_argument(
        "--skip-processed",
        action="store_true",
        help="Skip files already optimized to target specs"
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

    print("=" * 60)
    print("OPTIMIZE (compress to target specs)")
    print("=" * 60)

    all_files = ambient_files + binaural_files
    
    if args.limit > 0:
        all_files = all_files[:args.limit]
        
    processed_count = 0
    
    for audio_path in all_files:
        rel_path = audio_path.relative_to(base_path)
        is_binaural = audio_path.parent.name == "binaural"
        size_before = get_size_mb(audio_path)

        if args.dry_run:
            print(f"[DRY RUN] {rel_path}")
            continue

        if args.skip_processed:
            if is_optimized(audio_path, ffmpeg, is_binaural):
                print(f"Skipping (already optimized): {rel_path}")
                continue

        print(f"Processing: {rel_path} ... ", end="", flush=True)
        size, ok = process_file(audio_path, ffmpeg, "optimize", is_binaural)

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
            
        processed_count += 1
        
        if args.limit > 0 and processed_count >= args.limit:
            break

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
