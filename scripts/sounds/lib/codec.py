"""ffmpeg / libvorbis wrapper.

The only encoder this pipeline uses is libvorbis. ffmpeg's native `vorbis` encoder is
experimental and much worse; `assert_libvorbis()` refuses to run without libvorbis rather
than silently falling back. Encodes are bit-exact (no encoder tag, deterministic Ogg serial),
so a rebuild from the same inputs and the same ffmpeg/libvorbis gives identical bytes.
"""
import functools
import os
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

import numpy as np
import soundfile as sf

FALLBACK_PATHS = [r"C:\yt-dlp\ffmpeg.exe"]


class CodecError(RuntimeError):
    pass


@functools.lru_cache(maxsize=1)
def find_ffmpeg():
    """FFMPEG env var, then PATH, then C:\\yt-dlp\\ffmpeg.exe."""
    candidates = [os.environ.get("FFMPEG"), shutil.which("ffmpeg"), *FALLBACK_PATHS]
    for cand in candidates:
        if cand and (Path(cand).exists() or shutil.which(cand)):
            return str(cand)
    raise CodecError("ffmpeg not found (set FFMPEG, or put ffmpeg on PATH)")


def run_ffmpeg(args, **kw):
    return subprocess.run([find_ffmpeg(), "-hide_banner", *args], capture_output=True, **kw)


@functools.lru_cache(maxsize=1)
def ffmpeg_info():
    """{'ffmpeg_version', 'libvorbis_version' (the libavcodec wrapper tag, e.g.
    'Lavc62.23.101 libvorbis'), 'encoders': [audio encoder names]}."""
    ver = run_ffmpeg(["-version"], text=True).stdout.splitlines()[0]
    m = re.search(r"ffmpeg version (\S+)", ver)
    enc_out = run_ffmpeg(["-encoders"], text=True).stdout
    encoders = re.findall(r"^\s*A\S{5}\s+(\S+)", enc_out, re.M)
    info = {
        "ffmpeg_version": m.group(1) if m else ver,
        "encoders": encoders,
        "libvorbis_version": None,
    }
    if "libvorbis" in encoders:
        with tempfile.TemporaryDirectory() as td:
            probe_file = Path(td) / "probe.ogg"
            wav = Path(td) / "probe.wav"
            sf.write(wav, np.zeros(4410, dtype=np.float32), 44100, subtype="FLOAT")
            # No bit-exact flags here: the Ogg comment header then carries ffmpeg's encoder tag
            # ("Lavc<version> libvorbis"). The libvorbis library version itself is not exposed.
            run_ffmpeg(["-y", "-v", "error", "-i", str(wav), "-c:a", "libvorbis", str(probe_file)])
            v = re.search(rb"encoder=(Lavc[\d.]+ libvorbis)", probe_file.read_bytes())
            info["libvorbis_version"] = v.group(1).decode() if v else "libvorbis (version unknown)"
    return info


def assert_libvorbis():
    if "libvorbis" not in ffmpeg_info()["encoders"]:
        raise CodecError(
            "this ffmpeg has no libvorbis encoder; the native 'vorbis' encoder must not be used")


def _encode_to(x, rate, q, path):
    x = np.asarray(x, dtype=np.float32)
    with tempfile.TemporaryDirectory() as td:
        wav = Path(td) / "in.wav"
        sf.write(wav, x, rate, subtype="FLOAT")
        r = run_ffmpeg(["-y", "-v", "error", "-i", str(wav), "-c:a", "libvorbis", "-q:a", str(q),
                        "-map_metadata", "-1", "-fflags", "+bitexact", "-flags:a", "+bitexact",
                        str(path)])
        if r.returncode != 0:
            raise CodecError(r.stderr.decode(errors="replace"))


def encode_vorbis(x, rate, q, path):
    """Encode float samples (n,) or (n, ch) to Ogg Vorbis with libvorbis at quality `q`."""
    assert_libvorbis()
    _encode_to(x, rate, q, path)
    return Path(path)


def decode(path):
    """Decode with ffmpeg to float64. Returns (samples (n,) or (n, ch), rate)."""
    with tempfile.TemporaryDirectory() as td:
        wav = Path(td) / "out.wav"
        r = run_ffmpeg(["-y", "-v", "error", "-i", str(path), "-c:a", "pcm_f32le", str(wav)])
        if r.returncode != 0:
            raise CodecError(r.stderr.decode(errors="replace"))
        x, rate = sf.read(wav, dtype="float64", always_2d=False)
    return x, rate


def probe(path):
    """{'codec': 'vorbis', 'rate': 44100, 'channels': 1|2} from ffmpeg's stream line."""
    r = run_ffmpeg(["-i", str(path)], text=True)
    m = re.search(r"Audio: (\w+).*?, (\d+) Hz, (\w+)", r.stderr)
    if not m:
        raise CodecError(f"cannot probe {path}")
    layout = m.group(3)
    channels = {"mono": 1, "stereo": 2}.get(layout)
    if channels is None:
        mm = re.match(r"(\d+)", layout)
        channels = int(mm.group(1)) if mm else 0
    return {"codec": m.group(1), "rate": int(m.group(2)), "channels": channels}
