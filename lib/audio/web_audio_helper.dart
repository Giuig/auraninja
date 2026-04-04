import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Helper for web audio loop management.
///
/// Uses multiple copies of audio source for seamless gapless looping
/// without the slow loading of 100 copies.
///
/// Also monitors playback position to detect and recover from
/// browser-induced audio suspension.
class WebAudioHelper {
  static const int loopCopies = 30; // ~5x track length, much faster loading

  /// Creates the list of audio sources for gapless looping on web.
  /// Uses 5 copies instead of 100 to avoid slow loading.
  static List<AudioSource> createLoopingSources(String assetPath) {
    return List.filled(loopCopies, AudioSource.asset(assetPath));
  }

  /// Set up a watchdog that detects when audio stops unexpectedly
  /// and attempts to restart it.
  ///
  /// Returns a subscription that should be cancelled when done.
  static StreamSubscription<Duration> createRecoveryWatchdog({
    required AudioPlayer player,
    required VoidCallback onStalled,
  }) {
    Duration lastPosition = Duration.zero;
    int stallCount = 0;

    return player.positionStream.listen((position) {
      if (player.playing) {
        // Check if position has advanced
        if (position <= lastPosition) {
          stallCount++;
          if (stallCount >= 2) {
            // Stalled for at least 2 check intervals (~20s)
            debugPrint('[WebAudio] Playback stalled, attempting recovery');
            onStalled();
            stallCount = 0;
          }
        } else {
          stallCount = 0;
        }
        lastPosition = position;
      }
    });
  }
}
