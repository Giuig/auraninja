// Radio on the emulator, against scripts/ci/loop_stream.py running on the runner
// (reached as 10.0.2.2:8099). The station is added the way a user adds one: a
// user-added stream NinjaSound in the internet-radio category.
//
//  lifecycle  play (status AND position), pause/resume via pauseAll()/
//             playAllPaused(), stop
//  dead URL   a 404 ends in `error` within 15 s, never stuck on `loading`
//             (negative control: shows the status check can fail)
//
// The built-in Yumi Co. Radio runs separately, in radio_third_party_test.dart.
import 'package:auraninja/audio/sound_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/boot.dart';
import 'support/radio.dart';

void main() {
  initE2eBinding();

  testWidgets('local station: plays, pauses, resumes and stops',
      timeout: const Timeout(Duration(minutes: 3)), (tester) async {
    final handler = await ensureBooted();
    await checkStationLifecycle(
      handler,
      radioStation('CI local stream', kLocalStreamUrl),
      'radio_local',
    );
  });

  testWidgets('dead station: ends in error, not stuck on loading',
      timeout: const Timeout(Duration(minutes: 2)), (tester) async {
    final handler = await ensureBooted();
    // The previous test just stopped its station, and Android's SystemUI can
    // answer that with a media-session Stop a moment later; audio_service then
    // runs the handler's stop() -> stopAll(), which would cancel a start that
    // is in flight. Let that settle before starting.
    await Future<void>.delayed(const Duration(seconds: 3));

    final capture = captureDebugPrint();
    try {
      final dead = radioStation('CI dead stream', kDeadStreamUrl);
      await handler.registerSounds([dead]);
      final controller = controllerFor(handler, dead.path);

      final started = Stopwatch()..start();
      startWithoutAwaiting(handler.ninjaPlay(dead.path), 'play dead stream');
      try {
        await waitForStatus(controller, PlaybackStatus.error,
            timeout: const Duration(seconds: 15));
      } on TestFailure catch (e) {
        final raced =
            capture.lines.any((l) => l.startsWith('[WH] stop() OVERRIDE'));
        fail(raced
            ? '$e (an external media-session stop() ran during the wait)'
            : '$e');
      }
      metric('radio_dead_error_after_ms', started.elapsedMilliseconds);
      expect(controller.status, PlaybackStatus.error);

      await handler.ninjaStop(dead.path);
    } finally {
      capture.restore();
    }
  });
}
