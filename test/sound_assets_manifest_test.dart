// CI guard for the bundled sounds: every asset in pubspec.yaml must match the row the
// sound pipeline (scripts/sounds/build.py) recorded in scripts/sounds/levels.json, so a
// stale or hand-swapped file cannot ship. Reads the bytes only; no ffmpeg needed.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/ogg_info.dart';

const _budgetBytes = 16000000;
const _sampleRate = 44100;

List<String> _pubspecSoundAssets() {
  final text = File('pubspec.yaml').readAsStringSync();
  final re = RegExp(r'^\s*-\s*(assets/sounds/\S+\.ogg)\s*$', multiLine: true);
  return {for (final m in re.allMatches(text)) m.group(1)!}.toList()..sort();
}

Map<String, Map<String, dynamic>>? _loadRows() {
  final f = File('scripts/sounds/levels.json');
  if (!f.existsSync()) return null;
  final json = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
  return {
    for (final s in (json['sounds'] as List).cast<Map<String, dynamic>>())
      'assets/sounds/${s['path']}': s,
  };
}

void main() {
  final assets = _pubspecSoundAssets();
  final rows = _loadRows();

  test('pubspec lists the 48 sound assets and levels.json exists', () {
    expect(assets.length, 48);
    expect(rows, isNotNull,
        reason:
            'scripts/sounds/levels.json is missing: run scripts/sounds/build.py');
  });

  for (final asset in assets) {
    test('$asset matches levels.json', () {
      expect(rows, isNotNull, reason: 'scripts/sounds/levels.json is missing');
      final row = rows![asset];
      expect(row, isNotNull, reason: 'no levels.json row for $asset');

      final file = File(asset);
      expect(file.existsSync(), isTrue, reason: '$asset is not on disk');
      final bytes = file.readAsBytesSync();
      expect(bytes.length, row!['bytes'],
          reason: '$asset differs from levels.json: rebuild it with build.py');

      final info = OggInfo.parse(bytes);
      expect(info.sampleRate, _sampleRate, reason: 'Vorbis header sample rate');
      expect(info.sampleRate, row['rate']);
      expect(info.channels, row['channels'], reason: 'Vorbis header channels');
      expect(info.totalSamples, row['N'],
          reason:
              'last Ogg page granule position must equal the loop length N');
    });
  }

  test('the sounds total stays within the size budget', () {
    final total = assets.fold<int>(0, (sum, a) {
      final f = File(a);
      return sum + (f.existsSync() ? f.lengthSync() : 0);
    });
    expect(total, lessThanOrEqualTo(_budgetBytes));
    expect(rows, isNotNull,
        reason:
            'scripts/sounds/levels.json is missing: run scripts/sounds/build.py');
  });
}
