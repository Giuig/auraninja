import 'dart:math';
import 'package:auraninja/utils/visualizer_clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class MorphingPolygonVisualizer extends StatefulWidget {
  final List<Color> colors;
  final bool isPlaying;
  final int activeCount;

  const MorphingPolygonVisualizer({
    super.key,
    required this.colors,
    required this.isPlaying,
    required this.activeCount,
  });

  @override
  State<MorphingPolygonVisualizer> createState() =>
      _MorphingPolygonVisualizerState();
}

class _MorphingPolygonVisualizerState extends State<MorphingPolygonVisualizer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final List<double> _freqs;
  late final List<double> _phases;
  double _time = 0.0;
  Duration _lastElapsed = Duration.zero;
  bool _skipFrame = false;
  double _accumDt = 0.0;

  static const int _vertexCount = 8;

  // Advance 2π in ~10 s at full speed — matches original controller duration.
  static const double _cycleSpeed = 2 * pi / 10.0;

  @override
  void initState() {
    super.initState();
    final rand = Random();
    _freqs = List.generate(_vertexCount, (_) => 0.6 + rand.nextDouble() * 0.7);
    _phases = List.generate(_vertexCount, (_) => rand.nextDouble() * 2 * pi);
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
        painter: _MorphingPolygonPainter(
          time: _time,
          colors: widget.colors,
          freqs: _freqs,
          phases: _phases,
        ),
      ),
    );
  }
}

class _MorphingPolygonPainter extends CustomPainter {
  final double time;
  final List<Color> colors;
  final List<double> freqs;
  final List<double> phases;

  _MorphingPolygonPainter({
    required this.time,
    required this.colors,
    required this.freqs,
    required this.phases,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseR = size.shortestSide * 0.3;
    final morphAmp = baseR * 0.2;
    final n = freqs.length;
    final angleStep = 2 * pi / n;

    // Build vertex list
    final vertices = List.generate(n, (i) {
      final angle = i * angleStep - pi / 2;
      final r = baseR + morphAmp * sin(time * freqs[i] + phases[i]);
      return Offset(center.dx + cos(angle) * r, center.dy + sin(angle) * r);
    });

    // Smooth closed path with quadraticBezierTo
    final path = Path();
    path.moveTo(
      (vertices[n - 1].dx + vertices[0].dx) / 2,
      (vertices[n - 1].dy + vertices[0].dy) / 2,
    );
    for (int i = 0; i < n; i++) {
      final curr = vertices[i];
      final next = vertices[(i + 1) % n];
      final mid = Offset((curr.dx + next.dx) / 2, (curr.dy + next.dy) / 2);
      path.quadraticBezierTo(curr.dx, curr.dy, mid.dx, mid.dy);
    }
    path.close();

    // Rotating gradient stroke
    final gradient = LinearGradient(
      colors: [
        colors[0].withOpacity(0.9),
        colors[1].withOpacity(0.9),
        colors[2].withOpacity(0.9),
        colors[0].withOpacity(0.9),
      ],
      stops: const [0.0, 0.33, 0.66, 1.0],
      transform: GradientRotation(time * 0.5),
    );

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..shader = gradient.createShader(
        Rect.fromCenter(center: center, width: baseR * 2.5, height: baseR * 2.5),
      );

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = colors[3].withOpacity(0.08);

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _MorphingPolygonPainter old) =>
      time != old.time;
}
