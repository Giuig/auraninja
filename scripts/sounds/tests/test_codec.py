from lib import codec
from helpers import RATE, needs_ffmpeg, periodic_noise

pytestmark = needs_ffmpeg


def test_encoder_is_libvorbis_and_versions_are_captured():
    info = codec.ffmpeg_info()
    assert "libvorbis" in info["encoders"]
    assert info["ffmpeg_version"] and info["libvorbis_version"]


def test_encode_is_deterministic_and_decodes_to_exact_length(tmp_path):
    x = 0.3 * periodic_noise(3, 4)
    a, b = tmp_path / "a.ogg", tmp_path / "b.ogg"
    codec.encode_vorbis(x, RATE, 0, a)
    codec.encode_vorbis(x, RATE, 0, b)
    assert a.read_bytes() == b.read_bytes()
    dec, rate = codec.decode(a)
    assert rate == RATE and len(dec) == len(x)


def test_stereo_round_trip_keeps_two_channels(tmp_path):
    x = 0.3 * periodic_noise(2, 5, channels=2)
    p = tmp_path / "s.ogg"
    codec.encode_vorbis(x, RATE, 0, p)
    dec, rate = codec.decode(p)
    assert dec.shape == x.shape
