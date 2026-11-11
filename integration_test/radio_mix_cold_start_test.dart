// A radio inside a saved mix, started first after a cold launch, through the
// Mixes page's own play button.
//
// Guards the 2026-09-25 ordering bug: a mix's first start ran every sound at its
// global level because the mix volumes were applied after playback began. Here
// the stream's global level is 0.9 and the mix says 0.3, so a stream that reads
// 0.9 is the bug. The mix is saved through the real MixesService before
// app.main(), as if an earlier session had saved it.
import 'package:auraninja/audio/sound_controller.dart';
import 'package:auraninja/audio/wrapper_audio_handler.dart';
import 'package:auraninja/main.dart' as app;
import 'package:auraninja/model/mix.dart';
import 'package:auraninja/services/mixes_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
// ignore: depend_on_referenced_packages
import 'package:provider/provider.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';

import 'support/boot.dart';
import 'support/radio.dart';

const _rainPath = 'assets/sounds/rain/light-rain.ogg';
const _mixName = 'E2E radio mix';

/// Pumps frames until [done] holds. `pumpAndSettle` is avoided: the app has
/// endless animations, so it may never settle.
Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() done, {
  required Duration timeout,
  required String what,
}) async {
  final sw = Stopwatch()..start();
  while (!done()) {
    if (sw.elapsed > timeout) {
      fail('Timed out after ${timeout.inSeconds} s waiting for: $what');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The Mixes page overflows its emoji strip by under a pixel next to three
/// action buttons on a phone-width screen; in a debug build that is reported as
/// an error and would fail the test. It is a layout nit, not what this test
/// checks, so it is counted and ignored; every other framework error still
/// reaches the original handler (and fails the test).
const _overflowMarker = 'overflowed by';

Future<void> _coldStartMix(WidgetTester tester) async {
  // State from "an earlier session": the stream's own saved level and the mix.
  final prefs = await SharedPreferences.getInstance();
  await prefs.setDouble('vol_$kLocalStreamUrl', 0.9);
  await MixesService.save([
    Mix(
      id: 'e2e-radio-mix',
      name: _mixName,
      icon: '📻',
      sounds: [
        MixSound(path: kLocalStreamUrl, volume: 0.3),
        MixSound(path: _rainPath, volume: 0.6),
      ],
    ),
  ]);

  // Cold launch: nothing has been played yet.
  app.main();
  await _pumpUntil(
    tester,
    () => SoLoud.instance.isInitialized,
    timeout: const Duration(seconds: 60),
    what: 'SoLoud.instance.isInitialized after app.main()',
  );
  await _pumpUntil(
    tester,
    () => find.byType(NavigationBar).evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
    what: 'the navigation bar',
  );

  // Mixes tab, then the mix's own play button (found through its card's text).
  await tester.tap(find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text('Mixes'),
  ));
  final mixCard = find.widgetWithText(Card, _mixName);
  await _pumpUntil(
    tester,
    () => mixCard.evaluate().isNotEmpty,
    timeout: const Duration(seconds: 20),
    what: 'the "$_mixName" card on the Mixes page',
  );
  final playButton = find.descendant(
    of: mixCard,
    matching: find.byIcon(Icons.play_arrow),
  );
  expect(playButton, findsOneWidget);
  await tester.tap(playButton);

  final handler = Provider.of<WrapperAudioHandler>(
    tester.element(find.byType(Scaffold).first),
    listen: false,
  );
  SoundController? byPath(String path) =>
      handler.allControllers.where((c) => c.sound.path == path).firstOrNull;
  String statuses() => 'stream ${byPath(kLocalStreamUrl)?.status.name}, '
      'rain ${byPath(_rainPath)?.status.name}';
  bool bothPlaying() =>
      byPath(kLocalStreamUrl)?.status == PlaybackStatus.playing &&
      byPath(_rainPath)?.status == PlaybackStatus.playing;
  final sw = Stopwatch()..start();
  while (!bothPlaying()) {
    if (sw.elapsed > const Duration(seconds: 15)) {
      fail('Timed out after 15 s waiting for the stream and light-rain to '
          'reach playing (${statuses()})');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  final stream = byPath(kLocalStreamUrl)!;
  final rain = byPath(_rainPath)!;

  // The mix's volume, not the global one (0.9).
  metric('radio_mix_stream_volume', stream.volume);
  expect(stream.volume, closeTo(0.3, 0.001),
      reason: 'the stream started at its global level, not the mix level');
  expect(stream.player.volume, closeTo(0.3, 0.001),
      reason: "the stream's player is not at the mix level");
  expect(rain.volume, closeTo(0.6, 0.001));

  // The Mixes page shows the mix as running (its play button became stop).
  await _pumpUntil(
    tester,
    () => find
        .descendant(of: mixCard, matching: find.byIcon(Icons.stop))
        .evaluate()
        .isNotEmpty,
    timeout: const Duration(seconds: 15),
    what: 'the mix card to show the stop button',
  );

  // Audio really moves, not only the status. Measured once the mix has finished
  // starting (the page's 4 s start window is over): right after the start the
  // position moved only 1502-1687 ms over 2 s on the CI emulator, against a
  // 1500 ms gate.
  await expectAdvancing(stream, 'radio_mix');

  await handler.stopAll().timeout(const Duration(seconds: 15));
  await _pumpUntil(
    tester,
    () => handler.allControllers
        .every((c) => c.status == PlaybackStatus.notInitialized),
    timeout: const Duration(seconds: 5),
    what: 'every controller to be notInitialized after stopAll()',
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'radio in a mix, first start after a cold launch, plays at the '
      'mix volume',
      timeout: const Timeout(Duration(minutes: 4)), (tester) async {
    final original = FlutterError.onError;
    var overflows = 0;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains(_overflowMarker)) {
        overflows++;
        return;
      }
      original?.call(details);
    };
    try {
      await _coldStartMix(tester);
    } finally {
      FlutterError.onError = original;
      metric('radio_mix_layout_overflow_reports', overflows);
    }
  });
}
