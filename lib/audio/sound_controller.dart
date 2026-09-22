import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:auraninja/audio/fade_curve.dart';
import 'package:auraninja/model/ninja_sound.dart';
import 'package:auraninja/audio/web_audio_seamless.dart';
import 'package:auraninja/services/web_metadata_service.dart';

enum PlaybackStatus {
  notInitialized,
  loading,
  paused,
  playing,
  error,
}

class SoundController with ChangeNotifier {
  final NinjaSound sound;

  // SoLoud path: used for local asset sounds on native platforms.
  AudioSource? _soloudSource;
  SoundHandle? _soloudHandle;

  // Web Audio API path: used for local assets on web (seamless looping).
  WebAudioSeamlessPlayer? _webSeamlessPlayer;

  // just_audio path: used for HTTP streams.
  just_audio.AudioPlayer? _player;
  double _volume = 0.5;
  PlaybackStatus _statusValue = PlaybackStatus.notInitialized;
  PlaybackStatus get _status => _statusValue;
  set _status(PlaybackStatus v) {
    if (v == PlaybackStatus.playing && _statusValue != PlaybackStatus.playing) {
      debugPrint(
          '[SC:${sound.name}] _status→playing (userPaused=$_userPaused)\n${StackTrace.current}');
    }
    _statusValue = v;
  }

  StreamSubscription<just_audio.PlayerState>? _playerStateSubscription;
  StreamSubscription<just_audio.IcyMetadata?>? _icyMetadataSubscription;
  StreamSubscription<Duration>? _recoveryWatchdog;
  WebMetadataService? _webMetadataService;

  // just_audio has no native volume-ramp API, unlike SoLoud/Web Audio, so
  // fadeTo() drives it with a plain Dart ticker. Tracked so a new fade (or
  // any stop/pause/dispose) can cancel a stale one before it fires again.
  Timer? _justAudioFadeTimer;

  // Bounded auto-reconnect for dropped streams. When a live stream dies
  // mid-playback (network loss), ExoPlayer resets to idle but leaves
  // playWhenReady true — so playerStateStream keeps reporting playing=true
  // with nothing actually coming out, and without this the UI, the mix list
  // and the media notification all keep claiming playback forever.
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;

  // A failed attempt makes the player emit the same "dropped" shape again
  // while _attemptReconnect is still awaiting, which would schedule a second
  // backoff chain on top of the first and leave an orphaned timer running.
  bool _reconnectInFlight = false;

  // True from the moment a drop is detected until playback is genuinely
  // re-established (or the backoff gives up). The OS media session issues its
  // own play() at a dropped stream — independently of this backoff — so every
  // route back into playback has to consult this rather than assume the
  // player still holds a usable source.
  bool _reconnecting = false;

