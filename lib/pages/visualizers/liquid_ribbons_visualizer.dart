import 'dart:math';
import 'package:auraninja/utils/visualizer_clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class LiquidRibbonsVisualizer extends StatefulWidget {
  final List<Color> colors;
  final bool isPlaying;
  final int activeCount;

  const LiquidRibbonsVisualizer({
    super.key,
    required this.colors,
    required this.isPlaying,
    required this.activeCount,
  });

  @override
  State<LiquidRibbonsVisualizer> createState() =>
      _LiquidRibbonsVisualizerState();
}

class _LiquidRibbonsVisualizerState extends State<LiquidRibbonsVisualizer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final List<double> _randomOffsets;
  double _time = 0.0;
  Duration _lastElapsed = Duration.zero;
  bool _skipFrame = false;
  double _accumDt = 0.0;

  // Advance 2π in ~12 s at full speed — matches original controller duration.
  static const double _cycleSpeed = 2 * pi / 12.0;

  @override
  void initState() {
    super.initState();
    _randomOffsets = List.generate(6, (_) => Random().nextDouble() * 2 * pi);
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
        painter: _LiquidRibbonPainter(
          time: _time,
          colors: widget.colors,
          offsets: _randomOffsets,
        ),
      ),
    );
  }
}

class _LiquidRibbonPainter extends CustomPainter {
  final double time;
  final List<Color> colors;
  final List<double> offsets;

  _LiquidRibbonPainter({
    required this.time,
    required this.colors,
    required this.offsets,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final waveCount = offsets.length;
    final waveSpacing = size.height / (waveCount + 1);
    final waveLength = size.width / 3;

    for (int i = 0; i < waveCount; i++) {
      final baseY = waveSpacing * (i + 1);
      final color = colors[i % colors.length];

      final path = Path();
      const segments = 60;

      for (int x = 0; x <= segments; x++) {
        final dx = x * size.width / segments;
        final dy = sin((dx / waveLength) * 2 * pi + time + offsets[i]) *
            20 *
            (1 + 0.5 * sin(time * 2 + i));
        final posY = baseY + dy;

        if (x == 0) {
          path.moveTo(dx, posY);
        } else {
          path.lineTo(dx, posY);
        }
      }

      final gradient = LinearGradient(
        colors: [
          color.withOpacity(0.6),
          color.withOpacity(1.0),
          color.withOpacity(0.6),
        ],
        stops: const [0.0, 0.5, 1.0],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        transform: GradientRotation(time / 3),
      );

      paint.shader =
          gradient.createShader(Rect.fromLTWH(0, baseY - 30, size.width, 60));
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LiquidRibbonPainter oldDelegate) =>
      time != oldDelegate.time;
}
