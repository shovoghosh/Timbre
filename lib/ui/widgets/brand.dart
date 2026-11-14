import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/type.dart';

/// The Timbre mark: five spectrum bars, rounded, in the current accent.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = 28,
    this.color,
    this.gradient = true,
  });

  final double size;
  final Color? color;
  final bool gradient;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tint = color ?? c.accent;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BarsPainter(
          color: tint,
          second: Color.lerp(tint, c.onAccent, 0.35)!,
          gradient: gradient,
        ),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.color,
    required this.second,
    required this.gradient,
  });

  final Color color;
  final Color second;
  final bool gradient;

  static const _heights = <double>[0.46, 0.74, 1.0, 0.64, 0.38];

  @override
  void paint(Canvas canvas, Size size) {
    final barWidth = size.width * 0.115;
    final gap = (size.width - barWidth * _heights.length) / (_heights.length - 1);
    final paint = Paint()..style = PaintingStyle.fill;
    if (gradient) {
      paint.shader = ui.Gradient.linear(
        Offset(0, size.height),
        Offset(size.width, 0),
        [color, second],
      );
    } else {
      paint.color = color;
    }
    final radius = Radius.circular(barWidth);

    for (var i = 0; i < _heights.length; i++) {
      final h = size.height * _heights[i];
      final left = i * (barWidth + gap);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, size.height - h, barWidth, h),
        radius,
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.color != color || old.second != second || old.gradient != gradient;
}

/// "Timbre" set in the editorial serif, with generous tracking.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 30, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Timbre',
      style: TextStyle(
        fontFamily: 'InstrumentSerif',
        fontSize: size,
        height: 1,
        letterSpacing: -0.5,
        color: color ?? context.c.text,
      ),
    );
  }
}

/// A small overline label used above page titles.
class Kicker extends StatelessWidget {
  const Kicker(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: context.overline(color: color, spacing: 1.6),
    );
  }
}
