import 'dart:async';

import 'package:auraninja/audio/sound_controller.dart';
import 'package:auraninja/audio/soloud_engine.dart';
import 'package:auraninja/model/ninja_sound.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records every call. [loadGate], when set, holds `loadAsset` until completed.
class FakeSoloudEngine extends SoloudEngine {
  final List<String> calls = [];
  int _nextId = 0;
  Completer<void>? loadGate;
  final List<Object> disposedSources = [];

  int get loadCount => calls.where((c) => c.startsWith('loadAsset')).length;
  int get disposeCount => disposedSources.length;

  @override
  Future<SoloudSource> loadAsset(String path) async {
    calls.add('loadAsset $path');
    final gate = loadGate;
    if (gate != null) await gate.future;
    return 'source#${_nextId++}';
  }

  @override
  Future<SoloudVoice> play(SoloudSource source,
      {bool looping = false, double volume = 1}) async {
    calls.add('play $source');
    return 'voice#${_nextId++}';
  }

  @override
  Future<void> stop(SoloudVoice voice) async => calls.add('stop $voice');

  @override
  Future<void> disposeSource(SoloudSource source) async {
    calls.add('disposeSource $source');
    disposedSources.add(source);
  }

  @override
  Duration getLength(SoloudSource source) => const Duration(seconds: 30);

  @override
  void setVolume(SoloudVoice voice, double volume) {}

  @override
  void fadeVolume(SoloudVoice voice, double to, Duration time) {}
}

NinjaSound localSound() => NinjaSound(
      name: 'Rain',
      category: 'nature',
      icon: 'x',
      path: 'assets/sounds/rain.ogg',
    );

void main() {
  late FakeSoloudEngine engine;

  setUp(() {
    engine = FakeSoloudEngine();
    SoloudEngine.override = engine;
  });

  tearDown(() => SoloudEngine.override = null);

  group('SoundController frees the SoLoud source', () {
    test('(a) stop() after play disposes the source once; next play reloads',
        () async {
      final c = SoundController(localSound());
      await c.load();
      await c.play();
      expect(c.status, PlaybackStatus.playing);
      expect(engine.loadCount, 1);

      await c.stop();

      expect(engine.disposeCount, 1);
      expect(c.status, PlaybackStatus.notInitialized);

      await c.play();
      expect(engine.loadCount, 2, reason: 'source was cleared, must reload');
      expect(c.status, PlaybackStatus.playing);
    });

    test('(b) stop() during a pending load disposes the late source', () async {
      engine.loadGate = Completer<void>();
      final c = SoundController(localSound());
      final loading = c.load();
      await Future<void>.delayed(Duration.zero);
      expect(c.status, PlaybackStatus.loading);

      await c.stop();
      engine.loadGate!.complete();
      await loading;

      expect(engine.disposeCount, 1, reason: 'late source must be disposed');
      expect(c.status, PlaybackStatus.notInitialized);
    });

    test('(c) pause() does not dispose the source', () async {
      final c = SoundController(localSound());
      await c.load();
      await c.play();

      await c.pause();

      expect(engine.disposeCount, 0);
      expect(c.status, PlaybackStatus.paused);
      await c.play();
      expect(engine.loadCount, 1, reason: 'paused source is reused');
    });

    test('(d) stop() then releasePlayer()/dispose() never double-disposes',
        () async {
      final c = SoundController(localSound());
      await c.load();
      await c.play();

      await c.stop();
      await c.releasePlayer();
      c.dispose();

      expect(engine.disposeCount, 1);
      expect(engine.disposedSources.toSet().length, 1);
    });
  });
}
