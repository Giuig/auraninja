// Shared helpers for the emulator tests in integration_test/.
//
// Each test file runs in its own `flutter test` process (scripts/ci/
// run_android_e2e.sh), because AudioService.init may run only once per
// process. Inside one process ensureBooted() is idempotent.
import 'dart:async';
import 'dart:io';

import 'package:auraninja/audio/wrapper_audio_handler.dart';
import 'package:auraninja/bootstrap.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

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
