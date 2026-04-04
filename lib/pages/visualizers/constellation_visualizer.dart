import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class ConstellationVisualizer extends StatefulWidget {
  final List<Color> colors;
  final bool isPlaying;
  final int activeCount;

  const ConstellationVisualizer({
    super.key,
    required this.colors,
    required this.isPlaying,
    required this.activeCount,
  });

  @override
  State<ConstellationVisualizer> createState() =>
      _ConstellationVisualizerState();
}

class _Star {
  double x; // 0..1
  double y; // 0..1
  final double vx; // normalized velocity
  final double vy;
  final double radius;

  _Star({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.radius,
  });
}

class _ConstellationVisualizerState extends State<ConstellationVisualizer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final List<_Star> _stars;
  Duration _lastTime = Duration.zero;
  bool _skipFrame = false;
  double _accumDt = 0.0;

  static const int _count = 45;

  @override
  void initState() {
    super.initState();
    final rand = Random();
    _stars = List.generate(_count, (_) {
      final angle = rand.nextDouble() * 2 * pi;
      final speed = 0.008 + rand.nextDouble() * 0.012;
      return _Star(
        x: rand.nextDouble(),
        y: rand.nextDouble(),
        vx: cos(angle) * speed,
        vy: sin(angle) * speed,
        radius: 2.0 + rand.nextDouble() * 2.5,
      );
    });
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    _skipFrame = !_skipFrame;
    // Clamp dt to 50 ms to prevent stars teleporting after a tab-switch or
    // screen-off/on (which pauses the Ticker and causes a large elapsed jump).
    final rawDt = _lastTime == Duration.zero
        ? 0.0
        : (elapsed - _lastTime).inMicroseconds / 1e6;
    _lastTime = elapsed;
    _accumDt += rawDt.clamp(0.0, 0.05);
    if (_skipFrame) return;
    final dt = _accumDt;
    _accumDt = 0.0;

    final speedMult = widget.isPlaying ? 1.0 : 0.15;
    for (final s in _stars) {
      s.x = (s.x + s.vx * dt * speedMult) % 1.0;
      s.y = (s.y + s.vy * dt * speedMult) % 1.0;
      if (s.x < 0) s.x += 1.0;
      if (s.y < 0) s.y += 1.0;
    }
    setState(() {});
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
        painter: _ConstellationPainter(
          stars: _stars,
          colors: widget.colors,
        ),
      ),
    );
  }
}

class _ConstellationPainter extends CustomPainter {
  final List<_Star> stars;
  final List<Color> colors;

  _ConstellationPainter({required this.stars, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final threshold = size.shortestSide * 0.25;
    final thresholdSq = threshold * threshold;

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final dotPaint = Paint()..style = PaintingStyle.fill;

    // Draw lines between close stars
    for (int i = 0; i < stars.length; i++) {
      for (int j = i + 1; j < stars.length; j++) {
        final ax = stars[i].x * size.width;
        final ay = stars[i].y * size.height;
        final bx = stars[j].x * size.width;
        final by = stars[j].y * size.height;
        final dx = ax - bx;
        final dy = ay - by;
        final distSq = dx * dx + dy * dy;

        if (distSq < thresholdSq) {
          final opacity = (1.0 - sqrt(distSq) / threshold).clamp(0.0, 1.0);
          linePaint.color = colors[1].withOpacity(opacity * 0.6);
          canvas.drawLine(Offset(ax, ay), Offset(bx, by), linePaint);
        }
      }
    }

    // Draw star dots
    for (int i = 0; i < stars.length; i++) {
      final s = stars[i];
      dotPaint.color = colors[i % colors.length].withOpacity(0.85);
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height),
        s.radius,
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ConstellationPainter old) => true;
}
