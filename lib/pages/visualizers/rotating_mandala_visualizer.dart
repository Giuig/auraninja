import 'dart:math';
import 'package:auraninja/utils/visualizer_clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class RotatingMandalaVisualizer extends StatefulWidget {
  final List<Color> colors;
  final bool isPlaying;
  final int activeCount;

  const RotatingMandalaVisualizer({
    super.key,
    required this.colors,
    required this.isPlaying,
    required this.activeCount,
  });

  @override
  State<RotatingMandalaVisualizer> createState() =>
      _RotatingMandalaVisualizerState();
}

class _RotatingMandalaVisualizerState extends State<RotatingMandalaVisualizer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final List<double> _ringPhases;
  late final List<int> _petalCounts;
  double _time = 0.0;
  Duration _lastElapsed = Duration.zero;
  bool _skipFrame = false;
  double _accumDt = 0.0;

  // Advance 2π in ~16 s at full speed — matches original controller duration.
  static const double _cycleSpeed = 2 * pi / 16.0;

  @override
  void initState() {
    super.initState();
    final rand = Random();
    _ringPhases = List.generate(3, (_) => rand.nextDouble() * 2 * pi);
    _petalCounts = [
      5 + rand.nextInt(2),
      7 + rand.nextInt(2),
      10 + rand.nextInt(3),
    ];
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
        painter: _MandalaPainter(
          time: _time,
          colors: widget.colors,
          ringPhases: _ringPhases,
          petalCounts: _petalCounts,
        ),
      ),
    );
  }
}

class _MandalaPainter extends CustomPainter {
  final double time;
  final List<Color> colors;
  final List<double> ringPhases;
  final List<int> petalCounts;

  _MandalaPainter({
    required this.time,
    required this.colors,
    required this.ringPhases,
    required this.petalCounts,
  });

  void _drawPetalRing(
    Canvas canvas,
    Offset center,
    int petalCount,
    double innerR,
    double outerR,
    double rotation,
    Color color,
    double opacity,
  ) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withOpacity(opacity);

    final angleStep = 2 * pi / petalCount;

    for (int i = 0; i < petalCount; i++) {
      final angle = i * angleStep + rotation;
      final tipX = center.dx + cos(angle) * outerR;
      final tipY = center.dy + sin(angle) * outerR;

      final leftAngle = angle - angleStep * 0.35;
      final rightAngle = angle + angleStep * 0.35;

      final cp1x = center.dx + cos(leftAngle) * innerR * 1.2;
      final cp1y = center.dy + sin(leftAngle) * innerR * 1.2;
      final cp2x = center.dx + cos(rightAngle) * innerR * 1.2;
      final cp2y = center.dy + sin(rightAngle) * innerR * 1.2;

      final baseLeft = Offset(
        center.dx + cos(leftAngle) * innerR * 0.5,
        center.dy + sin(leftAngle) * innerR * 0.5,
      );
      final baseRight = Offset(
        center.dx + cos(rightAngle) * innerR * 0.5,
        center.dy + sin(rightAngle) * innerR * 0.5,
      );

      final path = Path()
        ..moveTo(baseLeft.dx, baseLeft.dy)
        ..quadraticBezierTo(cp1x, cp1y, tipX, tipY)
        ..quadraticBezierTo(cp2x, cp2y, baseRight.dx, baseRight.dy)
        ..close();

      canvas.drawPath(path, paint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final base = size.shortestSide * 0.42;

    _drawPetalRing(
      canvas, center, petalCounts[0], base * 0.15, base * 0.45,
      time * 1.1 + ringPhases[0], colors[0], 0.75,
    );
    _drawPetalRing(
      canvas, center, petalCounts[1], base * 0.3, base * 0.75,
      -time * 0.7 + ringPhases[1], colors[1], 0.6,
    );
    _drawPetalRing(
      canvas, center, petalCounts[2], base * 0.5, base * 1.0,
      time * 0.5 + ringPhases[2], colors[2], 0.45,
    );

    final centerPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = colors[3].withOpacity(0.9);
    canvas.drawCircle(center, base * 0.12, centerPaint);

    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = colors[0].withOpacity(0.95);
    canvas.drawCircle(center, base * 0.05, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _MandalaPainter old) => time != old.time;
}
