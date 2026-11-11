// Shared helpers for the emulator tests in integration_test/.
//
// Each test file runs in its own `flutter test` process (scripts/ci/
// run_android_e2e.sh), because AudioService.init may run only once per
// process. Inside one process ensureBooted() is idempotent.
import 'dart:io';

import 'package:auraninja/audio/sound_controller.dart';
import 'package:auraninja/audio/wrapper_audio_handler.dart';
import 'package:auraninja/bootstrap.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_test/flutter_test.dart';

Future<WrapperAudioHandler>? _booted;

/// Starts SoLoud and the audio handler once per process, as `main()` does.
Future<WrapperAudioHandler> ensureBooted() => _booted ??= _boot();

Future<WrapperAudioHandler> _boot() async {
  await SoLoud.instance.init();
  return initAudioHandler();
}

/// Collects every `debugPrint` line (the app's `[SC:...]` lines) while still
/// forwarding it to the original callback. [restore] must run in a `finally`:
/// flutter_test fails a test that leaves `debugPrint` replaced.
class DebugPrintCapture {
  DebugPrintCapture._(this._original) {
    debugPrint = (String? message, {int? wrapWidth}) {
      lines.add(message ?? '');
      _original(message, wrapWidth: wrapWidth);
    };
  }

  final DebugPrintCallback _original;
  final List<String> lines = <String>[];

  void restore() => debugPrint = _original;
}

DebugPrintCapture captureDebugPrint() => DebugPrintCapture._(debugPrint);

/// Resident memory of this process in kB, and where the number came from.
///
/// Read in-process (not by the runner with `dumpsys meminfo`): the test owns
/// the timing (idle, play, stop, settle) and the number sits next to its
/// assertion. Every gate is a delta inside one run, never compared with
/// numbers from another device.
({int kb, String source}) pssKb() {
  try {
    for (final line in File('/proc/self/smaps_rollup').readAsLinesSync()) {
      if (line.startsWith('Pss:')) {
        final kb = int.parse(RegExp(r'\d+').firstMatch(line)!.group(0)!);
        return (kb: kb, source: '/proc/self/smaps_rollup Pss');
      }
    }
  } catch (_) {
    // Fall through to the RSS reading.
  }
  return (
    kb: ProcessInfo.currentRss ~/ 1024,
    source: 'ProcessInfo.currentRss',
  );
}

/// One machine-readable line; the runner script copies these to the summary.
void metric(String name, Object value) =>
    // ignore: avoid_print
    print('E2E_METRIC $name=$value');

/// Memory gate shared by the memory and stress tests: after playing and
/// stopping, the process may sit at most this far above its own idle reading.
/// The P1 leak was +223 MB and a real device measured +12 MB; 60 MB absorbs
/// debug-build and emulator noise but cannot hide a leak of one large sound.
const int kMemoryMarginKb = 60 * 1024;

/// Polls until [done] holds. No frames are pumped: these tests have no widget
/// tree, only the audio handler.
Future<void> waitUntil(
  bool Function() done, {
  required Duration timeout,
  required String what,
  Duration poll = const Duration(milliseconds: 50),
}) async {
  final sw = Stopwatch()..start();
  while (!done()) {
    if (sw.elapsed > timeout) {
      fail('Timed out after ${timeout.inSeconds} s waiting for: $what');
    }
    await Future<void>.delayed(poll);
  }
}

Future<void> waitForStatus(
  SoundController controller,
  PlaybackStatus status, {
  Duration timeout = const Duration(seconds: 5),
}) =>
    waitUntil(
      () => controller.status == status,
      timeout: timeout,
      what: '${controller.sound.name} to reach ${status.name} '
          '(status ${controller.status.name})',
    );

/// Starts [path] through the real handler and waits until it reads `playing`.
Future<void> playAndWait(
  WrapperAudioHandler handler,
  String path, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final controller =
      handler.allControllers.firstWhere((c) => c.sound.path == path);
  final play = handler.ninjaPlay(path);
  await waitForStatus(controller, PlaybackStatus.playing, timeout: timeout);
  await play;
}

/// Frees every decoded source still held. Run at the start of a memory test so
/// one test's leftovers (the very leak a red run reintroduces) cannot shift the
/// next test's idle reading or hide inside its baseline.
Future<void> releaseAll(WrapperAudioHandler handler) async {
  for (final controller in handler.allControllers) {
    await controller.releasePlayer();
  }
}

/// Idle reading of this process: a 5 s settle, then the median of 3 reads 1 s
/// apart.
Future<int> settledIdlePssKb() async {
  await Future<void>.delayed(const Duration(seconds: 5));
  final reads = <int>[];
  for (var i = 0; i < 3; i++) {
    if (i > 0) await Future<void>.delayed(const Duration(seconds: 1));
    reads.add(pssKb().kb);
  }
  reads.sort();
  return reads[1];
}
