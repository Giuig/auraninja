import 'dart:math';
import 'package:auraninja/utils/visualizer_clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class BreathingOrbVisualizer extends StatefulWidget {
  final List<Color> colors;
  final bool isPlaying;
  final int activeCount;

  const BreathingOrbVisualizer({
    super.key,
    required this.colors,
    required this.isPlaying,
    required this.activeCount,
  });

  @override
  State<BreathingOrbVisualizer> createState() => _BreathingOrbVisualizerState();
}

class _BreathingOrbVisualizerState extends State<BreathingOrbVisualizer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final double _phase;
  late final double _wobbleFreq;
  late final double _wobbleAmp;
  double _time = 0.0;
  Duration _lastElapsed = Duration.zero;
  bool _skipFrame = false;
  double _accumDt = 0.0;

  // Advance 2π in ~6 s at full speed — matches original controller duration.
  static const double _cycleSpeed = 2 * pi / 6.0;

  @override
  void initState() {
    super.initState();
    final rand = Random();
    _phase = rand.nextDouble() * 2 * pi;
    _wobbleFreq = 1.5 + rand.nextDouble() * 0.8;
    _wobbleAmp = 0.02 + rand.nextDouble() * 0.03;
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
    final speedMult = widget.isPlaying ? 1.0 : 0.2;
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
      opacity: widget.isPlaying ? 1.0 : 0.35,
      duration: const Duration(milliseconds: 1000),
      child: CustomPaint(
        size: Size.infinite,
        painter: _BreathingOrbPainter(
          time: _time,
          phase: _phase,
          wobbleFreq: _wobbleFreq,
          wobbleAmp: _wobbleAmp,
          colors: widget.colors,
        ),
      ),
    );
  }
}

class _BreathingOrbPainter extends CustomPainter {
  final double time;
  final double phase;
  final double wobbleFreq;
  final double wobbleAmp;
  final List<Color> colors;

  _BreathingOrbPainter({
    required this.time,
    required this.phase,
    required this.wobbleFreq,
    required this.wobbleAmp,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final base = size.shortestSide;
    final minR = base * 0.15;
    final maxR = base * 0.35;

    final t = (sin(time + phase) + 1) / 2;
    final wobble = wobbleAmp * base * sin(time * wobbleFreq + phase * 1.3);
    final radius = (minR + (maxR - minR) * t + wobble).clamp(minR * 0.8, maxR * 1.1);

    final primary = colors[0];
    final secondary = colors[1];
    final tertiary = colors[2];

    for (int i = 2; i >= 1; i--) {
      final glowR = radius + i * 18.0;
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0 - i * 1.5
        ..color = colors[3].withOpacity((0.25 - i * 0.08).clamp(0.0, 1.0));
      canvas.drawCircle(center, glowR, glowPaint);
    }

    final gradient = RadialGradient(
      colors: [
        primary.withOpacity(0.95),
        secondary.withOpacity(0.7),
        tertiary.withOpacity(0.0),
      ],
      stops: const [0.0, 0.55, 1.0],
    );

    final orbPaint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      );
    canvas.drawCircle(center, radius, orbPaint);

    final highlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = primary.withOpacity(0.5);
    canvas.drawCircle(center, radius * 0.6, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant _BreathingOrbPainter old) => time != old.time;
}
