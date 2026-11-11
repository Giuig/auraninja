// A1: every bundled sound loads through the real SoLoud engine with exactly the
// length its Ogg header declares, and plays and stops through the real handler.
//
//  A1a  the engine, all 48 assets (incl. nature/walk-on-gravel)
//  A1b  the manager, every built-in sound that has a card (the count comes
//       from lib/data/sound_data.dart at run time): ninjaPlay -> playing ->
//       ninjaStop, with the app's own "[SC:<name>] loaded in X ms (len Y ms)" line
//
// Load times are reported as metrics only: emulator timing is relative.
import 'package:auraninja/audio/sound_controller.dart';
import 'package:auraninja/audio/soloud_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/assets.dart';
import 'support/boot.dart';

const _walkOnGravel = 'assets/sounds/nature/walk-on-gravel.ogg';

/// Attempts per card: the first, plus one retry per media-session stop that cut
/// an attempt short (twice at most).
const _maxAttempts = 3;

void main() {
  initE2eBinding();

  testWidgets('A1a: all 48 assets load in the engine with the exact length',
      timeout: const Timeout(Duration(minutes: 10)), (tester) async {
    await ensureBooted();
    final assets = await loadSoundAssets();
    expect(assets.length, 48,
        reason: 'sound assets in the manifest: ${assets.map((a) => a.path)}');
    expect(assets.map((a) => a.path), contains(_walkOnGravel),
        reason: '$_walkOnGravel is not bundled');

    final failures = <String>[];
    for (final a in assets) {
      if (a.info.sampleRate != 44100) {
        failures.add('${a.path}: Ogg header rate ${a.info.sampleRate}');
      }
      try {
        final src = await SoloudEngine.current.loadAsset(a.path);
        try {
          final us = SoloudEngine.current.getLength(src).inMicroseconds;
          if ((us - a.lengthUs).abs() > 1000) {
            failures.add('${a.path}: engine length $us us, header '
                '${a.lengthUs.toStringAsFixed(0)} us (${a.samples} samples)');
          }
        } finally {
          await SoloudEngine.current.disposeSource(src);
        }
      } catch (e) {
        failures.add('${a.path}: load threw $e');
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
    metric('a1a_assets_loaded', assets.length);
  });

  testWidgets('A1b: every card sound plays and stops through the handler',
      timeout: const Timeout(Duration(minutes: 10)), (tester) async {
    final capture = captureDebugPrint();
    try {
      final handler = await ensureBooted();
      final assets = {for (final a in await loadSoundAssets()) a.path: a};
      final sounds = localSounds();
      // The expected count is whatever sound_data.dart declares; it must be
      // non-empty and every card must point at a bundled asset.
      final expected = sounds.length;
      expect(expected, greaterThan(0), reason: 'local sounds with a card');
      expect(sounds.where((s) => !assets.containsKey(s.path)), isEmpty,
          reason: 'a card points at an asset that is not bundled');
      await handler.registerSounds(sounds);

      // The test stops sounds with ninjaStop only. A "[WH] stop() OVERRIDE
      // called" line is the handler's own stop(), reached when the Android
      // media session sends Stop (audio_service's onStop callback): on the CI
      // emulator SystemUI does that at random while this loop plays and stops
      // a card every ~0.25 s, and the handler then abandons the start that is
      // in flight (run 43020801834 and the repro 43024449708).
      int externalStops() => capture.lines
          .where((l) => l.startsWith('[WH] stop() OVERRIDE called'))
          .length;
      final attempts = <String, int>{};

      for (var i = 0; i < sounds.length; i++) {
        final sound = sounds[i];
        final controller = handler.allControllers
            .firstWhere((c) => c.sound.path == sound.path);
        // Printed as it happens (debugPrint is synchronous, see initE2eBinding)
        // so a hang names the card even when no exception text survives.
        metric('a1b_card', '${i + 1}/${sounds.length} ${sound.name}');
        final where = 'card ${i + 1}/${sounds.length} "${sound.name}" '
            '(${sound.path})';
        for (var attempt = 1;; attempt++) {
          final stopsBefore = externalStops();
          try {
            await playAndWait(handler, sound.path);
            await handler.ninjaStop(sound.path);
            await waitForStatus(controller, PlaybackStatus.notInitialized);
            break;
          } catch (e) {
            // The only retry: an attempt cut short by a media-session stop
            // that this test did not issue (see externalStops). Anything else,
            // or a third attempt, is a failure that names the card.
            final cut = externalStops() - stopsBefore;
            if (cut == 0 || attempt == _maxAttempts) {
              fail('$where failed on attempt $attempt'
                  '${cut == 0 ? '' : ' (a media-session stop cut it short)'}: '
                  '$e');
            }
            attempts[sound.name] = attempt + 1;
            metric('a1b_external_stop', '$where attempt $attempt: $e');
            await waitForStatus(controller, PlaybackStatus.notInitialized);
          }
        }
      }

      final loaded =
          RegExp(r'^\[SC:(.*)\] loaded in (\d+) ms \(len (\d+) ms\)$');
      final seen = <String, ({int loadMs, int lenMs})>{};
      final linesPerName = <String, int>{};
      var loadedLines = 0;
      for (final line in capture.lines) {
        final m = loaded.firstMatch(line);
        if (m == null) continue;
        loadedLines++;
        linesPerName[m.group(1)!] = (linesPerName[m.group(1)!] ?? 0) + 1;
        seen[m.group(1)!] =
            (loadMs: int.parse(m.group(2)!), lenMs: int.parse(m.group(3)!));
      }
      expect(seen.length, expected,
          reason: 'each sound has a "[SC:<name>] loaded in" line; '
              '${seen.length} distinct of $expected, names seen: '
              '${seen.keys.join(', ')}');
      // One line per sound, except a card that needed a second attempt (an
      // aborted load prints nothing, a load that finished before the stop
      // prints once more).
      final extra = <String>[
        for (final sound in sounds)
          if ((linesPerName[sound.name] ?? 0) > (attempts[sound.name] ?? 1))
            '${sound.name}: ${linesPerName[sound.name]} lines for '
                '${attempts[sound.name] ?? 1} attempt(s)',
      ];
      expect(extra, isEmpty,
          reason: 'more "loaded in" lines than attempts: ${extra.join('; ')}');

      final failures = <String>[];
      for (final sound in sounds) {
        final got = seen[sound.name];
        if (got == null) {
          failures.add('${sound.name}: no loaded line');
          continue;
        }
        // The app prints whole milliseconds (truncated): within 1 ms.
        final wantMs = assets[sound.path]!.lengthUs / 1000;
        if ((got.lenMs - wantMs).abs() > 1) {
          failures.add('${sound.name}: len ${got.lenMs} ms, header $wantMs ms');
        }
      }
      expect(failures, isEmpty, reason: failures.join('\n'));

      final errorLines =
          capture.lines.where((l) => RegExp(r'status: .* → error').hasMatch(l));
      expect(errorLines, isEmpty,
          reason: 'a controller went to error: ${errorLines.join(' | ')}');
      for (final c in handler.allControllers) {
        expect(c.status, isNot(PlaybackStatus.error),
            reason: '${c.sound.name} (${c.sound.path}) ended in error');
      }

      final times = seen.values.map((v) => v.loadMs).toList()..sort();
      metric('a1b_loaded_lines', loadedLines);
      metric('a1b_cards_retried', attempts.length);
      metric('a1b_load_ms_median', times[times.length ~/ 2]);
      metric('a1b_load_ms_max', times.last);
    } finally {
      capture.restore();
    }
  });
}
