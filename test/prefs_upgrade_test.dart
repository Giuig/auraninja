// Upgrade test: what auraninja 1.7.10 wrote to SharedPreferences must still
// be read back correctly by the current code.
//
// Provenance of test/fixtures/prefs_v1_7_10.json
//   Tag:       v1.7.10 (commit 9148a3c), generated 2026-11-11.
//   Method:    a throwaway VM test, run in a scratch `git worktree` checked out
//              at that tag (`flutter pub get`, then `flutter test` on the file
//              below), dumping the mock SharedPreferences map to JSON.
//              Only the tag's own code wrote the values: the handler's
//              persisted setVolume (vol_<path>), VolumeStorage (sound_volumes),
//              MixesService, FavoritesService, UserStationsService and
//              SectionOrderService. Keys are the unprefixed mock keys; the
//              fixture is the dump, unedited.
//   Generator: test/gen_prefs_fixture_test.dart in that worktree, never
//              committed. Re-running it reproduces the fixture byte for byte
//              (ids and dates are fixed):
//
//   import 'dart:convert';
//   import 'dart:io';
//
//   import 'package:auraninja/audio/wrapper_audio_handler.dart';
//   import 'package:auraninja/model/mix.dart';
//   import 'package:auraninja/model/ninja_sound.dart';
//   import 'package:auraninja/services/favorites_service.dart';
//   import 'package:auraninja/services/mixes_service.dart';
//   import 'package:auraninja/services/section_order_service.dart';
//   import 'package:auraninja/services/user_stations_service.dart';
//   import 'package:auraninja/services/volume_storage.dart';
//   import 'package:flutter_test/flutter_test.dart';
//   import 'package:shared_preferences/shared_preferences.dart';
//
//   void main() {
//     test('generate prefs fixture', () async {
//       TestWidgetsFlutterBinding.ensureInitialized();
//       SharedPreferences.setMockInitialValues({});
//
//       const rain = 'assets/sounds/rain/light-rain.ogg';
//       const wind = 'assets/sounds/nature/wind.ogg';
//       const thunder = 'assets/sounds/nature/thunder.ogg';
//       const yumi = 'https://yumicoradio.net/stream';
//       const stationUrl = 'https://radio.example.org/live.mp3';
//
//       // Sounds-page volumes: the handler persists vol_<path>; the bottom
//       // player bar also writes sound_volumes through VolumeStorage.
//       final handler = WrapperAudioHandler();
//       const volumes = {rain: 0.35, wind: 0.8, thunder: 0.15};
//       for (final e in volumes.entries) {
//         handler.setVolume(e.key, e.value); // persists vol_<path> (async)
//         await VolumeStorage.save(e.key, e.value);
//       }
//       await Future<void>.delayed(const Duration(milliseconds: 50));
//
//       // User station, two mixes, favourites, a section order.
//       final station = NinjaSound(
//         name: 'Example FM',
//         category: '@internetRadio',
//         icon: '📻',
//         path: stationUrl,
//         isUserAdded: true,
//       );
//       await UserStationsService.add(station);
//       await MixesService.save([
//         Mix(
//           id: 'mix-1',
//           name: 'Rainy Radio',
//           icon: '🌧️',
//           sounds: [
//             MixSound(path: rain, volume: 0.6),
//             MixSound(path: yumi, volume: 0.3),
//           ],
//           createdAt: DateTime.utc(2026, 10, 20, 18, 30),
//         ),
//         Mix(
//           id: 'mix-2',
//           name: 'Desk Focus',
//           icon: '☕',
//           sounds: [
//             MixSound(path: wind, volume: 0.45),
//             MixSound(path: thunder, volume: 0.2),
//             MixSound(path: stationUrl, volume: 0.7),
//           ],
//           createdAt: DateTime.utc(2026, 10, 28, 9, 5),
//         ),
//       ]);
//       await FavoritesService.save({thunder, rain, stationUrl});
//       await SectionOrderService.save('internetRadio', [stationUrl, yumi]);
//
//       final prefs = await SharedPreferences.getInstance();
//       final dump = {
//         for (final k in prefs.getKeys().toList()..sort()) k: prefs.get(k),
//       };
//       File('fixture_out.json')
//           .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(dump));
//     });
//   }
//
// The expected values below are pinned by hand (what the user created in
// 1.7.10), not derived from the fixture, so a reader that silently drops or
// renames data fails here instead of agreeing with itself.

import 'dart:convert';
import 'dart:io';

import 'package:auraninja/audio/soloud_engine.dart';
import 'package:auraninja/audio/wrapper_audio_handler.dart';
import 'package:auraninja/data/sound_data.dart';
import 'package:auraninja/services/favorites_service.dart';
import 'package:auraninja/services/mixes_service.dart';
import 'package:auraninja/services/section_order_service.dart';
import 'package:auraninja/services/user_stations_service.dart';
import 'package:auraninja/services/volume_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sound_controller_release_on_stop_test.dart' show FakeSoloudEngine;

const _rain = 'assets/sounds/rain/light-rain.ogg';
const _wind = 'assets/sounds/nature/wind.ogg';
const _thunder = 'assets/sounds/nature/thunder.ogg';
const _yumi = 'https://yumicoradio.net/stream';
const _stationUrl = 'https://radio.example.org/live.mp3';

