import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

/// Opaque handle to a loaded SoLoud source. The default engine stores an
/// [AudioSource] in it; test fakes may store anything.
typedef SoloudSource = Object;

/// Opaque handle to a playing SoLoud voice. The default engine stores a
/// [SoundHandle] in it; test fakes may store anything.
typedef SoloudVoice = Object;

/// Thin seam over `SoLoud.instance`, so tests can reach the SoLoud call sites
/// of `SoundController` (and, through it, `JustAudioSoundManager`) without a
/// native engine. Production code always uses [SoloudEngine.current], which
/// delegates to `SoLoud.instance` one-to-one.
abstract class SoloudEngine {
  const SoloudEngine();

  static const SoloudEngine _default = _DefaultSoloudEngine();
  static SoloudEngine? _override;

  /// The engine in use: the test override if one is set, else SoLoud itself.
  static SoloudEngine get current => _override ?? _default;

  /// Replaces the engine for tests. Pass null to restore the default.
  @visibleForTesting
  static set override(SoloudEngine? engine) => _override = engine;

  Future<SoloudSource> loadAsset(String path);
  Future<SoloudVoice> play(
    SoloudSource source, {
    bool looping = false,
    double volume = 1,
  });
  Future<void> stop(SoloudVoice voice);
  Future<void> disposeSource(SoloudSource source);
  Duration getLength(SoloudSource source);
  void setVolume(SoloudVoice voice, double volume);
  void fadeVolume(SoloudVoice voice, double to, Duration time);
}

/// Boxes the [SoundHandle] extension type, which is not an [Object] subtype.
class _Voice {
  const _Voice(this.handle);
  final SoundHandle handle;
}

class _DefaultSoloudEngine extends SoloudEngine {
  const _DefaultSoloudEngine();

  @override
  Future<SoloudSource> loadAsset(String path) =>
      SoLoud.instance.loadAsset(path);

  @override
  Future<SoloudVoice> play(
    SoloudSource source, {
    bool looping = false,
    double volume = 1,
  }) async {
    final SoundHandle handle = await SoLoud.instance.play(
      source as AudioSource,
      looping: looping,
      volume: volume,
    );
    return _Voice(handle);
  }

  @override
  Future<void> stop(SoloudVoice voice) =>
      SoLoud.instance.stop((voice as _Voice).handle);

  @override
  Future<void> disposeSource(SoloudSource source) =>
      SoLoud.instance.disposeSource(source as AudioSource);

  @override
  Duration getLength(SoloudSource source) =>
      SoLoud.instance.getLength(source as AudioSource);

  @override
  void setVolume(SoloudVoice voice, double volume) =>
      SoLoud.instance.setVolume((voice as _Voice).handle, volume);

  @override
  void fadeVolume(SoloudVoice voice, double to, Duration time) =>
      SoLoud.instance.fadeVolume((voice as _Voice).handle, to, time);
}
