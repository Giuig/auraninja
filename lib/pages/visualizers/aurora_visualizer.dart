import 'dart:math';
import 'package:auraninja/utils/visualizer_clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class AuroraVisualizer extends StatefulWidget {
  final List<Color> colors;
  final bool isPlaying;
  final int activeCount;

  const AuroraVisualizer({
    super.key,
    required this.colors,
    required this.isPlaying,
    required this.activeCount,
  });

  @override
  State<AuroraVisualizer> createState() => _AuroraVisualizerState();
}

class _AuroraVisualizerState extends State<AuroraVisualizer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  // Each band: [speed, phase, centerRatio, waveFreq]
  late final List<List<double>> _bandParams;
  double _time = 0.0;
  Duration _lastElapsed = Duration.zero;
  bool _skipFrame = false;
  double _accumDt = 0.0;

  // Advance 2π in ~20 s at full speed — matches original controller duration.
  static const double _cycleSpeed = 2 * pi / 20.0;

  @override
  void initState() {
    super.initState();
    final rand = Random();
    _bandParams = List.generate(4, (_) {
      return [
        0.25 + rand.nextDouble() * 0.2,     // speed 0.25–0.45
        rand.nextDouble() * 2 * pi,         // phase 0–2π
        0.15 + rand.nextDouble() * 0.7,     // center ratio 0.15–0.85
        1.4 + rand.nextDouble() * 0.8,      // wave freq 1.4–2.2
      ];
    });
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
        painter: _AuroraPainter(
          time: _time,
          colors: widget.colors,
          bandParams: _bandParams,
        ),
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final double time;
  final List<Color> colors;
  final List<List<double>> bandParams;

  _AuroraPainter({
    required this.time,
    required this.colors,
    required this.bandParams,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bandWidth = size.width * 0.55;

    for (int b = 0; b < bandParams.length; b++) {
      final params = bandParams[b];
      final speed = params[0];
      final phase = params[1];
      final centerRatio = params[2];
      final waveFreq = params[3];

      final cx = (centerRatio + 0.12 * sin(time * speed + phase)) * size.width;

      const segments = 40;
      final bandPath = Path();

      // Build left edge top→bottom
      for (int s = 0; s <= segments; s++) {
        final t = s / segments;
        final y = t * size.height;
        final wave = sin(t * waveFreq * pi + time * speed * 2 + phase) * 18;
        final left = cx - bandWidth / 2 + wave;
        if (s == 0) bandPath.moveTo(left, y);
        else bandPath.lineTo(left, y);
      }

      // Walk right edge bottom→top
      for (int s = segments; s >= 0; s--) {
        final t = s / segments;
        final y = t * size.height;
        final wave = sin(t * waveFreq * pi + time * speed * 2 + phase) * 18;
        final right = cx + bandWidth / 2 + wave;
        bandPath.lineTo(right, y);
      }
      bandPath.close();

      final color = colors[b % colors.length];
      final gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withOpacity(0.0),
          color.withOpacity(0.45),
          color.withOpacity(0.55),
          color.withOpacity(0.45),
          color.withOpacity(0.0),
        ],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      );

      final paint = Paint()
        ..shader = gradient.createShader(
          Rect.fromLTWH(0, 0, size.width, size.height),
        )
        ..blendMode = BlendMode.plus;

      canvas.drawPath(bandPath, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter old) => time != old.time;
}