/// The raw fixture, shaped the way SharedPreferences hands values back:
/// strings, doubles and string lists.
Map<String, Object> _fixtureValues() {
  final raw =
      jsonDecode(File('test/fixtures/prefs_v1_7_10.json').readAsStringSync())
          as Map<String, dynamic>;
  return {
    for (final e in raw.entries)
      e.key: e.value is List ? List<String>.from(e.value as List) : e.value!,
  };
}

void _useFixture() => SharedPreferences.setMockInitialValues(_fixtureValues());

const _expectedVolumes = {_rain: 0.35, _wind: 0.8, _thunder: 0.15};

const _expectedMixes = [
  {
    'id': 'mix-1',
    'name': 'Rainy Radio',
    'sounds': [
      {'path': _rain, 'volume': 0.6},
      {'path': _yumi, 'volume': 0.3},
    ],
  },
  {
    'id': 'mix-2',
    'name': 'Desk Focus',
    'sounds': [
      {'path': _wind, 'volume': 0.45},
      {'path': _thunder, 'volume': 0.2},
      {'path': _stationUrl, 'volume': 0.7},
    ],
  },
];

void main() {
  test('the fixture holds exactly the keys 1.7.10 writes', () {
    expect(_fixtureValues().keys.toSet(), {
      'favorites',
      'mixes',
      'section_order_internetRadio',
      'sound_volumes',
      'user_radio_stations',
      'vol_$_rain',
      'vol_$_wind',
      'vol_$_thunder',
    });
  });

  test('MixesService.load() returns the saved mixes: ids, names, sounds',
      () async {
    _useFixture();

    final mixes = await MixesService.load();

    expect([
      for (final m in mixes)
        {
          'id': m.id,
          'name': m.name,
          'sounds': [
            for (final s in m.sounds) {'path': s.path, 'volume': s.volume},
          ],
        },
    ], _expectedMixes);
    expect(mixes.map((m) => m.icon), ['🌧️', '☕']);
    expect(mixes.map((m) => m.createdAt), [
      DateTime.utc(2026, 10, 20, 18, 30),
      DateTime.utc(2026, 10, 28, 9, 5),
    ]);
  });

  test('every mix sound still resolves: built-in sound, stream or user station',
      () async {
    _useFixture();

    final builtIn = {for (final s in buildLocalizedSounds(null)) s.path};
    final stations = {for (final s in await UserStationsService.load()) s.path};
    // The built-in station list differs between debug and release builds
    // (kDebugMode), so a release-only stream is missing from the list a test
    // sees; it must then still be declared in sound_data.dart.
    final soundData = File('lib/data/sound_data.dart').readAsStringSync();
    final mixes = await MixesService.load();
    expect(mixes, isNotEmpty);

    for (final mix in mixes) {
      for (final sound in mix.sounds) {
        final resolves = sound.isStream
            ? builtIn.contains(sound.path) ||
                stations.contains(sound.path) ||
                soundData.contains("'${sound.path}'")
            : builtIn.contains(sound.path);
        expect(resolves, isTrue,
            reason: 'mix "${mix.name}": ${sound.path} resolves to nothing the '
                'current build knows (renamed or removed asset?)');
      }
    }
  });

  test('Sounds-page volumes: vol_<path> restored by the real handler',
      () async {
    _useFixture();
    final engine = FakeSoloudEngine();
    SoloudEngine.override = engine;
    addTearDown(() => SoloudEngine.override = null);
    TestWidgetsFlutterBinding.ensureInitialized();

    final handler = WrapperAudioHandler();
    await handler.registerSounds(buildLocalizedSounds(null));

    double volumeOf(String path) =>
        handler.allControllers.singleWhere((c) => c.sound.path == path).volume;
    for (final e in _expectedVolumes.entries) {
      expect(volumeOf(e.key), e.value, reason: e.key);
    }
    // A sound with no saved volume keeps the default.
    expect(volumeOf('assets/sounds/rain/heavy-rain.ogg'), 0.5);
    expect(engine.calls, isEmpty, reason: 'restoring volumes loads no audio');
  });

  test('VolumeStorage (sound_volumes) loads equal to what was saved', () async {
    _useFixture();

    expect(await VolumeStorage.load(), _expectedVolumes);
    expect(await VolumeStorage.get(_wind), 0.8);
  });

  test('favourites load in their saved order', () async {
    _useFixture();

    expect((await FavoritesService.load()).toList(),
        [_thunder, _rain, _stationUrl]);
  });

  test('the user station loads with all its fields', () async {
    _useFixture();

    final stations = await UserStationsService.load();

    expect(stations, hasLength(1));
    expect(stations.single.name, 'Example FM');
    expect(stations.single.category, '@internetRadio');
    expect(stations.single.icon, '📻');
    expect(stations.single.path, _stationUrl);
    expect(stations.single.isUserAdded, isTrue);
  });

  test('the Internet Radio section order loads as saved', () async {
    _useFixture();

    expect(
        await SectionOrderService.load('internetRadio'), [_stationUrl, _yumi]);
  });
}
