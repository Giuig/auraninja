// Store screenshots: stages realistic content and walks through six screens.
//
// Run by scripts/ci/store_screenshots.sh (workflow store_screenshots.yml) in a
// PROFILE build, on an emulator in SystemUI demo mode. Profile, not debug: no
// debug banner, no layout-overflow stripes, and the release station list (a
// debug build swaps the built-in radio stations for test streams).
//
// The test cannot capture the system bars itself (a Flutter-side screenshot
// holds only the app), so at each screen it prints one marker line,
//
//   E2E_METRIC store_shot=<name>
//
// and holds the screen still; the runner sees the line in logcat and takes the
// picture with `adb exec-out screencap -p`, which includes the demo-mode
// status bar. The hold is a fixed time, not a handshake: the runner needs well
// under it.
//
// State is staged through the app's own services before `app.main()`, as if an
// earlier session had saved it. Nothing here comes from a real device.
import 'package:auraninja/audio/sound_controller.dart';
import 'package:auraninja/audio/wrapper_audio_handler.dart';
import 'package:auraninja/main.dart' as app;
import 'package:auraninja/model/mix.dart';
import 'package:auraninja/services/mixes_service.dart';
import 'package:auraninja/services/user_stations_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:provider/provider.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';

import 'support/boot.dart';
import 'support/radio.dart';

const _rain = 'assets/sounds/rain/light-rain.ogg';
const _rainWindow = 'assets/sounds/rain/rain-on-window.ogg';
const _thunder = 'assets/sounds/nature/thunder.ogg';
const _fire = 'assets/sounds/nature/fire.ogg';
const _waves = 'assets/sounds/nature/waves.ogg';
const _wind = 'assets/sounds/nature/wind.ogg';
const _birds = 'assets/sounds/nature/birds.ogg';
const _crickets = 'assets/sounds/nature/crickets.ogg';
const _owl = 'assets/sounds/nature/owl.ogg';
const _chimes = 'assets/sounds/things/wind-chimes.ogg';
const _cafe = 'assets/sounds/places/cafe.ogg';
const _train = 'assets/sounds/places/train.ogg';
const _focus = 'assets/sounds/binaural/focus-10hz.ogg';
const _zenCalm = 'assets/sounds/binaural/theta-5hz.ogg';
const _brown = 'assets/sounds/noise/brown-noise.ogg';
const _pink = 'assets/sounds/noise/pink-noise.ogg';

/// A plain-named user station backed by the local stand-in stream. Its logo
/// lookup is switched off (see [_stage]) so the picture never shows another
/// station's favicon.
const _localStationName = 'Ambient FM';

/// Pumps frames for [duration] of real time. `pumpAndSettle` is avoided: the
/// app has endless animations, so it may never settle.
Future<void> _pumpFor(WidgetTester tester, Duration duration) async {
  final sw = Stopwatch()..start();
  while (sw.elapsed < duration) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// True when [done] held before [timeout].
Future<bool> _pumpUntilOrTimeout(
  WidgetTester tester,
  bool Function() done, {
  required Duration timeout,
}) async {
  final sw = Stopwatch()..start();
  while (!done()) {
    if (sw.elapsed > timeout) return false;
    await tester.pump(const Duration(milliseconds: 100));
  }
  return true;
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() done, {
  required Duration timeout,
  required String what,
}) async {
  if (!await _pumpUntilOrTimeout(tester, done, timeout: timeout)) {
    fail('Timed out after ${timeout.inSeconds} s waiting for: $what');
  }
}

/// Settles, announces the screen to the runner, and holds it still while the
/// runner takes the picture.
Future<void> _shot(
  WidgetTester tester,
  String name, {
  Duration settle = const Duration(milliseconds: 1500),
  Duration hold = const Duration(seconds: 6),
}) async {
  await _pumpFor(tester, settle);
  metric('store_shot', name);
  await _pumpFor(tester, hold);
}

Future<void> _stage() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();

  // Dark theme with the app's own green seed (not the emulator's wallpaper
  // colours), as in the existing store pictures.
  await prefs.setString('themeMode', 'dark');
  await prefs.setBool('useMaterialYou', false);

  await prefs.setStringList('favorites', [_rain, _fire, _cafe, _waves]);
  await prefs.setInt('selected_visualizer_index', 7); // Aurora

  // The station-logo cache is read from `logo_<name>` keys; an empty value
  // means "looked up, nothing found" and keeps the plain radio emoji.
  await prefs.setString('logo_$_localStationName', '');
  await UserStationsService.add(
      radioStation(_localStationName, kLocalStreamUrl));

  Mix mix(String id, String name, String icon, int day,
          List<(String, double)> sounds) =>
      Mix(
        id: id,
        name: name,
        icon: icon,
        sounds: [for (final (p, v) in sounds) MixSound(path: p, volume: v)],
        createdAt: DateTime.utc(2026, 1, day, 20),
      );
  await MixesService.save([
    mix('shot-rainy', 'Rainy evening', '🌧️', 1,
        [(_rain, 0.7), (_thunder, 0.25), (_cafe, 0.4)]),
    mix('shot-focus', 'Deep focus', '🎯', 2,
        [(_focus, 0.35), (_brown, 0.45), (_rainWindow, 0.3)]),
    mix('shot-camp', 'Campfire night', '🔥', 3,
        [(_fire, 0.6), (_crickets, 0.35), (_wind, 0.2), (_owl, 0.15)]),
    mix('shot-train', 'Night train', '🚂', 4,
        [(_train, 0.55), (_pink, 0.2), (_rainWindow, 0.35)]),
    mix('shot-beach', 'Beach morning', '🌊', 5,
        [(_waves, 0.6), (_birds, 0.3), (_chimes, 0.15)]),
  ]);
}

