// Memory is given back, measured in this process (PSS from /proc/self/smaps_rollup).
// Every gate is a delta against the idle reading taken inside the same run; the
// numbers are never compared with a phone or with another run.
//
//  A4        play and stop the 10 largest sounds one after another: the process
//            ends within kMemoryMarginKb of its idle reading (the P1 leak, where
//            stop() kept the decoded source, was ~+220 MB)
//  Stop All  five sounds together, then the real WrapperAudioHandler.stopAll()
//
// Each test first checks it can see memory at all (a vacuity guard): while the
// sound(s) play, PSS must sit well above idle. Without it a broken meter would
// pass the "memory came back" check trivially.
//
// Each test starts with releaseAll(): it frees whatever an earlier test left
// decoded, so a leak shows up in the test that caused it and cannot hide in the
// next test's idle reading.
import 'package:auraninja/audio/sound_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/assets.dart';
import 'support/boot.dart';

const _stopAllPaths = [
  'assets/sounds/rain/light-rain.ogg',
  'assets/sounds/nature/birds.ogg',
  'assets/sounds/nature/wind.ogg',
  'assets/sounds/places/cafe.ogg',
  'assets/sounds/nature/river.ogg',
];

void main() {
  initE2eBinding();

  testWidgets('A4: playing and stopping the 10 largest sounds frees memory',
      timeout: const Timeout(Duration(minutes: 10)), (tester) async {
    final handler = await ensureBooted();
    final assets = {for (final a in await loadSoundAssets()) a.path: a};
    final sounds = localSounds();
    await handler.registerSounds(sounds);

    // Deterministic: largest decoded size first, ties by path.
    final largest = sounds.map((s) => assets[s.path]!).toList()
      ..sort((a, b) {
        final bySize = b.decodedBytes.compareTo(a.decodedBytes);
        return bySize != 0 ? bySize : a.path.compareTo(b.path);
      });
    final ten = largest.take(10).toList();

    await releaseAll(handler);
    final idle = await settledIdlePssKb();

    var playingPss = 0;
    for (var i = 0; i < ten.length; i++) {
      final path = ten[i].path;
      final controller =
          handler.allControllers.firstWhere((c) => c.sound.path == path);
      await playAndWait(handler, path);
      if (i == 0) {
        await Future<void>.delayed(const Duration(seconds: 1));
        playingPss = pssKb().kb;
      }
      await Future<void>.delayed(const Duration(seconds: 3));
      await handler.ninjaStop(path);
      await waitForStatus(controller, PlaybackStatus.notInitialized);
    }

    await Future<void>.delayed(const Duration(seconds: 10));
    final after = pssKb().kb;

    metric('a4_idle_kb', idle);
    metric('a4_largest_playing_kb', playingPss);
    metric('a4_after_kb', after);
    metric('a4_delta_kb', after - idle);
    metric('a4_largest', ten.first.path.split('/').last);

    final largestKb = ten.first.decodedBytes ~/ 1024;
    expect(playingPss, greaterThanOrEqualTo(idle + largestKb ~/ 2),
        reason: 'vacuity guard: PSS while ${ten.first.path} plays '
            '($playingPss kB) is not above idle ($idle kB) by half its decoded '
            'size ($largestKb kB): the meter cannot see decoded audio');
    expect(after, lessThanOrEqualTo(idle + kMemoryMarginKb),
        reason: 'memory did not come back after 10 play/stop cycles: idle '
            '$idle kB, after $after kB, delta ${after - idle} kB, '
            'margin $kMemoryMarginKb kB');
  });

  testWidgets('Stop All frees the memory of sounds playing together',
      timeout: const Timeout(Duration(minutes: 10)), (tester) async {
    final capture = captureDebugPrint();
    try {
      final handler = await ensureBooted();
      final assets = {for (final a in await loadSoundAssets()) a.path: a};
      await handler.registerSounds(localSounds());
      final controllers = [
        for (final p in _stopAllPaths)
          handler.allControllers.firstWhere((c) => c.sound.path == p),
      ];
      final decodedKb = _stopAllPaths
              .map((p) => assets[p]!.decodedBytes)
              .fold<int>(0, (a, b) => a + b) ~/
          1024;

      await releaseAll(handler);
      final idle = await settledIdlePssKb();

      // As a mix starts: all at once, each with a 4 s limit (mixes_page.dart).
      await Future.wait(_stopAllPaths.map(
        (p) => handler.ninjaPlay(p).timeout(const Duration(seconds: 4)),
      ));
      for (final c in controllers) {
        await waitForStatus(c, PlaybackStatus.playing);
      }
      await Future<void>.delayed(const Duration(seconds: 2));
      final playingPss = pssKb().kb;

      await handler.stopAll();
      for (final c in controllers) {
        await waitForStatus(c, PlaybackStatus.notInitialized);
      }
      final stopAllCalls = capture.lines
          .where((l) => l.contains('[WH] stopAll() called'))
          .length;

      await Future<void>.delayed(const Duration(seconds: 10));
      final after = pssKb().kb;

      metric('stopall_idle_kb', idle);
      metric('stopall_playing_kb', playingPss);
      metric('stopall_after_kb', after);
      metric('stopall_delta_kb', after - idle);

      expect(stopAllCalls, 1,
          reason: 'one "[WH] stopAll() called" line, got $stopAllCalls');
      expect(playingPss, greaterThanOrEqualTo(idle + decodedKb * 8 ~/ 10),
          reason: 'vacuity guard: PSS with the five sounds playing '
              '($playingPss kB) is not above idle ($idle kB) by 0.8 x their '
              'decoded size ($decodedKb kB)');
      expect(after, lessThanOrEqualTo(idle + kMemoryMarginKb),
          reason: 'Stop All did not give the memory back: idle $idle kB, '
              'after $after kB, delta ${after - idle} kB, '
              'margin $kMemoryMarginKb kB');
    } finally {
      capture.restore();
    }
  });
}
