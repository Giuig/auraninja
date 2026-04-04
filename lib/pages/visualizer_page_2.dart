import 'dart:math';
import 'package:flutter/material.dart';

class VisualizerPage extends StatefulWidget {
  const VisualizerPage({super.key});

  @override
  State<VisualizerPage> createState() => _VisualizerPageState();
}

class _VisualizerPageState extends State<VisualizerPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late List<_SquareData> squares;

  final int rows = 8;
  final int cols = 12;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _generateSquares();
  }

  void _generateSquares() {
    final rand = Random();
    squares = List.generate(rows * cols, (i) {
      return _SquareData(
        rotationSpeed: 0.5 + rand.nextDouble() * 1.5,
        rotationPhase: rand.nextDouble() * 2 * pi,
        scalePhase: rand.nextDouble() * 2 * pi,
      );
    });
  }

  void _reshuffle() {
    setState(() {
      _generateSquares();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final colors = [
      cs.primary,
      cs.secondary,
      cs.primaryContainer,
      cs.secondaryContainer,
      cs.tertiary ?? cs.primary.withOpacity(0.7),
      cs.error,
    ];

    return Scaffold(
      backgroundColor: cs.surface,
      body: GestureDetector(
        onTap: _reshuffle,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, __) {
            return CustomPaint(
              size: Size.infinite,
              painter: _GridSquaresPainter(
                time: _controller.value * 2 * pi,
                squares: squares,
                rows: rows,
                cols: cols,
                colors: colors,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SquareData {
  final double rotationSpeed;
  final double rotationPhase;
  final double scalePhase;

  _SquareData({
    required this.rotationSpeed,
    required this.rotationPhase,
    required this.scalePhase,
  });
}

class _GridSquaresPainter extends CustomPainter {
  final double time;
  final List<_SquareData> squares;
  final int rows;
  final int cols;
  final List<Color> colors;

  _GridSquaresPainter({
    required this.time,
    required this.squares,
    required this.rows,
    required this.cols,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    final cellWidth = size.width / cols;
    final cellHeight = size.height / rows;
    final squareSize = min(cellWidth, cellHeight) * 0.6;

    int idx = 0;

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        final data = squares[idx];
        final cx = col * cellWidth + cellWidth / 2;
        final cy = row * cellHeight + cellHeight / 2;

        // Calculate rotation with easing back and forth
        final rotation =
            sin(time * data.rotationSpeed + data.rotationPhase) * pi / 4;

        // Pulsing scale
        final scale = 0.75 + 0.25 * sin(time * 2 + data.scalePhase);

        canvas.save();
        canvas.translate(cx, cy);
        canvas.rotate(rotation);
        canvas.scale(scale);

        // Cycle color smoothly based on position + time
        final colorIndex =
            ((row + col + (time / (2 * pi)) * colors.length).floor()) %
                colors.length;
        paint.color = colors[colorIndex].withOpacity(0.85);

        final rect = Rect.fromCenter(
          center: Offset.zero,
          width: squareSize,
          height: squareSize,
        );

        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(6)),
          paint,
        );

        canvas.restore();

        idx++;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GridSquaresPainter oldDelegate) => true;
}
