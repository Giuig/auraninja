import 'dart:io';

import 'package:auraninja/data/sound_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every bundled sound file must be reachable from a card, and every card's
/// file must be bundled. A file that ships without a card only costs download
/// size (walk-on-gravel.ogg shipped that way); a card without its file fails
/// to load.
void main() {
  List<String> bundledSoundAssets() {
    final pubspec = File('pubspec.yaml').readAsLinesSync();
    return pubspec
        .map((l) => l.trim())
        .where((l) => l.startsWith('- assets/sounds/') && l.endsWith('.ogg'))
        .map((l) => l.substring(2).trim())
        .toList();
  }

  test('pubspec lists the bundled sounds', () {
    expect(bundledSoundAssets(), isNotEmpty);
  });

  test('every bundled sound file has exactly one card', () {
    final cardPaths = buildLocalizedSounds(null)
        .where((s) => s.path.startsWith('assets/sounds/'))
        .map((s) => s.path)
        .toList();
    final withoutCard = [
      for (final asset in bundledSoundAssets())
        if (!cardPaths.contains(asset)) asset,
    ];
    final duplicated = {
      for (final p in cardPaths)
        if (cardPaths.where((q) => q == p).length > 1) p,
    };
    expect(withoutCard, isEmpty,
        reason: 'bundled sound files with no card in sound_data.dart');
    expect(duplicated, isEmpty, reason: 'sound files used by more than one card');
  });

  test('every card plays a bundled sound file', () {
    final bundled = bundledSoundAssets().toSet();
    final missing = [
      for (final s in buildLocalizedSounds(null))
        if (s.path.startsWith('assets/sounds/') && !bundled.contains(s.path))
          s.path,
    ];
    expect(missing, isEmpty, reason: 'cards whose file is not in pubspec.yaml');
  });
}
