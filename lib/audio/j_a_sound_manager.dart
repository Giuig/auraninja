import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:auraninja/audio/sound_controller.dart';
import 'package:auraninja/audio/web_audio_seamless.dart';
import 'package:auraninja/model/ninja_sound.dart';

class JustAudioSoundManager with ChangeNotifier {
  static final JustAudioSoundManager _instance =
      JustAudioSoundManager._internal();
  factory JustAudioSoundManager() => _instance;
  JustAudioSoundManager._internal();

  final Map<String, SoundController> _controllers = {};
  final ValueNotifier<Map<String, String>> _metadataNotifier =
      ValueNotifier({});
  ValueNotifier<Map<String, String>> get metadataNotifier => _metadataNotifier;

  int _streamPlaybackToken = 0;
  int _binauralPlaybackToken = 0;
  int _noisePlaybackToken = 0;
  int _globalStopToken = 0;

  void registerSounds(List<NinjaSound> sounds) {
    for (final sound in sounds) {
      if (!_controllers.containsKey(sound.path)) {
        final controller = SoundController(sound);
        controller.addListener(_onControllerStateChanged);
        _controllers[sound.path] = controller;
      }
    }
  }

  SoundController? get(String path) => _controllers[path];

  List<SoundController> get allControllers => _controllers.values.toList();

  List<SoundController> get activeControllers =>
      _controllers.values.where((c) => c.isPlaying).toList();

  bool get isAnyPlaying =>
      _controllers.values.any((c) => c.status == PlaybackStatus.playing);

  bool get isAnyLoading =>
      _controllers.values.any((c) => c.status == PlaybackStatus.loading);

  Map<String, PlaybackStatus> get allStatuses => {
        for (var entry in _controllers.entries) entry.key: entry.value.status,
      };

  Map<String, PlaybackStatus> get activeStatuses => {
        for (var entry in _controllers.entries)
          if (entry.value.status == PlaybackStatus.playing ||
              entry.value.status == PlaybackStatus.paused)
            entry.key: entry.value.status,
      };

  Future<void> play(String path) async {
    final controller = _controllers[path];
    if (controller == null) return;

    final isStream = controller.sound.isStream;
    final isBinaural = controller.sound.isBinaural;
    final isNoise = controller.sound.isNoise; // New: Check for isNoise

    final requestedStopToken = _globalStopToken; // capture stop priority

    int requestedPlaybackToken = 0;

    if (isStream) {
      requestedPlaybackToken = ++_streamPlaybackToken;

      await Future.wait(_controllers.values
          .where((c) =>
              c.sound.isStream &&
              c.sound.path != path &&
              (c.isPlaying ||
                  c.status == PlaybackStatus.loading ||
                  c.status == PlaybackStatus.paused))
          .map((c) => c.releasePlayer()));

      if (_globalStopToken != requestedStopToken) return;

      if (_streamPlaybackToken != requestedPlaybackToken ||
          _globalStopToken != requestedStopToken) {
        return;
      }
    } else if (isBinaural) {
      requestedPlaybackToken = ++_binauralPlaybackToken;

      await Future.wait(_controllers.values
          .where((c) =>
              c.sound.isBinaural &&
              c.sound.path != path &&
              (c.isPlaying ||
                  c.status == PlaybackStatus.loading ||
                  c.status == PlaybackStatus.paused))
          .map((c) => c.releasePlayer()));

      if (_binauralPlaybackToken != requestedPlaybackToken ||
          _globalStopToken != requestedStopToken) {
        return;
      }
    } else if (isNoise) {
      requestedPlaybackToken = ++_noisePlaybackToken;

      await Future.wait(_controllers.values
          .where((c) =>
              c.sound.isNoise &&
              c.sound.path != path &&
              (c.isPlaying ||
                  c.status == PlaybackStatus.loading ||
                  c.status == PlaybackStatus.paused))
          .map((c) => c.releasePlayer()));

      if (_noisePlaybackToken != requestedPlaybackToken ||
          _globalStopToken != requestedStopToken) {
        return;
      }
    }

    if (controller.status == PlaybackStatus.notInitialized) {
      await controller.load();
    }

    if (_globalStopToken != requestedStopToken) return;

    if (isStream && _streamPlaybackToken != requestedPlaybackToken) return;
    if (isBinaural && _binauralPlaybackToken != requestedPlaybackToken) return;
    if (isNoise && _noisePlaybackToken != requestedPlaybackToken)
      return; // New: Final check for noise

    await controller.play();
    // No explicit notifyListeners() here — controller.play() already triggers
    // _onControllerStateChanged via the controller's own notification chain.
  }

  Future<void> pause(String path) async {
    final controller = _controllers[path];
    if (controller != null && controller.isPlaying) {
      await controller.pause();
      // No explicit notifyListeners() — propagates through _onControllerStateChanged.
    }
  }

  Future<void> stop(String path) async {
    _globalStopToken++; // mark all pending play as invalid
    final controller = _controllers[path];
    if (controller != null) {
      await controller.stop();
      // No explicit notifyListeners() — propagates through _onControllerStateChanged.
    }
  }

  void setVolume(String path, double volume) {
    final controller = _controllers[path];
    if (controller != null) {
      controller.setVolume(volume);
      // No explicit notifyListeners() — controller.setVolume() notifies, which
      // propagates through _onControllerStateChanged.
    }
  }

  Future<void> disposeAll() async {
    for (final controller in _controllers.values) {
      controller.removeListener(_onControllerStateChanged);
      controller.dispose();
    }
    _controllers.clear();
    _metadataNotifier.value = {};
    SoLoud.instance.deinit();
    // Dispose Web Audio API manager on web
    if (kIsWeb) {
      WebAudioSeamlessManager().disposeAll();
    }
    notifyListeners();
  }

  Future<void> unregister(String path) async {
    final controller = _controllers.remove(path);
    if (controller != null) {
      controller.removeListener(_onControllerStateChanged);
      // Release the player (stops + disposes audio) before calling dispose()
      // so the underlying stream has no chance to emit late events that would
      // call notifyListeners() on an already-disposed ChangeNotifier.
      await controller.releasePlayer();
      controller.dispose();
      final updatedMetadata = Map<String, String>.from(_metadataNotifier.value);
      updatedMetadata.remove(path);
      _metadataNotifier.value = updatedMetadata;
      notifyListeners();
    }
  }

  String getMetadata(NinjaSound sound) {
    return _metadataNotifier.value[sound.path] ?? '';
  }

  // --- Crucial Change Here ---
  void _onControllerStateChanged() {
    // Rebuild the _metadataNotifier's value based on all active stream controllers
    final updatedMetadata = <String, String>{};
    for (final controller in _controllers.values) {
      if (controller.sound.isStream) {
        // Only add metadata for streams that are playing or paused (i.e., known state)
        // and have actual metadata
        if (controller.currentMetadata.isNotEmpty) {
          updatedMetadata[controller.sound.path] = controller.currentMetadata;
        } else if (controller.isPlaying ||
            controller.status == PlaybackStatus.paused) {
          // Optionally, if you want to show the stream name if no metadata yet but playing
          updatedMetadata[controller.sound.path] = '';
        }
      }
    }
    _metadataNotifier.value = updatedMetadata;

    // This notifyListeners is for the JustAudioSoundManager itself,
    // which listeners (like WrapperAudioHandler) might be observing for overall state changes.
    super.notifyListeners();
  }
}
