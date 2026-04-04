import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:marquee/marquee.dart';

import 'package:auraninja/audio/wrapper_audio_handler.dart';
import 'package:auraninja/audio/sound_controller.dart';
import 'package:auraninja/l10n/app_localizations.dart';
import 'package:auraninja/model/ninja_sound.dart';

class BottomPlayerBar extends StatefulWidget {
  const BottomPlayerBar({super.key});

  @override
  State<BottomPlayerBar> createState() => _BottomPlayerBarState();
}

class _BottomPlayerBarState extends State<BottomPlayerBar> {
  late final WrapperAudioHandler _audioHandler;

  /// Non-null while a sleep timer is active. Used to show/hide [_SleepCountdown].
  DateTime? _timerEnd;

  bool _showMarquee = false;
  Timer? _marqueeInitialDelayTimer;
  bool _isAllPaused = true;
  bool _isLoading = false;
  bool _hadActiveSounds = false;

  String? _currentActiveNetworkSoundId;

  // TextPainter overflow cache — avoids re-measuring on every metadata tick.
  String? _tpCachedMetadata;
  double? _tpCachedWidth;
  bool _tpCachedOverflows = false;

  @override
  void initState() {
    super.initState();
    _audioHandler = Provider.of<WrapperAudioHandler>(context, listen: false);
    _audioHandler.addListener(_onHandlerChanged);
    final initialSound = _getActiveNetworkSound();
    if (initialSound != null) {
      _currentActiveNetworkSoundId = initialSound.path;
    }
    _startMarqueeInitialDelay(resetMarqueeVisibility: true);
    _updateAudioState();
    _hadActiveSounds = _hasActiveSounds();
  }

  @override
  void dispose() {
    _audioHandler.removeListener(_onHandlerChanged);
    _marqueeInitialDelayTimer?.cancel();
    super.dispose();
  }

  void _onHandlerChanged() {
    if (!mounted) return;

    // Snapshot previous state before any updates.
    final wasAllPaused = _isAllPaused;
    final wasLoading = _isLoading;
    final hadActiveSounds = _hadActiveSounds;

    // Update derived state — must happen before any comparisons or early returns.
    _updateAudioState();
    _hadActiveSounds = _hasActiveSounds();

    if (_isAllPaused != wasAllPaused ||
        _isLoading != wasLoading ||
        hadActiveSounds != _hadActiveSounds) {
      // Pause state or active-sounds count changed — always rebuild.
      setState(() {});
      return;
    }

    // Check for network sound changes (station started / stopped).
    final newNetworkSound = _getActiveNetworkSound();
    if (newNetworkSound != null &&
        newNetworkSound.path != _currentActiveNetworkSoundId) {
      // New station started — reset marquee and rebuild for new station name.
      _currentActiveNetworkSoundId = newNetworkSound.path;
      _startMarqueeInitialDelay(resetMarqueeVisibility: true);
      setState(() {}); // _startMarqueeInitialDelay already called setState for
      //  _showMarquee; this extra call ensures station name refreshes too.
    } else if (newNetworkSound == null &&
        _currentActiveNetworkSoundId != null) {
      // Radio station stopped.
      _currentActiveNetworkSoundId = null;
      _marqueeInitialDelayTimer?.cancel();
      setState(() => _showMarquee = false);
    }
    // If nothing visible changed (e.g. a volume event on a non-radio sound),
    // skip the rebuild entirely.
  }

  /// Whether any sound is in playing, paused, or loading state.
  bool _hasActiveSounds() {
    return _audioHandler.allStatuses.entries.any((entry) {
      final status = entry.value;
      return status == PlaybackStatus.playing ||
          status == PlaybackStatus.paused ||
          status == PlaybackStatus.loading;
    });
  }

  /// Whether any non-radio (regular) sound is currently playing or paused.
  bool _hasActiveNonRadioSounds() {
    for (final controller in _audioHandler.allControllers) {
      if ((controller.status == PlaybackStatus.playing ||
              controller.status == PlaybackStatus.paused) &&
          !controller.sound.isStream) {
        return true;
      }
    }
    return false;
  }

  void _updateAudioState() {
    final statuses = _audioHandler.allStatuses.values.toList();
    _isAllPaused = statuses.isNotEmpty &&
        statuses.every((s) =>
            s == PlaybackStatus.paused ||
            s == PlaybackStatus.notInitialized ||
            s == PlaybackStatus.error);
    // Loading: at least one sound buffering, none actually playing yet.
    _isLoading = statuses.any((s) => s == PlaybackStatus.loading) &&
        !statuses.any((s) => s == PlaybackStatus.playing);
  }

