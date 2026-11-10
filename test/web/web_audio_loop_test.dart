@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:auraninja/audio/web_audio_seamless_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

// Renders the REAL WebAudioSeamlessPlayer graph into an OfflineAudioContext.
//
// The old scheduler tops itself up from a wall-clock timer (every 500 ms)
// reading ctx.currentTime, which an offline context only advances while it
// renders. So a test that needs the scheduler to keep running past its first
// look-ahead (3 s) pauses the render with OfflineAudioContext.suspend(),
// waits real time so the timer fires with currentTime at the suspend point,
// then resumes. That is exactly what a live context does continuously. An
// implementation without timers (native loop) is unaffected by the waits.

const int _sr = 44100;
const double _freq = 441.0; // exactly 100 samples per cycle at 44.1 kHz

web.OfflineAudioContext _offline(double seconds) =>
    web.OfflineAudioContext(2.toJS, (seconds * _sr).round(), _sr);

web.AudioBuffer _sine(web.BaseAudioContext ctx, double seconds) {
  final n = (seconds * _sr).round();
  final buf = ctx.createBuffer(1, n, _sr);
  final d = buf.getChannelData(0).toDart;
  for (var i = 0; i < n; i++) {
    d[i] = math.sin(2 * math.pi * _freq * i / _sr);
  }
  return buf;
}

web.AudioBuffer _noise(web.BaseAudioContext ctx, double seconds) {
  final n = (seconds * _sr).round();
  final buf = ctx.createBuffer(1, n, _sr);
  final d = buf.getChannelData(0).toDart;
  final rnd = math.Random(42); // seeded: the same noise on every run
  for (var i = 0; i < n; i++) {
    d[i] = rnd.nextDouble() * 2 - 1;
  }
  return buf;
}

typedef _Action = FutureOr<void> Function();

/// Renders [ctx], running each action while the render is paused at its time.
/// [realWait] is real time spent paused at each point (see the note above).
Future<Float32List> _render(
  web.OfflineAudioContext ctx,
  Map<double, _Action> actions, {
  Duration realWait = Duration.zero,
}) async {
  final pending = <Future<void>>[];
  for (final e in actions.entries) {
    pending.add(ctx.suspend(e.key).toDart.then((_) async {
      await e.value();
      if (realWait > Duration.zero) await Future<void>.delayed(realWait);
      await ctx.resume().toDart;
    }));
  }
  final out = await ctx.startRendering().toDart;
  await Future.wait(pending);
  return out.getChannelData(0).toDart;
}

double _rms(Float32List y, double fromS, double toS) {
  final a = (fromS * _sr).round(), b = (toS * _sr).round();
  var sum = 0.0;
  for (var i = a; i < b; i++) {
    sum += y[i] * y[i];
  }
  return math.sqrt(sum / (b - a));
}

double _db(double ratio) => 20 * math.log(ratio) / math.ln10;

