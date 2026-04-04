import 'dart:async';

import 'package:auraninja/audio/wrapper_audio_handler.dart';
import 'package:auraninja/audio/sound_controller.dart';
import 'package:auraninja/model/ninja_sound.dart';
import 'package:auraninja/pages/visualizers/aurora_visualizer.dart';
import 'package:auraninja/pages/visualizers/breathing_orb_visualizer.dart';
import 'package:auraninja/pages/visualizers/constellation_visualizer.dart';
import 'package:auraninja/pages/visualizers/ink_diffusion_visualizer.dart';
import 'package:auraninja/pages/visualizers/liquid_ribbons_visualizer.dart';
import 'package:auraninja/pages/visualizers/morphing_polygon_visualizer.dart';
import 'package:auraninja/pages/visualizers/particle_drift_visualizer.dart';
import 'package:auraninja/pages/visualizers/radial_rings_visualizer.dart';
import 'package:auraninja/pages/visualizers/rotating_mandala_visualizer.dart';
import 'package:auraninja/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

// ── Localised names for the fullscreen overlay ─────────────────────────────

List<String> _visualizerNames(BuildContext context) {
  final l = AppLocalizations.of(context)!;
  return [
    l.vizLiquidRibbons,
    l.vizBreathingOrb,
    l.vizRadialRings,
    l.vizParticleDrift,
    l.vizRotatingMandala,
    l.vizConstellation,
    l.vizMorphingPolygon,
    l.vizAurora,
    l.vizInkDiffusion,
  ];
}

// ── Shared visualizer builder ───────────────────────────────────────────────

Widget _buildVisualizer(
  int index,
  List<Color> colors,
  bool isPlaying,
  int activeCount,
) {
  switch (index) {
    case 0:
      return LiquidRibbonsVisualizer(
          colors: colors, isPlaying: isPlaying, activeCount: activeCount);
    case 1:
      return BreathingOrbVisualizer(
          colors: colors, isPlaying: isPlaying, activeCount: activeCount);
    case 2:
      return RadialRingsVisualizer(
          colors: colors, isPlaying: isPlaying, activeCount: activeCount);
    case 3:
      return ParticleDriftVisualizer(
          colors: colors, isPlaying: isPlaying, activeCount: activeCount);
    case 4:
      return RotatingMandalaVisualizer(
          colors: colors, isPlaying: isPlaying, activeCount: activeCount);
    case 5:
      return ConstellationVisualizer(
          colors: colors, isPlaying: isPlaying, activeCount: activeCount);
    case 6:
      return MorphingPolygonVisualizer(
          colors: colors, isPlaying: isPlaying, activeCount: activeCount);
    case 7:
      return AuroraVisualizer(
          colors: colors, isPlaying: isPlaying, activeCount: activeCount);
    case 8:
    default:
      return InkDiffusionVisualizer(
          colors: colors, isPlaying: isPlaying, activeCount: activeCount);
  }
}

// ── Visualizer page ─────────────────────────────────────────────────────────

class VisualizerPage extends StatefulWidget {
  const VisualizerPage({super.key});

  @override
  State<VisualizerPage> createState() => _VisualizerPageState();
}

