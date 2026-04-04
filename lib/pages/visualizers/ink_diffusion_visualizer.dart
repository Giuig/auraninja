import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class InkDiffusionVisualizer extends StatefulWidget {
  final List<Color> colors;
  final bool isPlaying;
  final int activeCount;

  const InkDiffusionVisualizer({
    super.key,
    required this.colors,
    required this.isPlaying,
    required this.activeCount,
  });

  @override
  State<InkDiffusionVisualizer> createState() => _InkDiffusionVisualizerState();
}

class _InkBlob {
  double cx; // 0..1 normalized
  double cy;
  double age; // 0..1
  final int colorIndex;

  _InkBlob({
    required this.cx,
    required this.cy,
    required this.age,
    required this.colorIndex,
  });
}

class _InkDiffusionVisualizerState extends State<InkDiffusionVisualizer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final List<_InkBlob> _blobs;
  Duration _lastTime = Duration.zero;
  bool _skipFrame = false;
  double _accumDt = 0.0;

  static const int _count = 5;

  @override
  void initState() {
    super.initState();
    final rand = Random();
    // Stagger initial ages so blobs are at different lifecycle stages
    _blobs = List.generate(_count, (i) {
      return _InkBlob(
        cx: rand.nextDouble(),
        cy: rand.nextDouble(),
        age: i / _count,
        colorIndex: i % 6,
      );
    });
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    _skipFrame = !_skipFrame;
    // Clamp dt to 50 ms to prevent blobs jumping after a tab-switch or
    // screen-off/on (which pauses the Ticker and causes a large elapsed jump).
    final rawDt = _lastTime == Duration.zero
        ? 0.0
        : (elapsed - _lastTime).inMicroseconds / 1e6;
    _lastTime = elapsed;
    _accumDt += rawDt.clamp(0.0, 0.05);
    if (_skipFrame) return;
    final dt = _accumDt;
    _accumDt = 0.0;

    final speed = widget.isPlaying ? 0.18 : 0.06;
    final rand = Random();

    for (final blob in _blobs) {
      blob.age += speed * dt;
      if (blob.age >= 1.0) {
        blob.age = 0.0;
        blob.cx = rand.nextDouble();
        blob.cy = rand.nextDouble();
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
      opacity: widget.isPlaying ? 1.0 : 0.35,
      duration: const Duration(milliseconds: 1000),
      child: CustomPaint(
        size: Size.infinite,
        painter: _InkDiffusionPainter(
          blobs: _blobs,
          colors: widget.colors,
        ),
      ),
    );
  }
}

class _InkDiffusionPainter extends CustomPainter {
  final List<_InkBlob> blobs;
  final List<Color> colors;

  _InkDiffusionPainter({required this.blobs, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final maxR = size.shortestSide * 0.45;

    for (final blob in blobs) {
      final radius = maxR * blob.age;
      final opacity = sin(pi * blob.age).clamp(0.0, 1.0);
      final color = colors[blob.colorIndex % colors.length];
      final center = Offset(blob.cx * size.width, blob.cy * size.height);

      final gradient = RadialGradient(
        colors: [
          color.withOpacity(opacity * 0.65),
          color.withOpacity(opacity * 0.2),
          color.withOpacity(0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      );

      final paint = Paint()
        ..shader = gradient.createShader(
          Rect.fromCircle(center: center, radius: radius),
        );

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _InkDiffusionPainter old) => true;
}
