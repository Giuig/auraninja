import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class FireflySwarmVisualizer extends StatefulWidget {
  final List<Color> colors;
  final bool isPlaying;
  final int activeCount;

  const FireflySwarmVisualizer({
    super.key,
    required this.colors,
    required this.isPlaying,
    required this.activeCount,
  });

  @override
  State<FireflySwarmVisualizer> createState() => _FireflySwarmVisualizerState();
}

class _Firefly {
  double x; // 0..1
  double y; // 0..1
  double angle; // heading, radians
  final double speed; // normalized units per second
  final double turnRate; // how sharply it can curve, rad/s of noise
  final double blinkSpeed; // rad/s
  final double blinkPhase;
  final double radius;
  final int colorIndex;

  _Firefly({
    required this.x,
    required this.y,
    required this.angle,
    required this.speed,
    required this.turnRate,
    required this.blinkSpeed,
    required this.blinkPhase,
    required this.radius,
    required this.colorIndex,
  });
}

class _FireflySwarmVisualizerState extends State<FireflySwarmVisualizer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final List<_Firefly> _flies;
  final _rand = Random();
  double _time = 0.0;
  Duration _lastTime = Duration.zero;
  bool _skipFrame = false;
  double _accumDt = 0.0;

  static const int _count = 35;

  @override
  void initState() {
    super.initState();
    _flies = List.generate(_count, (i) {
      return _Firefly(
        x: _rand.nextDouble(),
        y: _rand.nextDouble(),
        angle: _rand.nextDouble() * 2 * pi,
        speed: 0.015 + _rand.nextDouble() * 0.02,
        turnRate: 1.0 + _rand.nextDouble() * 1.5,
        blinkSpeed: 0.6 + _rand.nextDouble() * 0.8,
        blinkPhase: _rand.nextDouble() * 2 * pi,
        radius: 2.0 + _rand.nextDouble() * 2.0,
        colorIndex: i % 6,
      );
    });
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    _skipFrame = !_skipFrame;
    // Clamp dt to 50 ms so a tab-switch or screen-off/on (which pauses the
    // ticker and resumes with a huge elapsed jump) never causes fireflies to
    // teleport across the screen in one frame.
    final rawDt = _lastTime == Duration.zero
        ? 0.0
        : (elapsed - _lastTime).inMicroseconds / 1e6;
    _lastTime = elapsed;
    _accumDt += rawDt.clamp(0.0, 0.05);
    if (_skipFrame) return;
    final dt = _accumDt;
    _accumDt = 0.0;

    final speedMult = widget.isPlaying ? 1.0 : 0.15;
    _time += dt * speedMult;
    for (final f in _flies) {
      // Small random heading nudges each tick instead of a straight line or
      // a hard bounce — gives the organic, meandering drift of a real
      // firefly rather than a mechanical particle.
      f.angle += (_rand.nextDouble() * 2 - 1) * f.turnRate * dt;
      f.x = (f.x + cos(f.angle) * f.speed * dt * speedMult) % 1.0;
      f.y = (f.y + sin(f.angle) * f.speed * dt * speedMult) % 1.0;
      if (f.x < 0) f.x += 1.0;
      if (f.y < 0) f.y += 1.0;
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
        painter: _FireflyPainter(
          flies: _flies,
          colors: widget.colors,
          time: _time,
        ),
      ),
    );
  }
}

class _FireflyPainter extends CustomPainter {
  final List<_Firefly> flies;
  final List<Color> colors;
  final double time;

  _FireflyPainter({
    required this.flies,
    required this.colors,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final glowPaint = Paint()
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.plus
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
    final corePaint = Paint()
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.plus;

    for (final f in flies) {
      // A real firefly's flash is a quick bright pulse, not a smooth sine —
      // clamping the sine to its positive half and cubing it sharpens the
      // peak and holds near-zero (invisible) for most of the cycle.
      final raw = sin(time * f.blinkSpeed + f.blinkPhase);
      final blink = pow(raw.clamp(0.0, 1.0), 3).toDouble();
      if (blink < 0.02) continue;

      final center = Offset(f.x * size.width, f.y * size.height);
      final color = colors[f.colorIndex % colors.length];

      glowPaint.color = color.withOpacity(blink * 0.4);
      canvas.drawCircle(center, f.radius * 4, glowPaint);

      corePaint.color = color.withOpacity(blink * 0.9);
      canvas.drawCircle(center, f.radius, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FireflyPainter old) => true;
}
