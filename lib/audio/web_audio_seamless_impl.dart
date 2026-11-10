import 'dart:js_interop';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

class WebAudioSeamlessPlayer {
  WebAudioSeamlessPlayer();

  /// Builds a player on an existing context and buffer, so tests can render
  /// the real graph into an `OfflineAudioContext`. The caller owns [context]:
  /// the player never resumes or closes it.
  @visibleForTesting
  WebAudioSeamlessPlayer.withContext(
      web.BaseAudioContext context, web.AudioBuffer buffer)
      : _audioContext = context,
        _audioBuffer = buffer,
        _ownsContext = false;

  // A live AudioContext in production, an OfflineAudioContext in tests; the
  // graph code only needs what BaseAudioContext offers.
  web.BaseAudioContext? _audioContext;
  web.AudioBuffer? _audioBuffer;
  bool _ownsContext = true;

  web.GainNode? _mainGainNode;
  web.AudioBufferSourceNode? _source;

  bool _isPlaying = false;
  String? _currentPath;
  // Overwritten by every play() call, which now receives the volume
  // explicitly from its caller (SoundController._volume) instead of relying
  // on this default.
  double _volume = 0.5;

  bool _visibilityListenerAdded = false;

  bool get isPlaying => _isPlaying;

  // Noise colours load and loop their real asset like every other sound. Web
  // used to synthesise 5 s of uniform white noise for all four colours
  // instead, so brown, pink and green all played as white (and far louder
  // than on Android, which always played the files).
  Future<void> loadAsset(String assetPath) async {
    if (_currentPath == assetPath && _audioBuffer != null) return;
    _currentPath = assetPath;

    await stop();
    _audioContext ??= web.AudioContext();
    final ctx = _audioContext!;

    try {
      final webPath = 'assets/$assetPath';
      final response = await web.window.fetch(webPath.toJS).toDart;
      final arrayBuffer = await response.arrayBuffer().toDart;
      _audioBuffer = await ctx.decodeAudioData(arrayBuffer).toDart;
    } catch (e) {
      debugPrint('[WebAudio] Load Error: $e');
      rethrow;
    }
  }

  Future<void> play({required double volume}) async {
    _volume = volume.clamp(0.0, 1.0);
    final ctx = _audioContext;
    if (ctx == null) return;

    if (_ownsContext && ctx.state == 'suspended') {
      await (ctx as web.AudioContext).resume().toDart;
    }

    _stopAllSources();
    _isPlaying = true;
    _ensureVisibilityListener();

    final buffer = _audioBuffer;
    if (buffer == null) return;

    final gainNode = ctx.createGain();
    _mainGainNode = gainNode;
    gainNode.gain.value = _volume;
    gainNode.connect(ctx.destination);

    // One native looping source per play(). The loops are baked to an exact
    // length with their seam crossfaded in the file (scripts/sounds), so the
    // browser's own wrap is gapless. The loop runs on the audio thread, with
    // no JS timer to throttle when the tab is in the background, which is
    // what the old look-ahead scheduler and its 15 ms overlap worked around.
    final source = ctx.createBufferSource();
    source.buffer = buffer;
    source.loop = true;
    source.loopStart = 0;
    source.loopEnd = buffer.duration;
    source.connect(gainNode);
    source.start();
    _source = source;
  }

  /// Registered once per player. Browsers suspend a context the page did not
  /// start in a gesture, and iOS interrupts it (phone call, silent switch):
  /// when the tab is visible again, resume it if it is not running. The loop
  /// itself needs no help.
  void _ensureVisibilityListener() {
    if (_visibilityListenerAdded) return;
    _visibilityListenerAdded = true;
    web.document.addEventListener(
      'visibilitychange',
      (web.Event e) {
        if (_isPlaying && web.document.visibilityState == 'visible') {
          _resumeIfNotRunning();
        }
      }.toJS,
    );
  }

  Future<void> _resumeIfNotRunning() async {
    final ctx = _audioContext;
    if (!_ownsContext || ctx == null) {
      return;
    }
    final state = ctx.state;
    if (state == 'running' || state == 'closed') {
      return;
    }
    try {
      await (ctx as web.AudioContext).resume().toDart;
    } catch (e) {
      debugPrint('[WebAudio] Resume Error: $e');
    }
  }

  Future<void> stop() async {
    _isPlaying = false;
    _stopAllSources();
  }

  /// A looping source never ends on its own, so it has to be stopped, not
  /// just disconnected, or it would keep running (and being mixed) forever.
  void _stopAllSources() {
    final source = _source;
    _source = null;
    if (source != null) {
      source.stop();
      source.disconnect();
    }
    _mainGainNode?.disconnect();
    _mainGainNode = null;
  }

  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    final now = _audioContext?.currentTime ?? 0;
    _mainGainNode?.gain.setTargetAtTime(_volume, now, 0.02);
  }

  /// Schedules a native, AudioContext-clock-driven ramp to [target] over
  /// [duration] — runs on the audio thread, not the JS event loop, so it
  /// keeps going smoothly even if the tab is backgrounded/throttled.
  ///
  /// Deliberately does NOT touch [_volume]: the gain node built in play()
  /// comes from the volume its caller supplies (`SoundController._volume`),
  /// not from this field, so leaving [_volume] untouched here is still safe
  /// — the next play() after a stop() gets the caller's real level again,
  /// no separate restore step needed.
  void fadeTo(double target, Duration duration) {
    final ctx = _audioContext;
    if (ctx == null) return;
    final now = ctx.currentTime;
    final seconds = duration.inMicroseconds / Duration.microsecondsPerSecond;
    final clampedTarget = target.clamp(0.0, 1.0);
    final gain = _mainGainNode?.gain;
    if (gain != null) {
      // Cancel any pending automation (e.g. setVolume's setTargetAtTime)
      // and anchor the ramp at the param's current live value first, or
      // the ramp would jump from whatever was last scheduled instead of
      // where the sound actually is right now.
      gain.cancelScheduledValues(now);
      gain.setValueAtTime(gain.value, now);
      gain.linearRampToValueAtTime(clampedTarget, now + seconds);
    }
  }

  void dispose() {
    stop();
    if (_ownsContext) {
      (_audioContext as web.AudioContext?)?.close();
    }
  }
}

class WebAudioSeamlessManager {
  static final WebAudioSeamlessManager _instance =
      WebAudioSeamlessManager._internal();
  factory WebAudioSeamlessManager() => _instance;
  WebAudioSeamlessManager._internal();

  final Map<String, WebAudioSeamlessPlayer> _players = {};

  WebAudioSeamlessPlayer? get(String path) => _players[path];

  WebAudioSeamlessPlayer getOrCreate(String path) {
    return _players.putIfAbsent(path, () => WebAudioSeamlessPlayer());
  }

  Future<void> stopAll() async {
    for (final player in _players.values) {
      await player.stop();
    }
  }

  Future<void> disposeAll() async {
    for (final player in _players.values) {
      player.dispose();
    }
    _players.clear();
  }

  void remove(String path) {
    final player = _players.remove(path);
    player?.dispose();
  }
}
