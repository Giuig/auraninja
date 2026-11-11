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

  // We keep track of the next start time using the AudioContext clock
  double _nextStartTime = 0.0;
  web.GainNode? _mainGainNode;

  bool _isPlaying = false;
  String? _currentPath;
  // Overwritten by every play() call, which now receives the volume
  // explicitly from its caller (SoundController._volume) instead of relying
  // on this default.
  double _volume = 0.5;

  // To prevent multiple scheduling loops running at once
  int _activeLoopId = 0;

  // How far ahead we keep buffers queued, and how often we top that up.
  // Backgrounded tabs get their JS timers throttled by the browser (commonly
  // clamped to ~1/s), which would starve the old 100ms/50ms margins the
  // instant a tab lost focus — audio would then go silent once whatever was
  // already scheduled ran out, without the controller ever finding out.
  // Several seconds of look-ahead absorbs that throttling; the visibility
  // listener below is the safety net for anything that outlasts it.
  static const double _lookAheadSeconds = 3.0;
  static const Duration _checkInterval = Duration(milliseconds: 500);

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
    _activeLoopId++;
    _ensureVisibilityListener();

    if (_audioBuffer != null) {
      final gainNode = ctx.createGain();
      _mainGainNode = gainNode;
      gainNode.gain.value = _volume;
      gainNode.connect(ctx.destination);

      // Initialize start time to "now" plus a tiny safety buffer
      _nextStartTime = ctx.currentTime + 0.05;
      _scheduleLoop(_activeLoopId);
    }
  }

  /// THE PRO FIX: Recursive scheduling with high-precision look-ahead
  void _scheduleLoop(int loopId) {
    final ctx = _audioContext;
    final buffer = _audioBuffer;
    final mainGain = _mainGainNode;

    if (!_isPlaying ||
        ctx == null ||
        buffer == null ||
        mainGain == null ||
        loopId != _activeLoopId) return;

    // Look-ahead: schedule buffers up to _lookAheadSeconds before they're
    // actually needed, so a throttled recheck timer (background tab) still
    // finds several seconds of already-queued audio instead of running dry.
    while (_nextStartTime < ctx.currentTime + _lookAheadSeconds) {
      _playOneShot(buffer, ctx, mainGain, _nextStartTime);

      // Increment the next start time by buffer duration minus crossfade
      // We use a 15ms crossfade (0.015) to hide OGG encoder gaps.
      const crossfade = 0.015;
      _nextStartTime += (buffer.duration - crossfade);
    }

    // Check again to see if we need to schedule more.
    Future.delayed(_checkInterval, () => _scheduleLoop(loopId));
  }

  /// Registered once per player: when the tab regains visibility, immediately
  /// top up scheduling instead of waiting for the next (possibly still
  /// throttled) periodic check. Catches any gap the look-ahead margin above
  /// wasn't wide enough to cover.
  void _ensureVisibilityListener() {
    if (_visibilityListenerAdded) return;
    _visibilityListenerAdded = true;
    web.document.addEventListener(
      'visibilitychange',
      (web.Event e) {
        if (_isPlaying && web.document.visibilityState == 'visible') {
          _scheduleLoop(_activeLoopId);
        }
      }.toJS,
    );
  }

  void _playOneShot(web.AudioBuffer buffer, web.BaseAudioContext ctx,
      web.GainNode mainGain, double time) {
    final source = ctx.createBufferSource();
    source.buffer = buffer;

    final sliceGain = ctx.createGain();
    const crossfade = 0.015;

    source.connect(sliceGain);
    sliceGain.connect(mainGain);

    // Fade In at the start of THIS specific slice
    sliceGain.gain.setValueAtTime(0, time);
    sliceGain.gain.linearRampToValueAtTime(1.0, time + crossfade);

    // Fade Out at the end of THIS specific slice
    final duration = buffer.duration;
    sliceGain.gain.setValueAtTime(1.0, time + duration - crossfade);
    sliceGain.gain.linearRampToValueAtTime(0, time + duration);

    source.start(time);

    // Clean up nodes after they finish playing to save memory
    source.onended = (web.Event e) {
      source.disconnect();
      sliceGain.disconnect();
    }.toJS;
  }

  Future<void> stop() async {
    _isPlaying = false;
    _activeLoopId++; // Invalidate previous loop
    _stopAllSources();
  }

  void _stopAllSources() {
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
