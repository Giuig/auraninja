import 'dart:typed_data';

/// What the CI guard needs from an Ogg Vorbis file, read straight from the bytes
/// (no decoder, no ffmpeg).
class OggInfo {
  const OggInfo({
    required this.channels,
    required this.sampleRate,
    required this.totalSamples,
  });

  /// From the Vorbis identification header (first packet of the stream).
  final int channels;
  final int sampleRate;

  /// Granule position of the last Ogg page = decoded samples per channel.
  final int totalSamples;

  /// Throws [FormatException] if [bytes] is not a single-stream Ogg Vorbis file.
  static OggInfo parse(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    int? channels;
    int? rate;
    int lastGranule = -1;
    var pos = 0;
    var pages = 0;

    while (pos + 27 <= bytes.length) {
      if (bytes[pos] != 0x4F ||
          bytes[pos + 1] != 0x67 ||
          bytes[pos + 2] != 0x67 ||
          bytes[pos + 3] != 0x53) {
        throw FormatException('no "OggS" capture pattern at byte $pos');
      }
      final granule = data.getInt64(pos + 6, Endian.little);
      final segments = bytes[pos + 26];
      if (pos + 27 + segments > bytes.length) {
        throw const FormatException('truncated Ogg page header');
      }
      var bodyLen = 0;
      for (var i = 0; i < segments; i++) {
        bodyLen += bytes[pos + 27 + i];
      }
      final bodyStart = pos + 27 + segments;
      if (bodyStart + bodyLen > bytes.length) {
        throw const FormatException('truncated Ogg page body');
      }
      if (pages == 0) {
        // packet type 1 + "vorbis", version u32, channels u8, rate u32
        if (bodyLen < 16 ||
            bytes[bodyStart] != 1 ||
            String.fromCharCodes(bytes.sublist(bodyStart + 1, bodyStart + 7)) !=
                'vorbis') {
          throw const FormatException('first packet is not a Vorbis id header');
        }
        channels = bytes[bodyStart + 11];
        rate = data.getUint32(bodyStart + 12, Endian.little);
      }
      lastGranule = granule;
      pages++;
      pos = bodyStart + bodyLen;
    }
    if (pages == 0 || channels == null || rate == null) {
      throw const FormatException('not an Ogg file');
    }
    if (pos != bytes.length) {
      throw const FormatException('trailing bytes after the last Ogg page');
    }
    return OggInfo(
        channels: channels, sampleRate: rate, totalSamples: lastGranule);
  }
}
