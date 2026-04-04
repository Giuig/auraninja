/// Global clock used by all visualizers to synchronize [_time] initialization.
///
/// When a visualizer widget is rebuilt (e.g. entering/exiting fullscreen),
/// seeding [_time] from [VisualizerClock.elapsed] × [_cycleSpeed] ensures the
/// new instance starts at the same visual phase as the previous one instead of
/// resetting to zero.
class VisualizerClock {
  VisualizerClock._();

  static final Stopwatch _sw = Stopwatch()..start();

  /// Seconds elapsed since app launch.
  static double get elapsed => _sw.elapsed.inMicroseconds / 1e6;
}
