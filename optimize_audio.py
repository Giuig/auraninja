#!/usr/bin/env python3
"""Optimize audio files for app size reduction.

- Ambient sounds: 22050 Hz, 64 kbps, stereo
- Binaural beats: 44100 Hz, 64 kbps, stereo, trimmed to 10 seconds
"""

import subprocess
import os
import sys
from pathlib import Path

AUDIO_EXTENSIONS = {".ogg", ".mp3", ".wav", ".flac", ".m4a", ".aac"}
FFMPEG = r"C:\yt-dlp\ffmpeg.exe"

BINAURAL_DIR = "assets/sounds/binaural"
BINAURAL_DURATION = 10  # seconds

def get_size_mb(path):
    return os.path.getsize(path) / (1024 * 1024)

def convert_ambient(audio_path):
    """Convert ambient sounds: stereo, 22050 Hz, 64 kbps."""
    suffix = audio_path.suffix
    temp_path = audio_path.with_suffix(f".temp{suffix}")
    
    cmd = [
        FFMPEG, "-y", "-i", str(audio_path),
        "-ar", "22050",
        "-b:a", "64k",
        str(temp_path)
    ]
    result = subprocess.run(cmd, capture_output=True)
    
    if temp_path.exists() and temp_path.stat().st_size > 0:
        os.replace(temp_path, audio_path)
        return True
    return False

def convert_binaural(audio_path):
    """Convert binaural beats: stereo, 44100 Hz, 64 kbps, 10 seconds."""
    suffix = audio_path.suffix
    temp_path = audio_path.with_suffix(f".temp{suffix}")
    
    cmd = [
        FFMPEG, "-y", "-i", str(audio_path),
        "-t", str(BINAURAL_DURATION),
        "-ar", "44100",
        "-b:a", "64k",
        str(temp_path)
    ]
    result = subprocess.run(cmd, capture_output=True)
    
    if temp_path.exists() and temp_path.stat().st_size > 0:
        os.replace(temp_path, audio_path)
        return True
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
                # Skip excluded directories
                if any(excl in str(p) for excl in exclude_dirs):
                    continue
                files.append(p)
        return sorted(files)
    return []

def main():
    base_path = Path(__file__).parent
    
    # Find ambient sounds (excluding binaural)
    ambient_files = find_audio_files(base_path / "assets/sounds", exclude_dirs=[BINAURAL_DIR])
    binaural_files = find_audio_files(base_path / BINAURAL_DIR)
    
    total_before = 0
    total_after = 0
    success = 0
    failed = 0
    
    print("=" * 60)
    print("AMBIENT SOUNDS")
    print("Target: stereo, 22050 Hz, 64 kbps")
    print("=" * 60)
    print(f"Found {len(ambient_files)} files\n")
    
    for audio_path in ambient_files:
        rel_path = audio_path.relative_to(base_path)
        size_before = get_size_mb(audio_path)
        total_before += size_before
        
        print(f"Converting: {rel_path} ... ", end="", flush=True)
        if convert_ambient(audio_path):
            size_after = get_size_mb(audio_path)
            total_after += size_after
            saved = size_before - size_after
            print(f"{size_before:.2f} MB -> {size_after:.2f} MB (saved {saved:.2f} MB)")
            success += 1
        else:
            total_after += size_before
            print("FAILED")
            failed += 1
    
    print(f"\n{'='*60}")
    print("BINAURAL BEATS")
    print(f"Target: stereo, 44100 Hz, 64 kbps, {BINAURAL_DURATION}s loop")
    print("=" * 60)
    print(f"Found {len(binaural_files)} files\n")
    
    for audio_path in binaural_files:
        rel_path = audio_path.relative_to(base_path)
        size_before = get_size_mb(audio_path)
        total_before += size_before
        
        print(f"Converting: {rel_path} ... ", end="", flush=True)
        if convert_binaural(audio_path):
            size_after = get_size_mb(audio_path)
            total_after += size_after
            saved = size_before - size_after
            print(f"{size_before:.2f} MB -> {size_after:.2f} MB (saved {saved:.2f} MB)")
            success += 1
        else:
            total_after += size_before
            print("FAILED")
            failed += 1
    
    print(f"\n{'='*60}")
    print("SUMMARY")
    print("=" * 60)
    print(f"Converted: {success} | Failed: {failed}")
    if total_before > 0:
        print(f"Total before: {total_before:.2f} MB")
        print(f"Total after:  {total_after:.2f} MB")
        print(f"Saved:        {total_before - total_after:.2f} MB ({100*(1 - total_after/total_before):.0f}%)")

if __name__ == "__main__":
    main()