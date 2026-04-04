import 'dart:convert';

import 'package:auraninja/audio/sound_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import 'package:auraninja/audio/j_a_sound_manager.dart';
import 'package:auraninja/model/ninja_sound.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class WrapperAudioHandler extends BaseAudioHandler
    with ChangeNotifier, WidgetsBindingObserver {
  final JustAudioSoundManager _manager = JustAudioSoundManager();

  // Expose all SoundControllers
  List<SoundController> get allControllers => _manager.allControllers;

  // Expose only active (playing/paused) SoundControllers
  List<SoundController> get activeControllers => _manager.activeControllers;

  // Expose playback status map: path -> PlaybackStatus
  Map<String, PlaybackStatus> get allStatuses => _manager.allStatuses;

  // Expose metadata notifier for reactive UI updates
  ValueNotifier<Map<String, String>> get metadataNotifier =>
      _manager.metadataNotifier;

  final Map<String, String?> _stationLogoCache = {};
  final Map<String, Future<Map<String, dynamic>?>> _stationInfoFetches = {};
  bool _logoCacheLoaded = false;

  // Paths that were explicitly paused by the user. Used by playAllPaused() so
  // that sounds whose just_audio player went to idle instead of ready on web
  // (a known just_audio quirk) are still reliably restarted.
  final Set<String> _pausedPaths = {};

  // True while pauseAll() is running. Guards play() override against spurious
  // MediaSession "play" actions that the browser fires mid-pause (e.g. when the
  // stream audio element is stopped), which would undo the pause immediately.
  bool _isPausing = false;

  // Convenience method to get metadata text for a NinjaSound
  String getMetadata(NinjaSound sound) => _manager.getMetadata(sound);

  /// Loads persisted station logo URLs from SharedPreferences.
  /// Called once on first access.
  Future<void> _loadPersistedLogos() async {
    if (_logoCacheLoaded) return;
    _logoCacheLoaded = true;
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('logo_'));
    for (final key in keys) {
      final url = prefs.getString(key);
      if (url != null) {
        final stationName = key.substring(5); // Remove 'logo_' prefix
        _stationLogoCache[stationName] = url;
      }
    }
  }

  /// Returns the cached favicon URL for [stationName] without triggering a fetch.
  /// Returns null if the logo has not been fetched yet.
  String? peekCachedLogoUrl(String stationName) =>
      _stationLogoCache[stationName];

  /// Returns the cached favicon URL for [stationName], or null if not yet fetched.
  /// Also kicks off a background fetch the first time it's called for a name.
  String? getCachedLogoUrl(String stationName) {
    if (!_stationLogoCache.containsKey(stationName)) {
      // Mark as in-progress so we don't dispatch duplicate fetches
      _stationLogoCache[stationName] = null;
      fetchStationInfo(stationName).then((info) async {
        final url = info?['favicon'] as String?;
        _stationLogoCache[stationName] = url;
        if (url != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('logo_$stationName', url);
          notifyListeners();
        }
      });
    }
    return _stationLogoCache[stationName];
  }

  NinjaSound? getActiveNetworkSound() {
    for (final controller in activeControllers) {
      if (controller.status == PlaybackStatus.playing &&
          controller.sound.isStream) {
        return controller.sound;
      }
    }
    return null;
  }

  WrapperAudioHandler() {
    WidgetsBinding.instance.addObserver(this);
    _loadPersistedLogos(); // Load cached logos from disk
    _manager.addListener(() async {
      _updatePlaybackState();
      notifyListeners();

      final activeStream = getActiveNetworkSound();
      final metadataText =
          activeStream != null ? _manager.getMetadata(activeStream) : '';

      await updateNotificationMetadata(metadataText, activeStream);

      // New: check if all controllers errored to stop notification
      await _onControllerStatusChanged();
    });

    _updatePlaybackState();
  }

  void _updatePlaybackState() {
    final playing = _manager.isAnyPlaying;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.play,
        MediaControl.pause,
        MediaControl.stop,
      ],
      playing: playing,
      processingState: AudioProcessingState.ready,
    ));
  }

  void registerSounds(List<NinjaSound> sounds) {
    final newSounds = sounds
        .where((sound) =>
            !_manager.allControllers.any((c) => c.sound.path == sound.path))
        .toList();

    if (newSounds.isEmpty) {
      return;
    }

    _manager.registerSounds(newSounds);
    // Restore persisted volumes for the newly registered sounds.
    SharedPreferences.getInstance().then((prefs) {
      for (final s in newSounds) {
        final saved = prefs.getDouble('vol_${s.path}');
        if (saved != null) _manager.setVolume(s.path, saved);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  Future<void> _onControllerStatusChanged() async {
    final allInErrorOrNotInitialized = _manager.allControllers.every(
      (controller) =>
          controller.status == PlaybackStatus.error ||
          controller.status == PlaybackStatus.notInitialized,
    );

    final statuses = _manager.allControllers
        .map((c) => '${c.sound.name}:${c.status.name}')
        .join(', ');
    debugPrint(
        '[WH] _onCtrlChanged: [$statuses] allStopped=$allInErrorOrNotInitialized');

    if (allInErrorOrNotInitialized) {
      debugPrint('[WH] → calling super.stop()');
      await super.stop();
    }
  }

  Future<void> unregisterSound(String path) async {
    await _manager.unregister(path);
    notifyListeners();
  }

  Future<void> ninjaPlay(String path) async {
    debugPrint('[WH] ninjaPlay: $path');
    await _manager.play(path);
  }

  Future<void> ninjaStop(String path) async {
    debugPrint('[WH] ninjaStop: $path');
    await _manager.stop(path);
  }

  Future<void> ninjaPause(String path) async {
    debugPrint('[WH] ninjaPause: $path');
    await _manager.pause(path);
  }

  Future<void> pauseAll() async {
    _isPausing = true;
    final playing = allControllers
        .where((c) => c.status == PlaybackStatus.playing)
        .map((c) => c.sound.name)
        .toList();
    debugPrint('[WH] pauseAll() — playing=$playing pausedPaths=$_pausedPaths');
    final futures = <Future<void>>[];

    for (final controller in allControllers) {
      if (controller.status == PlaybackStatus.playing) {
        _pausedPaths.add(controller.sound.path);
        futures.add(ninjaPause(controller.sound.path));
      }
    }

    await Future.wait(futures);
    _isPausing = false;
    debugPrint('[WH] pauseAll() done — pausedPaths=$_pausedPaths');
    // No explicit notifyListeners() — each ninjaPause propagates through the
    // controller → manager → handler listener chain already.
  }

  Future<void> playAllPaused() async {
    debugPrint('[WH] playAllPaused() — pausedPaths=$_pausedPaths');
    // Use _pausedPaths instead of controller status: on web, just_audio can
    // send the player to idle (→ notInitialized) instead of ready (→ paused)
    // after pause(), so status-based filtering silently skips those sounds.
    final paths = Set.of(_pausedPaths);
    _pausedPaths.clear();
    final futures = <Future<void>>[];
    for (final path in paths) {
      futures.add(ninjaPlay(path));
    }
    await Future.wait(futures);
    debugPrint('[WH] playAllPaused() done');
  }

  Future<void> stopAll() async {
    debugPrint('[WH] stopAll() called');
    _pausedPaths.clear();
    final futures = <Future<void>>[];

    for (final controller in allControllers) {
      if (controller.status != PlaybackStatus.notInitialized) {
        futures.add(ninjaStop(controller.sound.path));
      }
    }
    await Future.wait(futures);
    await super.stop();
    notifyListeners();
  }

  void setVolume(String path, double volume) {
    _manager.setVolume(path, volume);
    // Persist so the volume survives app restarts.
    SharedPreferences.getInstance()
        .then((p) => p.setDouble('vol_$path', volume));
    // No explicit notifyListeners() — manager.setVolume → controller.setVolume
    // → _onControllerStateChanged → manager.notifyListeners → handler listener.
  }

  /// Called by Flutter when the app comes back to the foreground.
  /// On web, the browser may have suspended the AudioContext while the tab
  /// was backgrounded — audio silently stops without any state change events
  /// reaching just_audio, so the UI stays "lit up" while nothing plays.
  /// Re-calling play() on affected controllers resumes the suspended context.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!kIsWeb) return;
    if (state == AppLifecycleState.resumed) {
      for (final controller in allControllers) {
        if (controller.status == PlaybackStatus.playing) {
          controller.player.play();
        }
      }
    }
  }

  @override
  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    await _manager.disposeAll();
    super.dispose();
  }

  @override
  Future<void> play() async {
    // Guard: the browser's MediaSession can fire a "play" action mid-pause
    // (e.g. when the stream audio element is stopped). Ignore it.
    if (_isPausing) {
      debugPrint('[WH] play() OVERRIDE ignored — _isPausing=true');
      return;
    }
    await playAllPaused();
    // No explicit notifyListeners() — playAllPaused() propagates through chain.
  }

  @override
  Future<void> pause() async {
    await pauseAll();
    // No explicit notifyListeners() — pauseAll() propagates through chain.
  }

  @override
  Future<void> stop() async {
    debugPrint('[WH] stop() OVERRIDE called\n${StackTrace.current}');
    await stopAll();
    await super.stop();
    notifyListeners();
  }

  Future<void> updateNotificationMetadata(
      String metadataText, NinjaSound? activeStream) async {
    final playingSounds = allControllers
        .where((c) => c.status == PlaybackStatus.playing)
        .map((c) => c.sound)
        .toList();

    if (playingSounds.isEmpty) {
      mediaItem.add(const MediaItem(
        id: 'auraninja',
        album: 'Auraninja',
        title: 'Auraninja',
      ));
      return;
    }

    if (activeStream != null) {
      // Stream is playing — use ICY metadata for title/artist.
      final parts = metadataText.split(' - ');
      final artist = parts.isNotEmpty ? parts[0] : '';
      final title = parts.length > 1
          ? parts[1]
          : metadataText.isNotEmpty
              ? metadataText
              : activeStream.name;

      String? logoUrl = _stationLogoCache[activeStream.name];
      if (logoUrl == null &&
          !_stationLogoCache.containsKey(activeStream.name)) {
        final info = await fetchStationInfo(activeStream.name);
        logoUrl = info?['favicon'] as String?;
        _stationLogoCache[activeStream.name] = logoUrl;
      }

      mediaItem.add(MediaItem(
        id: 'auraninja-stream',
        album: 'Auraninja',
        title: title,
        artist: artist,
        artUri: logoUrl != null ? Uri.parse(logoUrl) : null,
        duration: Duration.zero,
      ));
    } else {
      // Local sounds (binaural, noise, nature) — build a real media item so
      // the browser MediaSession treats this as active playback and does not
      // suspend the AudioContext in background / PWA mode.
      final title = playingSounds.map((s) => s.name).join(' · ');
      mediaItem.add(MediaItem(
        id: 'auraninja-local',
        album: 'Auraninja',
        title: title,
        artist: 'Auraninja',
        // Non-zero duration is the key signal: it tells the MediaSession this
        // is intentional long-form audio, not a transient sound effect.
        duration: const Duration(hours: 1),
      ));
    }
  }

  Future<Map<String, dynamic>?> fetchStationInfo(String stationName) {
    if (_stationInfoFetches.containsKey(stationName)) {
      return _stationInfoFetches[stationName]!;
    }

    final fetch = _fetchStationInfoInternal(stationName);
    _stationInfoFetches[stationName] = fetch;

    return fetch;
  }

  Future<Map<String, dynamic>?> _fetchStationInfoInternal(
      String stationName) async {
    final query = {
      'name': stationName,
      'limit': '1',
    };

    final uri =
        Uri.https('de1.api.radio-browser.info', '/json/stations/search', query);

    try {
      final resp = await http.get(uri, headers: {
        'User-Agent': 'Auraninja/1.0',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final List stations = jsonDecode(resp.body);
        final data =
            stations.isNotEmpty ? stations.first as Map<String, dynamic> : null;
        return data;
      }
    } catch (_) {
    } finally {
      _stationInfoFetches.remove(stationName);
    }

    return null;
  }
}