class _VisualizerPageState extends State<VisualizerPage>
    with WidgetsBindingObserver {
  static const _prefKey = 'selected_visualizer_index';
  static const _count = 9;
  static const _swipeVelocityThreshold = 200.0;
  static const _overlayHideDelay = Duration(seconds: 3);

  int _selectedIndex = 0;

  // ── Fullscreen state ──────────────────────────────────────────────────────
  //
  // The visualizer widget is wrapped in KeyedSubtree(_vizKey). When going
  // fullscreen, the same GlobalKey is rendered inside a root OverlayEntry
  // instead of the page body. Flutter detects the key moved within the same
  // build pass and reparents the element — state (Ticker, _time, particles)
  // is preserved with zero rebuild.
  final _vizKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  bool _isFullscreen = false;
  bool _overlayVisible = true;
  Timer? _overlayTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SharedPreferences.getInstance().then((prefs) {
      final saved = prefs.getInt(_prefKey) ?? 0;
      if (mounted) setState(() => _selectedIndex = saved.clamp(0, _count - 1));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _overlayTimer?.cancel();
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      WakelockPlus.disable();
    }
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }

  // Intercept Android back button while fullscreen.
  @override
  Future<bool> didPopRoute() async {
    if (_isFullscreen) {
      _exitFullscreen();
      return true;
    }
    return false;
  }

  // ── Index navigation ──────────────────────────────────────────────────────

  void _goTo(int index) {
    final next = index.clamp(0, _count - 1);
    setState(() => _selectedIndex = next);
    // Keep the overlay in sync when navigating while fullscreen.
    _overlayEntry?.markNeedsBuild();
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setInt(_prefKey, next));
  }

  void _cycleNext() => _goTo((_selectedIndex + 1) % _count);
  void _cyclePrev() => _goTo((_selectedIndex - 1 + _count) % _count);

  // ── Fullscreen control ────────────────────────────────────────────────────

  void _openFullscreen() {
    // Insert the overlay entry first (initially renders SizedBox.shrink because
    // _isFullscreen is still false). Then setState + markNeedsBuild so both the
    // page and the overlay rebuild in the same frame: page drops _vizKey,
    // overlay picks it up → Flutter reparents the element tree atomically.
    _overlayEntry = OverlayEntry(builder: _buildFullscreenOverlay);
    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
    _overlayEntry!.markNeedsBuild();
    setState(() {
      _isFullscreen = true;
      _overlayVisible = true;
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();
    _scheduleOverlayHide();
  }

  void _exitFullscreen() {
    _overlayTimer?.cancel();
    // markNeedsBuild so the overlay rebuilds (returns SizedBox.shrink →
    // drops _vizKey) in the same frame as setState which re-adds _vizKey to
    // the page body → reparenting back to the page.
    _overlayEntry?.markNeedsBuild();
    setState(() {
      _isFullscreen = false;
      _overlayVisible = true;
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WakelockPlus.disable();
    // Defer removal until AFTER the reparenting build pass completes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
  }

  void _scheduleOverlayHide() {
    _overlayTimer?.cancel();
    _overlayTimer = Timer(_overlayHideDelay, () {
      if (mounted && _isFullscreen) {
        setState(() => _overlayVisible = false);
        _overlayEntry?.markNeedsBuild();
      }
    });
  }

  void _toggleOverlay() {
    setState(() => _overlayVisible = !_overlayVisible);
    _overlayEntry?.markNeedsBuild();
    if (_overlayVisible) {
      _scheduleOverlayHide();
    } else {
      _overlayTimer?.cancel();
    }
  }

  // ── Fullscreen overlay builder ────────────────────────────────────────────

  Widget _buildFullscreenOverlay(BuildContext ctx) {
    if (!_isFullscreen) return const SizedBox.shrink();

    // Use select (not watch) to only rebuild on isPlaying / activeCount changes,
    // matching the page's own select-based rebuild policy.
    final audioHandler = ctx.read<WrapperAudioHandler>();
    final isPlaying = ctx.select<WrapperAudioHandler, bool>(
      (h) => h.activeControllers.isNotEmpty,
    );
    final activeCount = ctx.select<WrapperAudioHandler, int>(
      (h) => h.activeControllers.length,
    );
    final isLoading = audioHandler.allStatuses.values.any(
      (status) => status == PlaybackStatus.loading,
    );
    final isAllPaused = audioHandler.allStatuses.values.isNotEmpty &&
        audioHandler.allStatuses.values.every((status) =>
            status == PlaybackStatus.paused ||
            status == PlaybackStatus.notInitialized ||
            status == PlaybackStatus.error);

    // Get network sound if any
    NinjaSound? networkSound;
    bool hasNonRadioSounds = false;
    for (final controller in audioHandler.activeControllers) {
      if (controller.sound.isStream) {
        networkSound = controller.sound;
      } else {
        hasNonRadioSounds = true;
      }
    }

    final localizations = AppLocalizations.of(ctx);
    final colorScheme = Theme.of(ctx).colorScheme;
    final soundInfoStyle = const TextStyle(
      color: Colors.white54,
      fontSize: 13,
      letterSpacing: 0.5,
    );
    final colors = [
      colorScheme.primary,
      colorScheme.secondary,
      colorScheme.tertiary,
      colorScheme.primaryContainer,
      colorScheme.secondaryContainer,
      colorScheme.tertiaryContainer,
    ];

    return Material(
      color: Colors.black,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleOverlay,
        onDoubleTap: _exitFullscreen,
        onHorizontalDragEnd: (details) {
          final v = details.primaryVelocity ?? 0;
          if (v < -_swipeVelocityThreshold) {
            _goTo((_selectedIndex + 1) % _count);
          } else if (v > _swipeVelocityThreshold) {
            _goTo((_selectedIndex - 1 + _count) % _count);
          }
          _scheduleOverlayHide();
        },
        child: Stack(
          children: [
            // ── Visualizer (reparented from page body via _vizKey) ──────────
            KeyedSubtree(
              key: _vizKey,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: child),
                child: KeyedSubtree(
                  key: ValueKey(_selectedIndex),
                  child: SizedBox.expand(
                    child: _buildVisualizer(
                        _selectedIndex, colors, isPlaying, activeCount),
                  ),
                ),
              ),
            ),

            // ── Layer 2: name + dots, fades with overlay ────────────────────
            AnimatedOpacity(
              opacity: _overlayVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 400),
              child: IgnorePointer(
                ignoring: !_overlayVisible,
                child: Stack(
                  children: [
                    // Visualizer name label
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            _visualizerNames(ctx)[_selectedIndex],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Dot indicator
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Padding(
                        padding: EdgeInsets.only(
                          bottom:
                              MediaQuery.of(ctx).systemGestureInsets.bottom +
                                  20,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Sound info text (above dots)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    networkSound?.name ??
                                        (hasNonRadioSounds
                                            ? (localizations?.playingSounds ??
                                                'Playing sounds')
                                            : ''),
                                    style: soundInfoStyle.copyWith(
                                      fontSize: 14,
                                      color: (isAllPaused || isLoading)
                                          ? Colors.white38
                                          : Colors.white70,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (networkSound != null ||
                                      hasNonRadioSounds) ...[
                                    const SizedBox(height: 4),
                                    if (isLoading)
                                      Text(
                                        'Loading...',
                                        style: soundInfoStyle.copyWith(
                                          fontStyle: FontStyle.italic,
                                        ),
                                      )
                                    else if (isAllPaused)
                                      Text(
                                        localizations?.paused ?? 'Paused',
                                        style: soundInfoStyle.copyWith(
                                          color: colorScheme.tertiary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    else if (networkSound != null)
                                      _NetworkMetadata(
                                        audioHandler: audioHandler,
                                        sound: networkSound,
                                        style: soundInfoStyle,
                                      ),
                                  ],
                                ],
                              ),
                            ),
                            _DotIndicator(
                              count: _count,
                              selected: _selectedIndex,
                              colorScheme: colorScheme,
                              onDotTap: (i) {
                                _goTo(i);
                                _scheduleOverlayHide();
                              },
                              onDark: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Layer 3: exit button — outermost so hit-tested first ────────
            Positioned(
              top: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: _overlayVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 400),
                child: IgnorePointer(
                  ignoring: !_overlayVisible,
                  child: SafeArea(
                    child: IconButton(
                      icon: const Icon(Icons.fullscreen_exit),
                      color: Colors.white70,
                      iconSize: 28,
                      onPressed: _exitFullscreen,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Page build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // select so we only rebuild on isPlaying / activeCount changes, not on
    // every audio handler notification (metadata polls, ICY updates, etc.).
    final isPlaying = context.select<WrapperAudioHandler, bool>(
      (h) => h.activeControllers.isNotEmpty,
    );
    final activeCount = context.select<WrapperAudioHandler, int>(
      (h) => h.activeControllers.length,
    );
    final colorScheme = Theme.of(context).colorScheme;

    final colors = [
      colorScheme.primary,
      colorScheme.secondary,
      colorScheme.tertiary,
      colorScheme.primaryContainer,
      colorScheme.secondaryContainer,
      colorScheme.tertiaryContainer,
    ];

    return Scaffold(
      // Keep background black while fullscreen so the placeholder body
      // doesn't flash a different colour during the reparenting transition.
      backgroundColor: _isFullscreen ? Colors.black : colorScheme.surface,
      body: GestureDetector(
        // Double tap to enter/exit fullscreen
        onDoubleTap: () {
          if (_isFullscreen) {
            _exitFullscreen();
          } else {
            _openFullscreen();
          }
        },
        // Disable page-level swipe while fullscreen; the overlay handles it.
        onHorizontalDragEnd: _isFullscreen
            ? null
            : (details) {
                if ((details.primaryVelocity ?? 0) < -_swipeVelocityThreshold) {
                  _cycleNext();
                } else if ((details.primaryVelocity ?? 0) >
                    _swipeVelocityThreshold) {
                  _cyclePrev();
                }
              },
        child: Stack(
          children: [
            // ── Visualizer area ─────────────────────────────────────────────
            // When NOT fullscreen: _vizKey subtree lives here.
            // When fullscreen: _vizKey subtree is in the overlay; page shows a
            // black placeholder so no flash occurs during reparenting.
            _isFullscreen
                ? const SizedBox.expand()
                : KeyedSubtree(
                    key: _vizKey,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 600),
                      transitionBuilder: (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                      child: KeyedSubtree(
                        key: ValueKey(_selectedIndex),
                        child: SizedBox.expand(
                          child: _buildVisualizer(
                              _selectedIndex, colors, isPlaying, activeCount),
                        ),
                      ),
                    ),
                  ),

            // ── Controls (hidden while fullscreen; overlay has its own) ─────
            if (!_isFullscreen) ...[
              Positioned(
                top: 12,
                right: 12,
                child: SafeArea(
                  child: IconButton(
                    icon: Icon(
                      Icons.fullscreen,
                      color: colorScheme.onSurface.withOpacity(0.5),
                    ),
                    tooltip: 'Fullscreen',
                    onPressed: _openFullscreen,
                  ),
                ),
              ),
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: _DotIndicator(
                  count: _count,
                  selected: _selectedIndex,
                  colorScheme: colorScheme,
                  onDotTap: _goTo,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Dot indicator ───────────────────────────────────────────────────────────

class _DotIndicator extends StatelessWidget {
  final int count;
  final int selected;
  final ColorScheme colorScheme;
  final void Function(int)? onDotTap;
  // When true, forces white dots (for use on a black fullscreen background).
  final bool onDark;

  const _DotIndicator({
    required this.count,
    required this.selected,
    required this.colorScheme,
    this.onDotTap,
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == selected;
        final dot = AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: isActive ? 10 : 6,
          height: isActive ? 10 : 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? (onDark ? Colors.white : colorScheme.primary)
                : (onDark
                    ? Colors.white.withOpacity(0.35)
                    : colorScheme.onSurface.withOpacity(0.25)),
          ),
        );
        // Wrap each dot in a generously-sized tap target.
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onDotTap != null ? () => onDotTap!(i) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: dot,
          ),
        );
      }),
    );
  }
}

// ── Network metadata widget ────────────────────────────────────────────────

class _NetworkMetadata extends StatelessWidget {
  final WrapperAudioHandler audioHandler;
  final NinjaSound sound;
  final TextStyle style;

  const _NetworkMetadata({
    required this.audioHandler,
    required this.sound,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, String>>(
      valueListenable: audioHandler.metadataNotifier,
      builder: (context, metaMap, _) {
        final metadata = audioHandler.getMetadata(sound);
        if (metadata.isEmpty) return const SizedBox.shrink();
        return Text(
          metadata,
          style: style.copyWith(
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}
