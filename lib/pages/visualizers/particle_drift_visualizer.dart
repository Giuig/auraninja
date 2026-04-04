import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class ParticleDriftVisualizer extends StatefulWidget {
  final List<Color> colors;
  final bool isPlaying;
  final int activeCount;

  const ParticleDriftVisualizer({
    super.key,
    required this.colors,
    required this.isPlaying,
    required this.activeCount,
  });

  @override
  State<ParticleDriftVisualizer> createState() =>
      _ParticleDriftVisualizerState();
}

class _Particle {
  double x; // 0..1 normalized
  double y; // 0..1 normalized
  final double speed; // normalized units per second
  final double radius;
  final int colorIndex;

  _Particle({
    required this.x,
    required this.y,
    required this.speed,
    required this.radius,
    required this.colorIndex,
  });
}

class _ParticleDriftVisualizerState extends State<ParticleDriftVisualizer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final List<_Particle> _particles;
  Duration _lastTime = Duration.zero;
  bool _skipFrame = false;
  double _accumDt = 0.0;

  static const int _count = 60;

  @override
  void initState() {
    super.initState();
    final rand = Random();
    _particles = List.generate(_count, (i) {
      return _Particle(
        x: rand.nextDouble(),
        y: rand.nextDouble(),
        speed: 0.02 + rand.nextDouble() * 0.06,
        radius: 2.0 + rand.nextDouble() * 4.0,
        colorIndex: i % 6,
      );
    });
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    _skipFrame = !_skipFrame;
    // Clamp dt to 50 ms so a tab-switch or screen-off/on (which pauses the
    // ticker and resumes with a huge elapsed jump) never causes particles
    // to teleport across the screen in one frame.
    final rawDt = _lastTime == Duration.zero
        ? 0.0
        : (elapsed - _lastTime).inMicroseconds / 1e6;
    _lastTime = elapsed;
    _accumDt += rawDt.clamp(0.0, 0.05);
    if (_skipFrame) return;
    final dt = _accumDt;
    _accumDt = 0.0;

    final speedMult = widget.isPlaying ? 1.0 : 0.15;
    for (final p in _particles) {
      p.y -= p.speed * dt * speedMult;
      if (p.y < -0.02) {
        p.y = 1.02;
        p.x = Random().nextDouble();
      }
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
        painter: _ParticlePainter(
          particles: _particles,
          colors: widget.colors,
        ),
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final List<Color> colors;

  _ParticlePainter({required this.particles, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in particles) {
      paint.color = colors[p.colorIndex % colors.length].withOpacity(0.7);
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => true;
}
