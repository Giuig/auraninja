import 'dart:js_interop';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Seamless audio player using Web Audio API for gapless looping on web.
///
/// For noise sounds: generates noise programmatically with no loop points.
/// For other sounds: uses single source with loop=true and loop point trimming.
class WebAudioSeamlessPlayer {
  web.AudioContext? _audioContext;
  web.AudioBuffer? _audioBuffer;

  // Noise generator nodes
  web.AudioBufferSourceNode? _noiseSource;
  web.GainNode? _noiseGain;
  web.GainNode? _masterGain;
  web.BiquadFilterNode? _filterNode;

  // Single source for non-noise sounds
  web.AudioBufferSourceNode? _sourceNode;
  web.GainNode? _gainNode;

  double _volume = 0.5;
  bool _isPlaying = false;
  String? _currentPath;
  bool _isNoise = false;
  String _noiseType = 'white'; // white, pink, brown, green

  bool get isPlaying => _isPlaying;
  double get volume => _volume;

  /// Determine noise type from path
  String _getNoiseTypeFromPath(String path) {
    if (path.contains('white')) return 'white';
    if (path.contains('pink')) return 'pink';
    if (path.contains('brown')) return 'brown';
    if (path.contains('green')) return 'green';
    return 'white';
  }

  /// Load an audio asset via fetch and decode to AudioBuffer.
  Future<void> loadAsset(String assetPath, {bool isNoise = false}) async {
    if (_currentPath == assetPath && _audioBuffer != null) {
      return; // Already loaded
    }

    _isNoise = isNoise;
    _noiseType = _getNoiseTypeFromPath(assetPath);

    // Stop and cleanup previous
    await stop();

    // Create audio context (suspended until user interaction)
    _audioContext ??= web.AudioContext();

    // For noise, we generate it programmatically - no need to load file
    if (_isNoise) {
      _currentPath = assetPath;
      debugPrint('[WebAudioSeamless] Prepared noise: $_noiseType');
      return;
    }

    // Fetch asset and decode using Web Audio API for non-noise sounds
    // Flutter web serves assets with 'assets/' prefix, so prepend it
    try {
      final webPath = 'assets/$assetPath';
      final response = await web.window.fetch(webPath.toJS).toDart;
      final arrayBuffer = await response.arrayBuffer().toDart;
      _audioBuffer = await _audioContext!.decodeAudioData(arrayBuffer).toDart;
      _currentPath = assetPath;
      debugPrint('[WebAudioSeamless] Loaded: $assetPath');
    } catch (e) {
      debugPrint('[WebAudioSeamless] Error loading $assetPath: $e');
      rethrow;
    }
  }

  /// Play the loaded audio with seamless looping.
  Future<void> play() async {
    if (_audioContext == null) {
      debugPrint('[WebAudioSeamless] Cannot play - no audio context');
      return;
    }

    // Resume audio context if suspended (required after user interaction)
    if (_audioContext!.state == 'suspended') {
      await _audioContext!.resume().toDart;
    }

    // Stop any existing playback
    _stopAllSources();

    if (_isNoise) {
      _playGeneratedNoise();
    } else if (_audioBuffer != null) {
      _playWithTrimmedLoop();
    }

    _isPlaying = true;
    debugPrint(
        '[WebAudioSeamless] Playing (noise: $_isNoise, type: $_noiseType)');
  }

  /// Generate and play noise using procedural generation.
  ///
  /// Creates a 30-second noise buffer with proper filtering.
  /// 30 seconds is long enough that looping is imperceptible.
  void _playGeneratedNoise() {
    final ctx = _audioContext!;
    final sampleRate = ctx.sampleRate;
    final duration = 30.0; // 30 seconds - long enough for imperceptible loop
    final length = (sampleRate * duration).toInt();

    // Create a buffer filled with white noise
    final buffer = ctx.createBuffer(1, length, sampleRate);
    final channelData = buffer.getChannelData(0).toDart;
    final random = Random();

    // Generate white noise - use Dart's Float32List
    for (int i = 0; i < length; i++) {
      channelData[i] = random.nextDouble() * 2.0 - 1.0;
    }

    // Create source with the noise buffer
    _noiseSource = ctx.createBufferSource();
    _noiseSource!.buffer = buffer;
    _noiseSource!.loop = true;

    // Create filter based on noise type
    _filterNode = ctx.createBiquadFilter();
    _setupFilterForNoiseType(_filterNode!, _noiseType, sampleRate);

    // Create master gain
    _masterGain = ctx.createGain();
    _masterGain!.gain.value = _volume;
    _masterGain!.connect(ctx.destination);

    // Connect: source -> filter -> master gain -> destination
    _noiseSource!.connect(_filterNode!);
    _filterNode!.connect(_masterGain!);

    // Start playback
    _noiseSource!.start();
  }

