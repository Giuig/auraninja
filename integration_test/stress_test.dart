// Short stress (A11 without the radio stream): 8 sounds, one toggle and one
// volume change every 10 s for 150 s. Nothing may throw, no controller may go
// to error, the process stays alive, and Stop All gives the memory back.
// (The runner's logcat grep covers FATAL EXCEPTION and ANR.)
import 'dart:math';

import 'package:auraninja/audio/sound_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/assets.dart';
import 'support/boot.dart';

const _paths = [
  'assets/sounds/rain/light-rain.ogg',
  'assets/sounds/nature/birds.ogg',
  'assets/sounds/nature/wind.ogg',
  'assets/sounds/places/cafe.ogg',
  'assets/sounds/nature/river.ogg',
  'assets/sounds/places/office.ogg',
  'assets/sounds/things/keyboard.ogg',
  'assets/sounds/noise/white-noise.ogg',
];

const _steps = 15;
const _stepSeconds = 10;

void main() {
  initE2eBinding();

  testWidgets('150 s of toggling and volume changes: no error, memory returns',
      timeout: const Timeout(Duration(minutes: 10)), (tester) async {
    final capture = captureDebugPrint();
    final errors = <String>[];
    final oldFlutterOnError = FlutterError.onError;
    final oldPlatformOnError = PlatformDispatcher.instance.onError;
    FlutterError.onError =
        (details) => errors.add('FlutterError: ${details.exceptionAsString()}');
    PlatformDispatcher.instance.onError = (error, stack) {
      errors.add('PlatformDispatcher: $error');
      return true;
    };
    try {
      final handler = await ensureBooted();
      await handler.registerSounds(
          localSounds().where((s) => _paths.contains(s.path)).toList());
      expect(handler.allControllers.length, _paths.length,
          reason: 'registered controllers: '
              '${handler.allControllers.map((c) => c.sound.name)}');

      await releaseAll(handler);
      final idle = await settledIdlePssKb();

      final rng = Random(42);
      final clock = Stopwatch()..start();
      var peak = idle;
      var toggles = 0;
      for (var i = 0; i < _steps; i++) {
        final path = _paths[rng.nextInt(_paths.length)];
        final controller =
            handler.allControllers.firstWhere((c) => c.sound.path == path);
        try {
          if (controller.status == PlaybackStatus.playing) {
            await handler.ninjaStop(path).timeout(const Duration(seconds: 10));
          } else {
            await handler.ninjaPlay(path).timeout(const Duration(seconds: 10));
          }
          toggles++;
          final volumePath = _paths[rng.nextInt(_paths.length)];
          handler.setVolume(volumePath, 0.1 + rng.nextDouble() * 0.9,
              persist: false);
        } catch (e) {
          errors.add('step $i ($path): $e');
        }
        final pss = pssKb().kb;
        if (pss > peak) peak = pss;
        final next = Duration(seconds: (i + 1) * _stepSeconds);
        if (clock.elapsed < next) {
          await Future<void>.delayed(next - clock.elapsed);
        }
      }

      await handler.stopAll();
      for (final c in handler.allControllers) {
        await waitForStatus(c, PlaybackStatus.notInitialized);
      }
      await Future<void>.delayed(const Duration(seconds: 10));
      final after = pssKb().kb;

      metric('stress_seconds', clock.elapsed.inSeconds);
      metric('stress_toggles', toggles);
      metric('stress_idle_kb', idle);
      metric('stress_peak_kb', peak);
      metric('stress_after_kb', after);
      metric('stress_delta_kb', after - idle);

      expect(errors, isEmpty, reason: errors.join('\n'));
      final errorLines =
          capture.lines.where((l) => RegExp(r'status: .* → error').hasMatch(l));
      expect(errorLines, isEmpty,
          reason: 'a controller went to error: ${errorLines.join(' | ')}');
      for (final c in handler.allControllers) {
        expect(c.status, isNot(PlaybackStatus.error),
            reason: '${c.sound.name} (${c.sound.path}) ended in error');
      }
      expect(after, greaterThan(0),
          reason: 'the process is not readable after the stress run '
              '(PSS $after kB)');
      expect(after, lessThanOrEqualTo(idle + kMemoryMarginKb),
          reason: 'after Stop All: idle $idle kB, after $after kB, delta '
              '${after - idle} kB, margin $kMemoryMarginKb kB');
    } finally {
      FlutterError.onError = oldFlutterOnError;
      PlatformDispatcher.instance.onError = oldPlatformOnError;
      capture.restore();
    }
  });
}
