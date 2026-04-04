#!/usr/bin/env python3
"""Convert audio files to a target sample rate and bitrate.

Usage:
    python convert_audio.py                          # Convert assets/sounds
    python convert_audio.py path/to/folder           # Convert all audio in folder
    python convert_audio.py path/to/file.ogg         # Convert single file
    python convert_audio.py path/to/folder --rate 44100 --bitrate 128k
"""

import subprocess
import os
import sys
import argparse
from pathlib import Path

AUDIO_EXTENSIONS = {".ogg", ".mp3", ".wav", ".flac", ".m4a", ".aac"}
FFMPEG = "ffmpeg"

def get_size_mb(path):
    return os.path.getsize(path) / (1024 * 1024)

def convert_file(audio_path, sample_rate, bitrate):
    suffix = audio_path.suffix
    temp_path = audio_path.with_suffix(f".temp{suffix}")
    
    cmd = [
        FFMPEG, "-y", "-i", str(audio_path),
        "-ar", str(sample_rate),
        "-b:a", bitrate,
        str(temp_path)
    ]
    result = subprocess.run(cmd, capture_output=True)
    
    if temp_path.exists() and temp_path.stat().st_size > 0:
        os.replace(temp_path, audio_path)
        return True
    return False

def find_audio_files(path):
    path = Path(path)
    if path.is_file():
        return [path] if path.suffix.lower() in AUDIO_EXTENSIONS else []
    if path.is_dir():
        return sorted(p for p in path.rglob("*") if p.suffix.lower() in AUDIO_EXTENSIONS)
    return []

def main():
    parser = argparse.ArgumentParser(description="Convert audio files for size optimization")
    parser.add_argument("path", nargs="?", default="assets/sounds", help="File or folder to convert (default: assets/sounds)")
    parser.add_argument("--rate", type=int, default=22050, help="Target sample rate in Hz (default: 22050)")
    parser.add_argument("--bitrate", default="64k", help="Target bitrate (default: 64k)")
    parser.add_argument("--ffmpeg", default="ffmpeg", help="Path to ffmpeg executable")
    args = parser.parse_args()

    # Store ffmpeg path globally
    global FFMPEG
    FFMPEG = args.ffmpeg

    files = find_audio_files(args.path)
    if not files:
        print(f"No audio files found in '{args.path}'")
        sys.exit(1)

    total_before = 0
    total_after = 0
    success = 0
    failed = 0

    print(f"Found {len(files)} audio files")
    print(f"Target: {args.rate} Hz / {args.bitrate}\n")

    for audio_path in files:
        size_before = get_size_mb(audio_path)
        total_before += size_before

        print(f"Converting: {audio_path} ... ", end="", flush=True)
        if convert_file(audio_path, args.rate, args.bitrate):
            size_after = get_size_mb(audio_path)
            total_after += size_after
            saved = size_before - size_after
            print(f"{size_before:.1f} MB -> {size_after:.1f} MB (saved {saved:.1f} MB)")
            success += 1
        else:
            total_after += size_before
            print("FAILED")
            failed += 1

    print(f"\n{'='*50}")
    print(f"Converted: {success} | Failed: {failed}")
    if total_before > 0:
        print(f"Total: {total_before:.1f} MB -> {total_after:.1f} MB")
        print(f"Saved: {total_before - total_after:.1f} MB ({100*(1 - total_after/total_before):.0f}%)")

if __name__ == "__main__":
    main()