Finder _tab(String label) => find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    );

/// Scrolls the Sounds page so that the section header [text] is as high as
/// the scroll extent allows.
Future<void> _scrollToSection(WidgetTester tester, String text) async {
  final header = find.text(text);
  await _pumpUntil(tester, () => header.evaluate().isNotEmpty,
      timeout: const Duration(seconds: 10), what: 'the "$text" section header');
  await Scrollable.ensureVisible(
    tester.element(header.first),
    alignment: 0,
    duration: const Duration(milliseconds: 400),
    curve: Curves.easeInOut,
  );
  await _pumpFor(tester, const Duration(milliseconds: 800));
}

/// Plays [path] at [volume] through the real handler.
Future<void> _play(
  WidgetTester tester,
  WrapperAudioHandler handler,
  String path,
  double volume,
) async {
  handler.setVolume(path, volume);
  final controller = controllerFor(handler, path);
  startWithoutAwaiting(handler.ninjaPlay(path), 'play $path');
  await _pumpUntil(tester, () => controller.status == PlaybackStatus.playing,
      timeout: const Duration(seconds: 15),
      what: '${controller.sound.name} to reach playing');
}

/// Stops everything and gives the system's own media-session Stop (it follows
/// the last stop by a moment) time to land while nothing is starting.
Future<void> _quiet(WidgetTester tester, WrapperAudioHandler handler) async {
  await handler.stopAll().timeout(const Duration(seconds: 15));
  await _pumpFor(tester, const Duration(seconds: 2));
}

/// Taps the play button of the mix card [name] until the mix is really running
/// (the card shows its stop button and every sound plays), up to 3 attempts.
Future<void> _playMix(
  WidgetTester tester,
  WrapperAudioHandler handler,
  String name,
  List<String> paths,
) async {
  final card = find.widgetWithText(Card, name);
  await _pumpUntil(tester, () => card.evaluate().isNotEmpty,
      timeout: const Duration(seconds: 20), what: 'the "$name" mix card');
  for (var attempt = 1; attempt <= 3; attempt++) {
    await _quiet(tester, handler);
    final play =
        find.descendant(of: card, matching: find.byIcon(Icons.play_arrow));
    expect(play, findsOneWidget);
    await tester.tap(play);
    final running = await _pumpUntilOrTimeout(
      tester,
      () =>
          find
              .descendant(of: card, matching: find.byIcon(Icons.stop))
              .evaluate()
              .isNotEmpty &&
          paths.every((p) =>
              controllerFor(handler, p).status == PlaybackStatus.playing),
      timeout: const Duration(seconds: 25),
    );
    metric('store_mix_attempt_$attempt', running ? 'running' : 'not_running');
    if (running) return;
  }
  fail('the "$name" mix did not start in 3 attempts');
}

