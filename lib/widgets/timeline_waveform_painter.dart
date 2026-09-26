import 'dart:math' as math;
import 'package:flutter/material.dart';

class TimelineWaveformPainter extends CustomPainter {
  final Color color;
  final double durationSec;
  final int seed;

  const TimelineWaveformPainter({
    required this.color,
    required this.durationSec,
    required this.seed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 2 || size.height <= 2) return;

    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.0;

    final midY = size.height / 2;
    const barSpacing = 4.0;
    final barCount = (size.width / barSpacing).floor();

    for (int i = 0; i < barCount; i++) {
      final x = i * barSpacing + 2.0;
      final sampleIndex = (i * 7 + seed).abs();
      final t = (x / size.width) * durationSec;

      // Realistic audio wave synthesis based on seed and time offset
      final wave1 = math.sin(t * 9.0 + (seed % 17));
      final wave2 = math.cos(t * 23.0 + (sampleIndex % 19));
      final wave3 = math.sin(t * 43.0 + (sampleIndex % 29));
      final rawAmp = ((wave1 * 0.45 + wave2 * 0.35 + wave3 * 0.20).abs()).clamp(0.08, 0.95);

      final barHeight = rawAmp * (size.height * 0.76);
      canvas.drawLine(
        Offset(x, midY - barHeight / 2),
        Offset(x, midY + barHeight / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant TimelineWaveformPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.durationSec != durationSec ||
        oldDelegate.seed != seed;
  }
}