void main() {
  test('(a) seam: 3 wraps of an integer-cycle sine match the ideal sine',
      () async {
    final ctx = _offline(4.0);
    final player = WebAudioSeamlessPlayer.withContext(ctx, _sine(ctx, 1.0));
    await player.play(volume: 1.0);
    final y = await _render(
      ctx,
      {
        for (final t in [0.5, 1.5, 2.5]) t: () {}
      },
      realWait: const Duration(milliseconds: 650),
    );
    await player.stop();

    // Ideal output: the same sine at gain 1, with amplitude and phase fitted
    // on a clean stretch (no wrap in it) so the start time is not assumed.
    const fitFrom = 20000; // 0.45 s, a whole number of cycles from here
    var sa = 0.0, ca = 0.0;
    for (var i = fitFrom; i < fitFrom + 20000; i++) {
      final ph = 2 * math.pi * _freq * i / _sr;
      sa += y[i] * math.sin(ph);
      ca += y[i] * math.cos(ph);
    }
    final a = sa / 10000, b = ca / 10000; // 2/N with N = 20000
    final from = (0.2 * _sr).round(), to = (3.9 * _sr).round();
    var maxErr = 0.0;
    for (var i = from; i < to; i++) {
      final ph = 2 * math.pi * _freq * i / _sr;
      final err = (y[i] - (a * math.sin(ph) + b * math.cos(ph))).abs();
      if (err > maxErr) maxErr = err;
    }
    final refRms = math.sqrt((a * a + b * b) / 2);

    // Sliding RMS over exactly one cycle (100 samples) is constant for a
    // pure sine, so any dip is a seam artefact.
    var worstDip = 0.0;
    var acc = 0.0;
    for (var i = from; i < from + 100; i++) {
      acc += y[i] * y[i];
    }
    for (var i = from + 100; i < to; i++) {
      acc += y[i] * y[i] - y[i - 100] * y[i - 100];
      final d = _db(math.sqrt(acc / 100) / refRms);
      if (d < worstDip) worstDip = d;
    }

    printOnFailure('seam: max error ${_db(maxErr).toStringAsFixed(1)} dBFS, '
        'deepest dip ${worstDip.toStringAsFixed(2)} dB');
    expect(refRms * math.sqrt(2), closeTo(1.0, 0.01),
        reason: 'the fit window should carry the full-scale sine');
    expect(_db(maxErr), lessThanOrEqualTo(-60.0),
        reason:
            'max error vs ideal sine: ${_db(maxErr).toStringAsFixed(1)} dBFS');
    expect(worstDip, greaterThanOrEqualTo(-0.1),
        reason: 'deepest dip: ${worstDip.toStringAsFixed(2)} dB');
  });

  test('(b) stop() at 1.5 s leaves silence after 1.5 s + 30 ms', () async {
    final ctx = _offline(3.0);
    final player = WebAudioSeamlessPlayer.withContext(ctx, _sine(ctx, 1.0));
    await player.play(volume: 1.0);
    final y = await _render(ctx, {1.5: () => player.stop()});

    expect(_rms(y, 1.0, 1.4), greaterThan(0.3), reason: 'plays before stop');
    final from = ((1.5 + 0.03) * _sr).round();
    var peak = 0.0;
    for (var i = from; i < y.length; i++) {
      if (y[i].abs() > peak) peak = y[i].abs();
    }
    expect(peak, 0.0, reason: 'peak after stop: $peak');
  });

  test('(c) play/stop x20 then play equals a single source within 0.5 dB',
      () async {
    // Reference: one play().
    final refCtx = _offline(3.0);
    final refPlayer =
        WebAudioSeamlessPlayer.withContext(refCtx, _noise(refCtx, 1.0));
    await refPlayer.play(volume: 0.5);
    final ref = await _render(refCtx, {});
    await refPlayer.stop();

    // 20 play/stop pairs, 10 ms apart, then the real play at 0.45 s. Any
    // source left running (a loop that stop() missed) adds uncorrelated power.
    final ctx = _offline(3.0);
    final player = WebAudioSeamlessPlayer.withContext(ctx, _noise(ctx, 1.0));
    final actions = <double, _Action>{};
    for (var k = 0; k < 40; k++) {
      final t = 0.01 * (k + 1);
      actions[t] =
          k.isEven ? () => player.play(volume: 0.5) : () => player.stop();
    }
    actions[0.45] = () => player.play(volume: 0.5);
    final y = await _render(ctx, actions);
    await player.stop();

    // A window clear of every wrap of both renders (the old scheduler's wraps
    // sit at 1.035/2.02 s for the reference and 1.485/2.47 s here).
    final diff = _db(_rms(y, 1.6, 1.95) / _rms(ref, 1.6, 1.95));
    expect(diff.abs(), lessThanOrEqualTo(0.5),
        reason: 'RMS vs single source: ${diff.toStringAsFixed(2)} dB');
  });

  test('(d) setVolume and fadeTo still ramp on the main gain', () async {
    final ctx = _offline(3.5);
    final player = WebAudioSeamlessPlayer.withContext(ctx, _sine(ctx, 1.0));
    await player.play(volume: 1.0);
    final y = await _render(ctx, {
      0.5: () => player.setVolume(0.25),
      1.5: () => player.fadeTo(0.0, const Duration(seconds: 1)),
    });
    await player.stop();

    const full = 0.7071; // RMS of a full-scale sine
    expect(_db(_rms(y, 0.2, 0.45) / full).abs(), lessThan(0.5),
        reason: 'starts at volume 1.0');
    // setVolume is a smoothed approach (tau 20 ms), not a step.
    final mid = _rms(y, 0.505, 0.515) / full;
    expect(mid, inInclusiveRange(0.27, 0.95), reason: 'mid-ramp gain $mid');
    expect(_db(_rms(y, 0.9, 1.4) / (full * 0.25)).abs(), lessThan(0.5),
        reason: 'settles at 0.25');
    // fadeTo: linear 0.25 -> 0 over 1.5 s..2.5 s, so about 0.125 at 2.0 s.
    expect(_db(_rms(y, 1.98, 2.02) / (full * 0.125)).abs(), lessThan(1.0),
        reason: 'halfway through the fade');
    expect(_rms(y, 2.6, 3.4), lessThan(1e-4), reason: 'silent after the fade');
  });
}
