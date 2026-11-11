// The bundled sound assets as the running app sees them: the list comes from the
// AssetManifest, the sizes from the Ogg headers in the bytes (no decoder), so a
// test can compare what the native engine reports against what the file says.

import 'package:auraninja/data/sound_data.dart';
import 'package:auraninja/model/ninja_sound.dart';
import 'package:flutter/services.dart';

import '../../test/support/ogg_info.dart';

class SoundAsset {
  const SoundAsset(this.path, this.info);

  final String path;
  final OggInfo info;

  /// Samples per channel: the length the engine must report, at 44.1 kHz.
  int get samples => info.totalSamples;

  /// What the source holds in memory once decoded: 32-bit float per sample.
  int get decodedBytes => info.totalSamples * info.channels * 4;

  /// The exact length in microseconds, from the header.
  double get lengthUs => info.totalSamples * 1000000 / info.sampleRate;
}

/// Every `assets/sounds/**.ogg` in the manifest, sorted by path.
Future<List<SoundAsset>> loadSoundAssets() async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final paths = manifest
      .listAssets()
      .where((a) => a.startsWith('assets/sounds/') && a.endsWith('.ogg'))
      .toList()
    ..sort();
  final assets = <SoundAsset>[];
  for (final path in paths) {
    final data = await rootBundle.load(path);
    final bytes = Uint8List.sublistView(data);
    assets.add(SoundAsset(path, OggInfo.parse(bytes)));
  }
  return assets;
}

/// The built-in sounds that have a card (everything local; the radio stations
/// are streams). A bundled asset may have no card, hence A1a covers the assets.
List<NinjaSound> localSounds() =>
    buildLocalizedSounds(null).where((s) => !s.isStream).toList();
