import 'dart:js_interop';
import 'dart:math';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

class WebAudioSeamlessPlayer {
  web.AudioContext? _audioContext;
  web.AudioBuffer? _audioBuffer;

  web.AudioBufferSourceNode? _noiseSource;
  web.GainNode? _masterGain;

  // We keep track of the next start time using the AudioContext clock
  double _nextStartTime = 0.0;
  web.GainNode? _mainGainNode;

  bool _isPlaying = false;
  String? _currentPath;
  bool _isNoise = false;
  String _noiseType = 'white';
  double _volume = 0.5;

  // To prevent multiple scheduling loops running at once
  int _activeLoopId = 0;

  bool get isPlaying => _isPlaying;

  Future<void> loadAsset(String assetPath, {bool isNoise = false}) async {
    if (_currentPath == assetPath && _audioBuffer != null) return;
    _isNoise = isNoise;
    _currentPath = assetPath;

    await stop();
    _audioContext ??= web.AudioContext();

    if (!_isNoise) {
      try {
        final webPath = 'assets/$assetPath';
        final response = await web.window.fetch(webPath.toJS).toDart;
        final arrayBuffer = await response.arrayBuffer().toDart;
        _audioBuffer = await _audioContext!.decodeAudioData(arrayBuffer).toDart;
      } catch (e) {
        debugPrint('[WebAudio] Load Error: $e');
        rethrow;
      }
    }
  }

  Future<void> play() async {
    final ctx = _audioContext;
    if (ctx == null) return;

    if (ctx.state == 'suspended') await ctx.resume().toDart;

    _stopAllSources();
    _isPlaying = true;
    _activeLoopId++;

    if (_isNoise) {
      _playGeneratedNoise();
    } else if (_audioBuffer != null) {
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

    // Look-ahead: We schedule the next buffer 100ms before it's actually needed
    // This ensures that even if the CPU is busy, the audio hardware already has the command.
    while (_nextStartTime < ctx.currentTime + 0.1) {
      _playOneShot(buffer, ctx, mainGain, _nextStartTime);

      // Increment the next start time by buffer duration minus crossfade
      // We use a 15ms crossfade (0.015) to hide OGG encoder gaps.
      const crossfade = 0.015;
      _nextStartTime += (buffer.duration - crossfade);
    }

    // Check again in 50ms to see if we need to schedule more
    Future.delayed(
        const Duration(milliseconds: 50), () => _scheduleLoop(loopId));
  }

  void _playOneShot(web.AudioBuffer buffer, web.AudioContext ctx,
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

  void _playGeneratedNoise() {
    final ctx = _audioContext;
    if (ctx == null) return;

    final buffer =
        ctx.createBuffer(1, (ctx.sampleRate * 5).toInt(), ctx.sampleRate);
    final data = buffer.getChannelData(0).toDart;
    final rand = Random();
    for (int i = 0; i < data.length; i++) {
      data[i] = rand.nextDouble() * 2 - 1;
    }

    final source = ctx.createBufferSource();
    source.buffer = buffer;
    source.loop = true;
    _noiseSource = source;

    final gain = ctx.createGain();
    gain.gain.value = _volume;
    _masterGain = gain;

    source.connect(gain);
    gain.connect(ctx.destination);
    source.start();
  }

  Future<void> stop() async {
    _isPlaying = false;
    _activeLoopId++; // Invalidate previous loop
    _stopAllSources();
  }

  void _stopAllSources() {
    try {
      _noiseSource?.stop();
    } catch (_) {}
    _noiseSource?.disconnect();
    _mainGainNode?.disconnect();
    _masterGain?.disconnect();
    _mainGainNode = null;
    _masterGain = null;
  }

  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    final now = _audioContext?.currentTime ?? 0;
    _mainGainNode?.gain.setTargetAtTime(_volume, now, 0.02);
    _masterGain?.gain.setTargetAtTime(_volume, now, 0.02);
  }

  void dispose() {
    stop();
    _audioContext?.close();
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
