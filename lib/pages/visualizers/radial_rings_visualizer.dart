import 'dart:math';
import 'package:auraninja/utils/visualizer_clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class RadialRingsVisualizer extends StatefulWidget {
  final List<Color> colors;
  final bool isPlaying;
  final int activeCount;

  const RadialRingsVisualizer({
    super.key,
    required this.colors,
    required this.isPlaying,
    required this.activeCount,
  });

  @override
  State<RadialRingsVisualizer> createState() => _RadialRingsVisualizerState();
}

class _RadialRingsVisualizerState extends State<RadialRingsVisualizer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final List<double> _phases;
  late final List<double> _strokeWidths;
  late final List<double> _speeds;
  double _time = 0.0;
  Duration _lastElapsed = Duration.zero;
  bool _skipFrame = false;
  double _accumDt = 0.0;

  static const int _ringCount = 6;

  // Advance 1 unit in ~8 s at full speed — matches original controller duration.
  static const double _cycleSpeed = 1.0 / 8.0;

  @override
  void initState() {
    super.initState();
    final rand = Random();
    _phases = List.generate(_ringCount, (_) => rand.nextDouble());
    _strokeWidths = List.generate(_ringCount, (_) => 1.5 + rand.nextDouble() * 1.0);
    _speeds = List.generate(_ringCount, (_) => 0.85 + rand.nextDouble() * 0.3);
    _ticker = createTicker(_onTick)..start();
    _time = VisualizerClock.elapsed * _cycleSpeed;
  }

  void _onTick(Duration elapsed) {
    _skipFrame = !_skipFrame;
    final rawDt = _lastElapsed == Duration.zero
        ? 0.0
        : (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    _accumDt += rawDt.clamp(0.0, 0.05);
    if (_skipFrame) return;
    final dt = _accumDt;
    _accumDt = 0.0;
    final speedMult = widget.isPlaying ? 1.0 : 0.15;
    setState(() => _time += dt * speedMult * _cycleSpeed);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: widget.isPlaying ? 1.0 : 0.3,
      duration: const Duration(milliseconds: 1000),
      child: CustomPaint(
        size: Size.infinite,
        painter: _RadialRingsPainter(
          time: _time,
          colors: widget.colors,
          phases: _phases,
          strokeWidths: _strokeWidths,
          speeds: _speeds,
        ),
      ),
    );
  }
}

class _RadialRingsPainter extends CustomPainter {
  final double time;
  final List<Color> colors;
  final List<double> phases;
  final List<double> strokeWidths;
  final List<double> speeds;

  _RadialRingsPainter({
    required this.time,
    required this.colors,
    required this.phases,
    required this.strokeWidths,
    required this.speeds,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.longestSide * 0.55;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < phases.length; i++) {
      final normalizedR = ((time * speeds[i] + phases[i]) % 1.0);
      final radius = normalizedR * maxRadius;
      // sin(π·t) gives 0→peak→0: rings fade in from centre, fade out at edge.
      final opacity = sin(normalizedR * pi).clamp(0.0, 1.0);

      paint.strokeWidth = strokeWidths[i];
      paint.color = colors[i % colors.length].withOpacity(opacity * 0.85);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadialRingsPainter old) => time != old.time;
}
