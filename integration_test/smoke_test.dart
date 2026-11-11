// Emulator smoke test: the real app boots, SoLoud is running, one sound loads
// and plays through the real handler, and stops again.
//
// Uses app.main() (as the installed app does), so the SoLoud init here is the
// one the user's phone runs. Needs an Android device or emulator.
import 'package:auraninja/audio/sound_controller.dart';
import 'package:auraninja/audio/wrapper_audio_handler.dart';
import 'package:auraninja/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
// ignore: depend_on_referenced_packages
import 'package:provider/provider.dart';

import 'support/boot.dart';

const _soundName = 'Light Rain';
const _soundPath = 'assets/sounds/rain/light-rain.ogg';

/// Pumps frames until [done] holds. `pumpAndSettle` is avoided: the app has
/// endless animations (visualizers, marquee), so it may never settle.
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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app boots, SoLoud is up, one sound loads, plays and stops',
      (tester) async {
    final capture = captureDebugPrint();
    try {
      // The user's own startup path: SoLoud.instance.init(), the audio
      // handler, then the widget tree. main() returns void, so it cannot be
      // awaited; a failing SoLoud.init() surfaces as an uncaught error and as
      // the wait below timing out.
      app.main();
      await _pumpUntil(
        tester,
        () => SoLoud.instance.isInitialized,
        timeout: const Duration(seconds: 60),
        what: 'SoLoud.instance.isInitialized after app.main()',
      );
      expect(SoLoud.instance.isInitialized, isTrue);

      // The app opens on its first tab; go to Sounds and find a known card.
      await _pumpUntil(
        tester,
        () => find.byType(NavigationBar).evaluate().isNotEmpty,
        timeout: const Duration(seconds: 30),
        what: 'the navigation bar',
      );
      await tester.tap(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Sounds'),
      ));
      await _pumpUntil(
        tester,
        () => find.text(_soundName).evaluate().isNotEmpty,
        timeout: const Duration(seconds: 20),
        what: 'the "$_soundName" card on the Sounds page',
      );

      final handler = Provider.of<WrapperAudioHandler>(
        tester.element(find.byType(Scaffold).first),
        listen: false,
      );
      await _pumpUntil(
        tester,
        () => handler.allControllers.any((c) => c.sound.path == _soundPath),
        timeout: const Duration(seconds: 10),
        what: 'the sound being registered with the handler',
      );
      final controller =
          handler.allControllers.firstWhere((c) => c.sound.path == _soundPath);

      // ninjaPlay awaits load + play; the status must read playing quickly.
      final play = handler.ninjaPlay(_soundPath);
      await _pumpUntil(
        tester,
        () => controller.status == PlaybackStatus.playing,
        timeout: const Duration(seconds: 5),
        what: '$_soundName to reach playing (status ${controller.status})',
      );
      await play;

      expect(
        capture.lines.any((l) =>
            RegExp(r'\[SC:Light Rain\] loaded in \d+ ms \(len \d+ ms\)')
                .hasMatch(l)),
        isTrue,
        reason: 'no "[SC:Light Rain] loaded in N ms (len N ms)" line was printed',
      );

      final playingPss = pssKb();
      expect(playingPss.kb, greaterThan(0));

      await handler.ninjaStop(_soundPath);
      await _pumpUntil(
        tester,
        () => controller.status == PlaybackStatus.notInitialized,
        timeout: const Duration(seconds: 5),
        what: '$_soundName to stop (status ${controller.status})',
      );

      metric('smoke_pss_playing_kb', playingPss.kb);
      metric('smoke_pss_source', playingPss.source.replaceAll(' ', '_'));
    } finally {
      capture.restore();
    }
  });
}