  /// Backoff schedule for a dropped stream. Exhausting it is what turns the
  /// sound red (PlaybackStatus.error) rather than retrying indefinitely —
  /// ~90s total. No jitter: jitter exists to spread load across many clients
  /// hitting one server, which does not apply to a single device.
  static const List<Duration> _reconnectDelays = [
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 16),
    Duration(seconds: 30),
    Duration(seconds: 30),
  ];

  String _currentMetadata = '';
  Duration? _singleTrackDuration;
  bool _userPaused = false;

  SoundController(this.sound);

  /// True when this controller should use the SoLoud engine.
  /// Local asset sounds on native platforms only — not web, not HTTP streams.
  bool get _useSoloud => !sound.isStream && !kIsWeb;

  /// True when this controller should use Web Audio API for seamless looping.
  /// All local asset sounds on web use this for gapless looping.
  /// Streams use just_audio (HTTP streams can't be pre-loaded into AudioBuffer).
  bool get _useWebSeamless => !sound.isStream && kIsWeb;

  /// Lazy getter — creates the just_audio.AudioPlayer on first access only.
  /// Only used for streams and web.
  just_audio.AudioPlayer get player {
    if (_player == null) {
      _player = just_audio.AudioPlayer();
      _listenToPlayerState();
    }
    return _player!;
  }

  /// True if an just_audio.AudioPlayer has been created for this controller.
  bool get hasPlayer => _player != null;

  /// True for categories where only one instance plays at a time
  /// (stream, binaural, noise). Nature sounds return false.
  bool get isExclusiveCategory =>
      sound.isStream || sound.isBinaural || sound.isNoise;

  PlaybackStatus get status => _status;
  double get volume => _volume;
  bool get isPlaying => _status == PlaybackStatus.playing;
  String get currentMetadata => _currentMetadata;

  void _listenToPlayerState() {
    _playerStateSubscription = _player!.playerStateStream.listen((playerState) {
      final processingState = playerState.processingState;
      final playing = playerState.playing;
      if (_userPaused) {
        debugPrint(
            '[SC:${sound.name}] event BLOCKED(_userPaused): playing=$playing proc=$processingState');
        return;
      }
      debugPrint(
          '[SC:${sound.name}] event: playing=$playing proc=$processingState myStatus=$_status');

      PlaybackStatus newStatus;

      if (playing) {
        // playing=true cannot be trusted on its own: after a load error the
        // ExoPlayer resets to idle while playWhenReady stays true, so it
        // reports "playing" for a stream that has actually stopped. Only
        // treat it as a drop once real playback had been reached, so a first
        // connect that never worked still fails fast via load()'s catch
        // rather than retrying a bad URL for a minute and a half.
        if (sound.isStream &&
            processingState == just_audio.ProcessingState.idle &&
            (_status == PlaybackStatus.playing ||
                _status == PlaybackStatus.loading)) {
          _handleStreamDropped();
          return;
        }

        // playWhenReady stays true through a mid-stream rebuffer and through
        // every reconnect attempt, so `playing` on its own is not evidence
        // that audio is flowing: it reported "playing" across 14s of silence
        // during a stall, and turned the card fully green on each retry.
        // Audio only actually comes out at `ready`.
        if (processingState == just_audio.ProcessingState.loading ||
            processingState == just_audio.ProcessingState.buffering) {
          newStatus = PlaybackStatus.loading;
        } else {
          newStatus = PlaybackStatus.playing;
          // Only real playback clears the backoff. A retry reports
          // playing=true with proc=loading moments before it fails again, and
          // treating that as success reset the counter every cycle — the
          // backoff never escalated past its first delay and the give-up path
          // was unreachable.
          if (processingState == just_audio.ProcessingState.ready) {
            _cancelReconnect();
          }

          if (sound.isStream) {
            // Use WebMetadataService on web, icyMetadataStream on native
            if (kIsWeb && _webMetadataService == null) {
              _startWebMetadataService();
            } else if (!kIsWeb && _icyMetadataSubscription == null) {
              _startIcyMetadataSubscription();
            }
          }
        }
      } else {
        if (processingState == just_audio.ProcessingState.loading ||
            processingState == just_audio.ProcessingState.buffering) {
          newStatus = PlaybackStatus.loading;
        } else if (processingState == just_audio.ProcessingState.ready) {
          newStatus = PlaybackStatus.paused;
          _stopIcyMetadataSubscription();
        } else if (processingState == just_audio.ProcessingState.idle) {
          newStatus = PlaybackStatus.notInitialized;
          _stopIcyMetadataSubscription();
        } else {
          newStatus = PlaybackStatus.error;
          _stopIcyMetadataSubscription();
        }
      }

      if (_status != newStatus) {
        debugPrint('[SC:${sound.name}] status: $_status → $newStatus');
        _status = newStatus;
        notifyListeners();
      }
    }, onError: (_) {
      if (sound.isStream &&
          !_userPaused &&
          (_status == PlaybackStatus.playing ||
              _status == PlaybackStatus.loading)) {
        _handleStreamDropped();
        return;
      }
      _status = PlaybackStatus.error;
      notifyListeners();
      _stopIcyMetadataSubscription();
    });
  }

  /// A stream that was playing has stopped without the user asking. Starts the
  /// backoff if one isn't already running; [_scheduleReconnect] is what
  /// eventually gives up and reports the error.
  void _handleStreamDropped() {
    if (_userPaused || _reconnectTimer != null || _reconnectInFlight) return;
    _reconnecting = true;
    _scheduleReconnect();
  }

  /// Cancels a pending attempt without forgetting how many have been made —
  /// used where playback is re-attempted through another route (a media
  /// session play(), a load()), which must not silently restart the backoff
  /// from zero and make it retry forever.
  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _cancelReconnect() {
    _cancelReconnectTimer();
    _reconnectAttempt = 0;
    _reconnecting = false;
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    if (_reconnectAttempt >= _reconnectDelays.length) {
      _cancelReconnect();
      _stopIcyMetadataSubscription();
      if (_status != PlaybackStatus.error) {
        _status = PlaybackStatus.error;
        notifyListeners();
      }
      return;
    }

    final delay = _reconnectDelays[_reconnectAttempt];
    _reconnectAttempt++;
    debugPrint(
        '[SC:${sound.name}] reconnect attempt $_reconnectAttempt in ${delay.inSeconds}s');

    // Reuse `loading` rather than adding a status: it already means
    // "connecting" everywhere in the UI (spinner on the card, 'Loading…' in
    // the player bar) and already counts as an active sound, so the whole
    // retry window renders correctly without touching any widget.
    _stopIcyMetadataSubscription();
    if (_status != PlaybackStatus.loading) {
      _status = PlaybackStatus.loading;
      notifyListeners();
    }

    _reconnectTimer = Timer(delay, _attemptReconnect);
  }

  Future<void> _attemptReconnect() async {
    _reconnectTimer = null;
    if (_userPaused || !sound.isStream) {
      _cancelReconnect();
      return;
    }

    _reconnectInFlight = true;
    // Deliberately not load(): its catch reports error immediately, which is
    // the very thing the backoff exists to defer until the retries run out.
    try {
      await player
          .setAudioSource(just_audio.AudioSource.uri(Uri.parse(sound.path)));
      await player.setLoopMode(just_audio.LoopMode.one);
      await player.setVolume(_volume);
      await player.play();
      // Success is confirmed by playerStateStream reporting a real playing
      // state, which resets _reconnectAttempt — not by this call returning.
      _reconnectInFlight = false;
    } catch (_) {
      _reconnectInFlight = false;
      if (!_userPaused) _scheduleReconnect();
    }
  }

  void _startIcyMetadataSubscription() {
    _icyMetadataSubscription = player.icyMetadataStream.listen((icyMetadata) {
      final newMetadata = icyMetadata?.info?.title ?? '';
      if (_currentMetadata != newMetadata) {
        _currentMetadata = newMetadata;
        notifyListeners();
      }
    }, onError: (_) {
      _stopIcyMetadataSubscription();
    }, onDone: () {
      _stopIcyMetadataSubscription();
    });
  }

  void _stopIcyMetadataSubscription() {
    _icyMetadataSubscription?.cancel();
    _icyMetadataSubscription = null;
    // Also stop web metadata service if running
    _webMetadataService?.stop();
    _webMetadataService = null;
    if (_currentMetadata.isNotEmpty) {
      _currentMetadata = '';
      notifyListeners();
    }
  }

  /// Start web metadata service for streams on web.
  void _startWebMetadataService() {
    _webMetadataService?.stop();
    _webMetadataService = WebMetadataService(
      streamUrl: sound.path,
      onUpdate: (title) {
        if (_currentMetadata != title) {
          _currentMetadata = title;
          notifyListeners();
        }
      },
    );
    _webMetadataService?.start();
  }

  Future<void> load() async {
    _cancelReconnectTimer();
    _status = PlaybackStatus.loading;
    notifyListeners();

    // Clean up any existing recovery watchdog
    _recoveryWatchdog?.cancel();
    _recoveryWatchdog = null;

    if (_useSoloud) {
      try {
        // Reuse the source if already loaded; otherwise load from asset.
        _soloudSource ??= await SoLoud.instance.loadAsset(sound.path);
        _status = PlaybackStatus.paused;
        notifyListeners();
      } catch (_) {
        _status = PlaybackStatus.error;
        notifyListeners();
      }
      return;
    }

    // Web Audio API seamless looping for local assets on web
    if (_useWebSeamless) {
      try {
        _webSeamlessPlayer ??=
            WebAudioSeamlessManager().getOrCreate(sound.path);
        await _webSeamlessPlayer!.loadAsset(sound.path, isNoise: sound.isNoise);
        // Re-establish volume from the controller — parity with the
        // just_audio branch (line 234: player.setVolume(_volume)) and the
        // SoLoud branch (line 259: play(..., volume: _volume)). Without
        // this, a setVolume() that arrived while _webSeamlessPlayer was
        // still null (e.g. the unawaited prefs restore in registerSounds)
        // is silently dropped by `?.`, and nothing re-establishes it.
        // Calling setVolume() here while stopped only updates the player's
        // cached field — _mainGainNode is null, so the setTargetAtTime
        // calls are no-ops — which is exactly the intent.
        _webSeamlessPlayer!.setVolume(_volume);
        _status = PlaybackStatus.paused;
        notifyListeners();
      } catch (_) {
        _status = PlaybackStatus.error;
        notifyListeners();
      }
      return;
    }

    try {
      just_audio.AudioSource source;

      if (sound.isStream) {
        // Streams don't loop - just play
        source = just_audio.AudioSource.uri(Uri.parse(sound.path));
        _singleTrackDuration = await player.setAudioSource(source);
        await player.setLoopMode(just_audio.LoopMode.one);
      } else {
        // Native platforms: use LoopMode.one for seamless looping
        source = just_audio.AudioSource.asset(sound.path);
        _singleTrackDuration = await player.setAudioSource(source);
        await player.setLoopMode(just_audio.LoopMode.one);
      }

      await player.setVolume(_volume);
    } catch (_) {
      // Mid-reconnect this is just another failed attempt, not a verdict:
      // going straight to error here would paint the sound red on the first
      // retry instead of after the backoff is exhausted.
      if (_reconnecting && sound.isStream && !_userPaused) {
        _scheduleReconnect();
        return;
      }
      _status = PlaybackStatus.error;
      notifyListeners();
      _stopIcyMetadataSubscription();
    }
  }

  Future<void> play() async {
    debugPrint('[SC:${sound.name}] play() status=$_status');
    if (_useSoloud) {
      if (_status == PlaybackStatus.notInitialized ||
          _status == PlaybackStatus.error) {
        await load();
        if (_status == PlaybackStatus.error) return;
      }
      try {
        // Stop any existing handle before creating a new one.
        if (_soloudHandle != null) {
          await SoLoud.instance.stop(_soloudHandle!);
          _soloudHandle = null;
        }
        _soloudHandle = await SoLoud.instance.play(
          _soloudSource!,
          looping: true,
          volume: _volume,
        );
        _status = PlaybackStatus.playing;
        notifyListeners();
      } catch (_) {
        _status = PlaybackStatus.error;
        notifyListeners();
      }
      return;
    }

    if (_useWebSeamless) {
      if (_status == PlaybackStatus.notInitialized ||
          _status == PlaybackStatus.error) {
        await load();
        if (_status == PlaybackStatus.error) return;
      }
      try {
        // Web analogue of the SoLoud branch's play(..., volume: _volume)
        // above — the volume is passed explicitly rather than read from a
        // private default that can diverge from the controller.
        await _webSeamlessPlayer!.play(volume: _volume);
        _status = PlaybackStatus.playing;
        notifyListeners();
      } catch (_) {
        _status = PlaybackStatus.error;
        notifyListeners();
      }
      return;
    }

    _userPaused = false;

    // For stream on web: player was stopped during pause (streams can't be
    // paused on web). Must reload before playing. For other sounds: reload
    // only if not initialized or in error.
    // _reconnecting is in that list because a dropped stream leaves the
    // player idle with a dead source while status is still `loading` — the
    // media session issues its own play() at exactly that moment, and
    // without a reload this plays a source that can only fail again.
    if (_status == PlaybackStatus.notInitialized ||
        _status == PlaybackStatus.error ||
        _reconnecting ||
        (sound.isStream && kIsWeb)) {
      await load();
      // load() handed this back to the backoff — let that timer own the
      // retry instead of racing it with another play() on a dead source.
      if (_reconnectTimer != null) return;
      if (_status == PlaybackStatus.error) return;
    }

    try {
      await player.play();
      // Explicit update for immediate UI feedback if the stream event hasn't
      // fired yet by the time the Future resolves.
      // Guard: pause() may have set _userPaused=true while player.play() was
      // pending (the JS Promise resolves after our pause() call). Don't
      // override the paused state in that case.
      // Gated on the player actually being ready: claiming `playing` the
      // moment play() returns paints the card green before a single byte has
      // arrived, which on a slow or dead connection is simply untrue. When
      // it is not ready the status stays `loading` and the state stream
      // promotes it once audio really starts.
      if (!_userPaused &&
          _status != PlaybackStatus.playing &&
          player.processingState == just_audio.ProcessingState.ready) {
        _status = PlaybackStatus.playing;
        notifyListeners();
      }
    } catch (_) {
      if (_reconnecting && sound.isStream && !_userPaused) {
        _scheduleReconnect();
        return;
      }
      _status = PlaybackStatus.error;
      notifyListeners();
      _stopIcyMetadataSubscription();
    }
  }

  Future<void> pause() async {
    debugPrint('[SC:${sound.name}] pause() status=$_status');
    _cancelReconnect();
    _justAudioFadeTimer?.cancel();
    _justAudioFadeTimer = null;
    if (_useSoloud) {
      if (_soloudHandle != null) {
        await SoLoud.instance.stop(_soloudHandle!);
        _soloudHandle = null;
      }
      if (_status != PlaybackStatus.paused) {
        _status = PlaybackStatus.paused;
        notifyListeners();
      }
      return;
    }

    if (_useWebSeamless) {
      await _webSeamlessPlayer?.stop();
      if (_status != PlaybackStatus.paused) {
        _status = PlaybackStatus.paused;
        notifyListeners();
      }
      return;
    }

    // Block all player events and immediately show paused state in the UI.
    // This prevents spurious playing=true events (LoopMode.one on web) and
    // the idle event from stream stop from overriding the intended pause.
    _userPaused = true;
    if (_status != PlaybackStatus.paused) {
      _status = PlaybackStatus.paused;
      notifyListeners();
    }

    // On web, live HTTP streams can't be paused by the browser's audio element —
    // pause() is silently ignored and audio keeps playing. stop() is the only
    // reliable way to silence a stream on web. WrapperAudioHandler._pausedPaths
    // remembers the path so playAllPaused() can reconnect and restart it.
    if (sound.isStream && kIsWeb) {
      await player.stop(); // idle event is blocked by _userPaused=true
      return;
    }

    await player.pause();
  }

  Future<void> stop() async {
    _cancelReconnect();
    _justAudioFadeTimer?.cancel();
    _justAudioFadeTimer = null;
    if (_useSoloud) {
      if (_soloudHandle != null) {
        await SoLoud.instance.stop(_soloudHandle!);
        _soloudHandle = null;
      }
      if (_status != PlaybackStatus.notInitialized) {
        _status = PlaybackStatus.notInitialized;
        notifyListeners();
      }
      return;
    }

    if (_useWebSeamless) {
      await _webSeamlessPlayer?.stop();
      if (_status != PlaybackStatus.notInitialized) {
        _status = PlaybackStatus.notInitialized;
        notifyListeners();
      }
      return;
    }

    await player.stop();
    // Guard: same as pause() — avoid double-notification if stream fired first.
    if (_status != PlaybackStatus.notInitialized) {
      _status = PlaybackStatus.notInitialized;
      notifyListeners();
    }
  }

  // setVolume() always forwards the write to whichever backend is active,
  // even when [v] equals the cached [_volume] already — only
  // notifyListeners() stays gated on an actual change:
  //   - Keeping notifyListeners() change-gated is the point. The manager ->
  //     handler chain (j_a_sound_manager.dart:154-160 ->
  //     _onControllerStateChanged -> wrapper_audio_handler.dart:99-110) runs
  //     an async notification-metadata update on every notification, and
  //     wrapper_audio_handler's listener relies on exactly this chain.
  //     Notifying on no-op writes would add rebuilds and metadata work for
  //     nothing; gating it keeps listener behaviour byte-for-byte identical
  //     to today.
  //   - Redundant engine calls are accepted and bounded: setVolume() is
  //     driven by slider onChanged (which only fires on an actual value
  //     change), by the mix apply loop (once per sound per mix start), and
  //     by the prefs restore (once per sound). SoLoud's setVolume and the
  //     web player's setTargetAtTime are cheap; just_audio's is a
  //     platform-channel hop but at that call rate it is immaterial.
  //   - One accepted behaviour delta, worth stating out loud:
  //     sound_card.dart:176's reset-to-0.5 tap target stays hit-testable
  //     while invisible (Opacity(0) + HitTestBehavior.opaque). Tapping it
  //     while the volume is already exactly 0.5 used to be swallowed; it now
  //     reaches the engine, which during a sleep-timer fade would snap that
  //     sound back to 0.5. Marginal and already true for any other value
  //     pre-fix (the guard never protected the fade), so it is accepted
  //     rather than worked around.
  void setVolume(double v) {
    final changed = _volume != v;
    _volume = v;
    if (_useSoloud) {
      if (_soloudHandle != null) {
        SoLoud.instance.setVolume(_soloudHandle!, v);
      }
    } else if (_useWebSeamless) {
      _webSeamlessPlayer?.setVolume(v);
    } else if (hasPlayer) {
      _player!.setVolume(v);
    }
    if (changed) {
      notifyListeners();
    }
  }

  /// Ramps this sound's volume down to [target] over [duration], then
  /// leaves it stopped/paused as-is — callers decide when to actually stop
  /// playback (e.g. once every active sound has finished fading).
  ///
  /// Deliberately does NOT touch [_volume] or call [setVolume]/persist
  /// anything: every backend re-establishes its live volume from [_volume]
  /// on its next real play() — SoLoud passes [_volume] into play() directly,
  /// the web-seamless player now receives it explicitly via
  /// play(volume: _volume) and is re-synced from [_volume] again in load(),
  /// and just_audio re-applies [_volume] via load() after a stop() — so
  /// leaving [_volume] untouched here means the next play() is back at full
  /// volume with no separate restore step.
  void fadeTo(double target, Duration duration) {
    _justAudioFadeTimer?.cancel();
    _justAudioFadeTimer = null;

    if (_useSoloud) {
      if (_soloudHandle != null) {
        SoLoud.instance.fadeVolume(_soloudHandle!, target, duration);
      }
      return;
    }

    if (_useWebSeamless) {
      // Native, AudioContext-clock-driven ramp — keeps going smoothly even
      // if the tab is backgrounded/throttled, unlike a Dart Timer would.
      _webSeamlessPlayer?.fadeTo(target, duration);
      return;
    }

    // just_audio has no native ramp primitive, so drive it with a ticker.
    if (!hasPlayer) return;
    final start = _player!.volume;
    final startTime = DateTime.now();
    const tickInterval = Duration(milliseconds: 50);
    _justAudioFadeTimer = Timer.periodic(tickInterval, (timer) {
      final elapsedMs = DateTime.now().difference(startTime).inMilliseconds;
      final t = duration.inMilliseconds == 0
          ? 1.0
          : elapsedMs / duration.inMilliseconds;
      final eased = fadeOutEase(t);
      final v = start + (target - start) * eased;
      _player?.setVolume(v.clamp(0.0, 1.0));
      if (t >= 1.0) {
        timer.cancel();
        _justAudioFadeTimer = null;
      }
    });
  }

  /// Disposes the underlying audio resource and resets all state, but keeps
  /// this SoundController alive. Resources will be lazily recreated on next play().
  Future<void> releasePlayer() async {
    _justAudioFadeTimer?.cancel();
    _justAudioFadeTimer = null;
    if (_useSoloud) {
      if (_soloudHandle != null) {
        await SoLoud.instance.stop(_soloudHandle!);
        _soloudHandle = null;
      }
      if (_soloudSource != null) {
        await SoLoud.instance.disposeSource(_soloudSource!);
        _soloudSource = null;
      }
      _status = PlaybackStatus.notInitialized;
      _currentMetadata = '';
      notifyListeners();
      return;
    }

    if (_useWebSeamless) {
      await _webSeamlessPlayer?.stop();
      _webSeamlessPlayer = null;
      _status = PlaybackStatus.notInitialized;
      _currentMetadata = '';
      notifyListeners();
      return;
    }

    _cancelReconnect();
    _playerStateSubscription?.cancel();
    _playerStateSubscription = null;
    _icyMetadataSubscription?.cancel();
    _icyMetadataSubscription = null;
    _recoveryWatchdog?.cancel();
    _recoveryWatchdog = null;
    _webMetadataService?.dispose();
    _webMetadataService = null;
    await _player?.dispose();
    _player = null;
    _status = PlaybackStatus.notInitialized;
    _currentMetadata = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _cancelReconnect();
    _justAudioFadeTimer?.cancel();
    _justAudioFadeTimer = null;
    if (_useSoloud) {
      if (_soloudHandle != null) {
        SoLoud.instance.stop(_soloudHandle!);
      }
      if (_soloudSource != null) {
        SoLoud.instance.disposeSource(_soloudSource!);
      }
    }
    if (_useWebSeamless) {
      _webSeamlessPlayer?.dispose();
    }
    _playerStateSubscription?.cancel();
    _icyMetadataSubscription?.cancel();
    _recoveryWatchdog?.cancel();
    _webMetadataService?.dispose();
    _player?.dispose();
    super.dispose();
  }
}