  /// Configure filter based on noise color.
  ///
  /// White: No filter (equal energy per frequency)
  /// Pink: -3dB/octave rolloff (equal energy per octave)
  /// Brown: -6dB/octave rolloff (equal energy per decade)
  /// Green: Band-pass around 500Hz (optimized for relaxation)
  void _setupFilterForNoiseType(
      web.BiquadFilterNode filter, String type, double sampleRate) {
    switch (type) {
      case 'pink':
        // Low shelf filter for -3dB/octave effect
        filter.type = 'lowshelf';
        filter.frequency.value = 1000;
        filter.gain.value = -3;
        filter.Q.value = 0.5;
        break;
      case 'brown':
        // Low pass filter for -6dB/octave effect
        filter.type = 'lowpass';
        filter.frequency.value = 500;
        filter.Q.value = 0.7;
        break;
      case 'green':
        // Band pass centered around 500Hz (relaxation sweet spot)
        filter.type = 'bandpass';
        filter.frequency.value = 500;
        filter.Q.value = 0.5;
        break;
      case 'white':
      default:
        // No filtering needed for white noise
        filter.type = 'allpass';
        filter.frequency.value = 20000;
        break;
    }
  }

  /// Play non-noise sounds with trimmed loop points.
  void _playWithTrimmedLoop() {
    final buffer = _audioBuffer!;
    final ctx = _audioContext!;

    // Create gain node for volume control
    _gainNode = ctx.createGain();
    _gainNode!.gain.value = _volume;
    _gainNode!.connect(ctx.destination);

    // Create buffer source with seamless looping
    _sourceNode = ctx.createBufferSource();
    _sourceNode!.buffer = buffer;
    _sourceNode!.loop = true;

    // Trim loop points by small amount to avoid boundary clicks
    final sampleRate = buffer.sampleRate;
    final trimSamples = (sampleRate * 0.002).round(); // 2ms trim
    if (buffer.length > trimSamples * 4) {
      _sourceNode!.loopStart = trimSamples / sampleRate;
      _sourceNode!.loopEnd = (buffer.length - trimSamples) / sampleRate;
    }

    _sourceNode!.connect(_gainNode!);
    _sourceNode!.start();
  }

  /// Stop playback.
  Future<void> stop() async {
    _stopAllSources();
    _isPlaying = false;
  }

  void _stopAllSources() {
    // Stop noise source
    try {
      _noiseSource?.stop();
    } catch (_) {}
    _noiseSource?.disconnect();
    _filterNode?.disconnect();
    _noiseGain?.disconnect();
    _noiseSource = null;
    _filterNode = null;
    _noiseGain = null;

    // Stop single source
    try {
      _sourceNode?.stop();
    } catch (_) {}
    _sourceNode?.disconnect();
    _gainNode?.disconnect();
    _sourceNode = null;
    _gainNode = null;

    // Stop master gain
    _masterGain?.disconnect();
    _masterGain = null;
  }

  /// Set volume (0.0 to 1.0).
  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    if (_masterGain != null) {
      _masterGain!.gain.value = _volume;
    }
    if (_gainNode != null) {
      _gainNode!.gain.value = _volume;
    }
  }

  /// Release resources.
  Future<void> dispose() async {
    stop();
    _audioBuffer = null;
    _currentPath = null;
    if (_audioContext != null) {
      _audioContext!.close();
      _audioContext = null;
    }
  }
}

/// Manager for multiple WebAudioSeamlessPlayer instances (one per sound).
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
      await player.dispose();
    }
    _players.clear();
  }

  void remove(String path) {
    final player = _players.remove(path);
    player?.dispose();
  }
}
