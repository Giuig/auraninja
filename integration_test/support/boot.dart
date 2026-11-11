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
import 'package:integration_test/integration_test.dart';

/// First line of every test file's `main()`: initialises the binding with an
/// unthrottled `debugPrint`.
///
/// The binding makes the `debugPrint` it finds at start-up the one the test
/// framework reports failures through, and the default one throttles to 12 kB
/// per second. The app's `[WH]` lines are long, so on the runner the backlog
/// ran seconds behind the test, and the process ended before the framework's
/// own failure dump left the queue: a red test said only "See exception logs
/// above" and the log stopped at an arbitrary, older card (run 43020801834).
/// Synchronous printing has no queue, so nothing can be lost or lag.
IntegrationTestWidgetsFlutterBinding initE2eBinding() {
  debugPrint = debugPrintSynchronously;
  return IntegrationTestWidgetsFlutterBinding.ensureInitialized();
}

Future<WrapperAudioHandler>? _booted;

/// Starts SoLoud and the audio handler once per process, as `main()` does.
Future<WrapperAudioHandler> ensureBooted() => _booted ??= _boot();

Future<WrapperAudioHandler> _boot() async {
  await SoLoud.instance.init();
  return initAudioHandler();
}

/// Collects every `debugPrint` line (the app's `[SC:...]` lines) while still
/// forwarding it, unchanged, to the original callback (a tee: nothing a test
/// or the framework prints is swallowed). [restore] must run in a `finally`:
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
/// tree, only the audio handler. [stateNow] is read when the wait times out
/// (not when it starts), so the failure says what the state was at the end.
Future<void> waitUntil(
  bool Function() done, {
  required Duration timeout,
  required String what,
  String Function()? stateNow,
  Duration poll = const Duration(milliseconds: 50),
}) async {
  final sw = Stopwatch()..start();
  while (!done()) {
    if (sw.elapsed > timeout) {
      fail('Timed out after ${timeout.inSeconds} s waiting for: $what'
          '${stateNow == null ? '' : ' (${stateNow()})'}');
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
      what: '${controller.sound.name} to reach ${status.name}',
      stateNow: () => 'status ${controller.status.name}',
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