Future<void> _shots(WidgetTester tester) async {
  await _stage();

  // Cold launch, as a user would see it.
  app.main();
  await _pumpUntil(tester, () => SoLoud.instance.isInitialized,
      timeout: const Duration(seconds: 60),
      what: 'SoLoud.instance.isInitialized after app.main()');
  await _pumpUntil(
      tester, () => find.byType(NavigationBar).evaluate().isNotEmpty,
      timeout: const Duration(seconds: 30), what: 'the navigation bar');
  final handler = Provider.of<WrapperAudioHandler>(
    tester.element(find.byType(Scaffold).first),
    listen: false,
  );

  // 1. Sounds: favourites and weather, three sounds playing at different levels.
  await tester.tap(_tab('Sounds'));
  await _pumpUntil(
      tester,
      () =>
          handler.allControllers.any((c) => c.sound.path == _rain) &&
          find.text('Weather').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 20),
      what: 'the Sounds page with its sounds registered');
  await _play(tester, handler, _rain, 0.75);
  await _play(tester, handler, _fire, 0.35);
  await _play(tester, handler, _thunder, 0.22);
  await _shot(tester, '01_sounds');

  // 2. Mixes: the saved mixes, one of them running.
  await tester.tap(_tab('Mixes'));
  await _playMix(tester, handler, 'Rainy evening', [_rain, _thunder, _cafe]);
  await _shot(tester, '02_mixes');

  // 3. Binaural: one calm tone playing, the section at the top.
  await tester.tap(_tab('Sounds'));
  await _quiet(tester, handler);
  await _play(tester, handler, _zenCalm, 0.5);
  await _scrollToSection(tester, 'Binaural');
  await _shot(tester, '03_binaural');

  // 4. Internet radio: the built-in station playing; the plain local station
  // if the third-party one does not come up (never a failure).
  await _quiet(tester, handler);
  var station = kYumiUrl;
  startWithoutAwaiting(handler.ninjaPlay(kYumiUrl), 'play Yumi');
  final yumi = controllerFor(handler, kYumiUrl);
  final yumiPlaying = await _pumpUntilOrTimeout(
      tester, () => yumi.status == PlaybackStatus.playing,
      timeout: const Duration(seconds: 25));
  if (!yumiPlaying) {
    metric('store_radio', 'yumi_unreachable_using_local');
    await handler.ninjaStop(kYumiUrl).timeout(const Duration(seconds: 10));
    await _quiet(tester, handler);
    station = kLocalStreamUrl;
    startWithoutAwaiting(handler.ninjaPlay(station), 'play local station');
    await _pumpUntil(tester,
        () => controllerFor(handler, station).status == PlaybackStatus.playing,
        timeout: const Duration(seconds: 15),
        what: 'the local station to reach playing');
  } else {
    metric('store_radio', 'yumi');
    // Give the station's track title and logo a moment to arrive (optional).
    await _pumpUntilOrTimeout(
        tester, () => handler.getMetadata(yumi.sound).isNotEmpty,
        timeout: const Duration(seconds: 10));
    await _pumpFor(tester, const Duration(seconds: 3));
  }
  metric('store_radio_metadata',
      handler.getMetadata(controllerFor(handler, station).sound));
  await _scrollToSection(tester, 'Internet Radio');
  await _shot(tester, '04_radio');

  // 5. Visualizer tab, the station still playing.
  await tester.tap(_tab('Visualizer'));
  await _shot(tester, '05_visualizer', settle: const Duration(seconds: 3));

  // 6. Fullscreen visualizer with the track information. Its overlay hides
  // itself 3 s after opening, so the picture is taken right away.
  await tester.tap(find.byTooltip('Fullscreen'));
  await _shot(tester, '06_fullscreen',
      settle: const Duration(milliseconds: 600),
      hold: const Duration(milliseconds: 2500));

  await _quiet(tester, handler);
}

void main() {
  initE2eBinding();

  testWidgets('store screenshots', timeout: const Timeout(Duration(minutes: 8)),
      (tester) async {
    await _shots(tester);
  });
}
