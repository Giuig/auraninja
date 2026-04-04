/// Stub implementation of WebAudioSeamlessPlayer for non-web platforms.
///
/// This file is used when building for Android/iOS/etc. The real
/// implementation is in web_audio_seamless_impl.dart (loaded on web).
library;

import 'package:flutter/foundation.dart';

/// Stub player - does nothing on non-web platforms.
class WebAudioSeamlessPlayer {
  bool get isPlaying => false;
  double get volume => 0.5;

  Future<void> loadAsset(String assetPath, {bool isNoise = false}) async {
    debugPrint('[WebAudioSeamless] Stub: loadAsset called on non-web platform');
  }

  Future<void> play() async {}

  Future<void> stop() async {}

  void setVolume(double volume) {}

  Future<void> dispose() async {}
}

/// Stub manager - does nothing on non-web platforms.
class WebAudioSeamlessManager {
  static final WebAudioSeamlessManager _instance =
      WebAudioSeamlessManager._internal();
  factory WebAudioSeamlessManager() => _instance;
  WebAudioSeamlessManager._internal();

  WebAudioSeamlessPlayer? get(String path) => null;

  WebAudioSeamlessPlayer getOrCreate(String path) {
    return WebAudioSeamlessPlayer();
  }

  Future<void> stopAll() async {}

  Future<void> disposeAll() async {}

  void remove(String path) {}
}