  void _startMarqueeInitialDelay({bool resetMarqueeVisibility = true}) {
    _marqueeInitialDelayTimer?.cancel();
    if (resetMarqueeVisibility) {
      setState(() => _showMarquee = false);
    }
    _marqueeInitialDelayTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showMarquee = true);
    });
  }

  NinjaSound? _getActiveNetworkSound() {
    for (final controller in _audioHandler.allControllers) {
      if ((controller.status == PlaybackStatus.playing ||
              controller.status == PlaybackStatus.paused) &&
          controller.sound.isStream) {
        return controller.sound;
      }
    }
    return null;
  }

  void _stopAll() {
    _audioHandler.stopAll();
    _startMarqueeInitialDelay(resetMarqueeVisibility: true);
  }

  void _cancelSleepTimer() {
    if (_timerEnd == null) return;
    setState(() => _timerEnd = null);
  }

  void _startSleepTimer(Duration duration) {
    setState(() => _timerEnd = DateTime.now().add(duration));
  }

  Future<void> _showSleepTimerDialog() async {
    final options = <Duration>[
      const Duration(minutes: 5),
      const Duration(minutes: 10),
      const Duration(minutes: 15),
      const Duration(minutes: 30),
      const Duration(hours: 1),
    ];

    final selected = await showModalBottomSheet<Duration>(
      context: context,
      builder: (context) {
        final localizations = AppLocalizations.of(context);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final option in options)
                ListTile(
                  title: Text(localizations?.sleepInMinutes(option.inMinutes) ??
                      'Sleep in ${option.inMinutes} minutes'),
                  onTap: () => Navigator.of(context).pop(option),
                ),
              if (_timerEnd != null)
                ListTile(
                  title: Text(
                      localizations?.cancelSleepTimer ?? 'Cancel Sleep Timer'),
                  onTap: () => Navigator.of(context).pop(Duration.zero),
                ),
            ],
          ),
        );
      },
    );

    if (selected != null) {
      if (selected == Duration.zero) {
        _cancelSleepTimer();
      } else {
        _startSleepTimer(selected);
      }
    }
  }

  void _togglePlayPauseAll() {
    if (_isAllPaused) {
      _audioHandler.playAllPaused();
    } else {
      _audioHandler.pauseAll();
    }
  }

  /// Returns whether [metadata] overflows [maxWidth], re-measuring only when
  /// either value has changed since the last call.
  bool _checkMetadataOverflows(
      String metadata, double maxWidth, TextStyle? style) {
    if (metadata == _tpCachedMetadata && maxWidth == _tpCachedWidth) {
      return _tpCachedOverflows;
    }
    final tp = TextPainter(
      text: TextSpan(text: metadata, style: style),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: double.infinity);
    final overflows = tp.width > maxWidth;
    tp.dispose();
    _tpCachedMetadata = metadata;
    _tpCachedWidth = maxWidth;
    _tpCachedOverflows = overflows;
    return overflows;
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final hasActiveSounds = _hasActiveSounds();

    if (!hasActiveSounds) {
      _marqueeInitialDelayTimer?.cancel();
      _showMarquee = false;
      _currentActiveNetworkSoundId = null;
      return const SizedBox.shrink();
    }

    final networkSound = _getActiveNetworkSound();
    final hasActiveNonRadioSounds = _hasActiveNonRadioSounds();

    // Fixed subtitle height — same as one line of bodySmall — keeps the bar
    // the same height regardless of whether a subtitle is shown.
    final subtitleH =
        Theme.of(context).textTheme.bodySmall!.fontSize! * 1.6;
    final subtitleStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          fontStyle: FontStyle.italic,
          color: Theme.of(context).colorScheme.onSecondaryContainer,
        );

    return Material(
      elevation: 12,
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Play/pause button — becomes a spinner while loading.
            // Stop is always rendered separately so it's never blocked.
            SizedBox(
              width: 48,
              height: 48,
              child: _isLoading
                  ? Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    )
                  : IconButton(
                      icon: Icon(
                        _isAllPaused ? Icons.play_arrow : Icons.pause,
                        size: 30,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      tooltip: _isAllPaused
                          ? localizations?.resumeAll ?? 'Resume All'
                          : localizations?.pauseAll ?? 'Pause All',
                      onPressed: _togglePlayPauseAll,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (networkSound != null) ...[
                    Text(
                      networkSound.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: (_isAllPaused || _isLoading)
                                ? Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.6)
                                : null,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Fixed-height subtitle slot — always the same height so the
                    // bar doesn't resize when switching between states.
                    SizedBox(
                      height: subtitleH,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _isLoading
                            ? Text('Loading…', style: subtitleStyle)
                            : _isAllPaused
                                ? Text(
                                    localizations?.paused ?? 'Paused',
                                    style: subtitleStyle?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .tertiary,
                                      fontWeight: FontWeight.bold,
                                      fontStyle: FontStyle.normal,
                                    ),
                                    maxLines: 1,
                                  )
                                : ValueListenableBuilder<Map<String, String>>(
                                    valueListenable:
                                        _audioHandler.metadataNotifier,
                                    builder: (context, metaMap, _) {
                                      final metadata =
                                          _audioHandler.getMetadata(networkSound);
                                      if (metadata.isEmpty) {
                                        return const SizedBox.shrink();
                                      }
                                      return LayoutBuilder(
                                        builder: (context, constraints) {
                                          final overflows =
                                              _checkMetadataOverflows(
                                                  metadata,
                                                  constraints.maxWidth,
                                                  subtitleStyle);
                                          if (overflows) {
                                            return _showMarquee
                                                ? Marquee(
                                                    key: ValueKey(metadata),
                                                    text: metadata,
                                                    style: subtitleStyle,
                                                    scrollAxis: Axis.horizontal,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    blankSpace: 20.0,
                                                    velocity: 50.0,
                                                    pauseAfterRound:
                                                        const Duration(
                                                            seconds: 5),
                                                    startPadding: 0.0,
                                                    fadingEdgeStartFraction:
                                                        0.1,
                                                    fadingEdgeEndFraction: 0.1,
                                                  )
                                                : Text(
                                                    metadata,
                                                    style: subtitleStyle,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  );
                                          }
                                          return Text(
                                            metadata,
                                            style: subtitleStyle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          );
                                        },
                                      );
                                    },
                                  ),
                      ),
                    ),
                  ] else if (hasActiveNonRadioSounds) ...[
                    Text(
                      localizations?.playingSounds ?? 'Playing sounds',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: (_isAllPaused || _isLoading)
                                ? Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.6)
                                : null,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Fixed-height subtitle — same height whether showing text or empty.
                    SizedBox(
                      height: subtitleH,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _isLoading
                            ? Text('Loading…', style: subtitleStyle)
                            : _isAllPaused
                                ? Text(
                                    localizations?.paused ?? 'Paused',
                                    style: subtitleStyle?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .tertiary,
                                      fontWeight: FontWeight.bold,
                                      fontStyle: FontStyle.normal,
                                    ),
                                    maxLines: 1,
                                  )
                                : const SizedBox.shrink(),
                      ),
                    ),
                  ],
                  // Sleep countdown is its own StatefulWidget so only the
                  // tiny Text label rebuilds every second, not the whole bar.
                  if (_timerEnd != null)
                    _SleepCountdown(
                      timerEnd: _timerEnd!,
                      onExpired: () {
                        _stopAll();
                        _cancelSleepTimer();
                      },
                    ),
                ],
              ),
            ),

            // Right-aligned button row
            if (networkSound != null)
              ValueListenableBuilder<Map<String, String>>(
                valueListenable: _audioHandler.metadataNotifier,
                builder: (context, metaMap, _) {
                  final metadata = _audioHandler.getMetadata(networkSound);
                  if (metadata.isEmpty) return const SizedBox.shrink();
                  return IconButton(
                    icon: const Icon(Icons.copy),
                    tooltip:
                        localizations?.copyToClipboard ?? 'Copy to Clipboard',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: metadata));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(localizations?.copiedToClipboard ??
                              'Copied to clipboard'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  );
                },
              ),
            IconButton(
              icon: Icon(Icons.timer_outlined,
                  color: Theme.of(context).colorScheme.primary),
              tooltip: localizations?.setSleepTimer ?? 'Set Sleep Timer',
              onPressed: _showSleepTimerDialog,
            ),
            IconButton(
              icon: Icon(Icons.stop_circle_outlined,
                  size: 30, color: Theme.of(context).colorScheme.primary),
              tooltip: localizations?.stopAll ?? 'Stop All',
              onPressed: _stopAll,
            ),
          ],
        ),
      ),
    );
  }
}

/// Isolated countdown widget so only the [Text] label rebuilds every second
/// while a sleep timer is active — the rest of [BottomPlayerBar] stays still.
class _SleepCountdown extends StatefulWidget {
  final DateTime timerEnd;
  final VoidCallback onExpired;

  const _SleepCountdown({required this.timerEnd, required this.onExpired});

  @override
  State<_SleepCountdown> createState() => _SleepCountdownState();
}

class _SleepCountdownState extends State<_SleepCountdown> {
  late Timer _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = _computeRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  Duration _computeRemaining() {
    final r = widget.timerEnd.difference(DateTime.now());
    return r.isNegative ? Duration.zero : r;
  }

  void _tick(Timer _) {
    final remaining = _computeRemaining();
    if (remaining == Duration.zero) {
      _timer.cancel();
      widget.onExpired();
    } else if (mounted) {
      setState(() => _remaining = remaining);
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final mins = _remaining.inMinutes;
    final secs = (_remaining.inSeconds % 60).toString().padLeft(2, '0');
    return Text(
      localizations?.sleepRemainingTime(mins, secs) ?? 'Sleep in $mins:$secs',
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.error,
          ),
    );
  }
}
