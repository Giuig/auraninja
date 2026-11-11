// Shared pieces of the radio tests: the local stand-in station, and the checks
// that a station really plays, pauses, resumes and stops.
//
// "Playing" is never read from the status alone: the 1.7.7 radio bug was audio
// flowing under a spinner that never cleared, so the status and the player's
// own position must both say so.
import 'dart:async';

import 'package:auraninja/audio/sound_controller.dart';
import 'package:auraninja/audio/wrapper_audio_handler.dart';
import 'package:auraninja/model/ninja_sound.dart';
import 'package:auraninja/model/sound_category.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'boot.dart';

/// scripts/ci/loop_stream.py on the runner, as the emulator sees the host.
const kLocalStreamUrl = 'http://10.0.2.2:8099/stream';
const kDeadStreamUrl = 'http://10.0.2.2:8099/dead';

/// The release build's built-in station. Debug builds (which these tests are)
/// swap the built-in radio list for test streams, so the station is built here
/// with the same name and URL as lib/data/sound_data.dart.
const kYumiUrl = 'https://yumicoradio.net/stream';

NinjaSound radioStation(String name, String url) => NinjaSound(
      name: name,
      category: SoundCategory.internetRadio,
      icon: '📻',
      path: url,
      isUserAdded: true,
    );

SoundController controllerFor(WrapperAudioHandler handler, String path) =>
    handler.allControllers.firstWhere((c) => c.sound.path == path);

/// A stream's `ninjaPlay` does not complete while the stream plays, so it is
/// started without awaiting and the status is polled. A throw is logged, not
/// left unhandled.
void startWithoutAwaiting(Future<void> future, String what) {
  unawaited(future.catchError((Object e) {
    debugPrint('[E2E] $what ended with: $e');
  }));
}

/// How far the player's position moved over [over].
Future<Duration> positionMovedOver(
  SoundController controller,
  Duration over,
) async {
  final before = controller.player.position;
  await Future<void>.delayed(over);
  return controller.player.position - before;
}

/// The player's position must advance at least 1.5 s over 2 s.
Future<void> expectAdvancing(SoundController controller, String label) async {
  final moved = await positionMovedOver(controller, const Duration(seconds: 2));
  metric('${label}_moved_ms', moved.inMilliseconds);
  metric('${label}_buffered_ms',
      controller.player.bufferedPosition.inMilliseconds);
  expect(moved.inMilliseconds, greaterThanOrEqualTo(1500),
      reason: '$label: status is ${controller.status.name} but the position '
          'moved only ${moved.inMilliseconds} ms over 2000 ms');
}

/// The player's position must stay put (under 0.2 s over 2 s).
Future<void> expectFrozen(SoundController controller, String label) async {
  final moved = await positionMovedOver(controller, const Duration(seconds: 2));
  metric('${label}_moved_ms', moved.inMilliseconds);
  expect(moved.inMilliseconds, lessThan(200),
      reason: '$label: the position moved ${moved.inMilliseconds} ms over '
          '2000 ms while paused');
}

/// play, advancing; pause (the notification path), frozen; resume, advancing;
/// stop. [label] prefixes the metrics.
Future<void> checkStationLifecycle(
  WrapperAudioHandler handler,
  NinjaSound station,
  String label,
) async {
  await handler.registerSounds([station]);
  final controller = controllerFor(handler, station.path);

  // play: `playing` (not `loading`) and a moving position.
  final started = Stopwatch()..start();
  startWithoutAwaiting(handler.ninjaPlay(station.path), 'play $label');
  await waitForStatus(controller, PlaybackStatus.playing,
      timeout: const Duration(seconds: 15));
  metric('${label}_playing_after_ms', started.elapsedMilliseconds);
  await expectAdvancing(controller, '${label}_play');

  // pause: pauseAll() is what the notification's pause button calls.
  await handler.pauseAll().timeout(const Duration(seconds: 10));
  await waitForStatus(controller, PlaybackStatus.paused);
  await Future<void>.delayed(const Duration(milliseconds: 500));
  await expectFrozen(controller, '${label}_paused');

  // resume: playAllPaused(); its Future does not complete while a stream plays.
  startWithoutAwaiting(handler.playAllPaused(), 'resume $label');
  await waitForStatus(controller, PlaybackStatus.playing,
      timeout: const Duration(seconds: 15));
  await expectAdvancing(controller, '${label}_resumed');

  // stop.
  await handler.ninjaStop(station.path).timeout(const Duration(seconds: 10));
  await waitForStatus(controller, PlaybackStatus.notInitialized);
}
