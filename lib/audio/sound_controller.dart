import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
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
        newStatus = PlaybackStatus.playing;

        if (sound.isStream) {
          // Use WebMetadataService on web, icyMetadataStream on native
          if (kIsWeb && _webMetadataService == null) {
            _startWebMetadataService();
          } else if (!kIsWeb && _icyMetadataSubscription == null) {
            _startIcyMetadataSubscription();
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
      _status = PlaybackStatus.error;
      notifyListeners();
      _stopIcyMetadataSubscription();
    });
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
        await _webSeamlessPlayer!.play();
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
    if (_status == PlaybackStatus.notInitialized ||
        _status == PlaybackStatus.error ||
        (sound.isStream && kIsWeb)) {
      await load();
      if (_status == PlaybackStatus.error) return;
    }

    try {
      await player.play();
      // Explicit update for immediate UI feedback if the stream event hasn't
      // fired yet by the time the Future resolves.
      // Guard: pause() may have set _userPaused=true while player.play() was
      // pending (the JS Promise resolves after our pause() call). Don't
      // override the paused state in that case.
      if (!_userPaused && _status != PlaybackStatus.playing) {
        _status = PlaybackStatus.playing;
        notifyListeners();
      }
    } catch (_) {
      _status = PlaybackStatus.error;
      notifyListeners();
      _stopIcyMetadataSubscription();
    }
  }

  Future<void> pause() async {
    debugPrint('[SC:${sound.name}] pause() status=$_status');
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

  void setVolume(double v) {
    if (_volume != v) {
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
      notifyListeners();
    }
  }

  /// Disposes the underlying audio resource and resets all state, but keeps
  /// this SoundController alive. Resources will be lazily recreated on next play().
  Future<void> releasePlayer() async {
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
