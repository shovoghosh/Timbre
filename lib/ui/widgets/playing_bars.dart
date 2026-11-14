import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/type.dart';

/// Three little bars that dance while a track plays.
class PlayingBars extends StatefulWidget {
  const PlayingBars({
    super.key,
    this.size = 16,
    this.color,
    this.playing = true,
  });

  final double size;
  final Color? color;
  final bool playing;

  @override
  State<PlayingBars> createState() => _PlayingBarsState();
}

class _PlayingBarsState extends State<PlayingBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.playing) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant PlayingBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playing && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.playing && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tint = widget.color ?? context.c.accent;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _BarsPainter(_controller.value, tint),
          );
        },
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter(this.t, this.color);

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final barWidth = size.width * 0.2;
    final gap = (size.width - barWidth * 3) / 2;
    for (var i = 0; i < 3; i++) {
      final phase = t * math.pi * 2 + i * 1.1;
      final level = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(phase));
      final height = size.height * level;
      final left = i * (barWidth + gap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, size.height - height, barWidth, height),
          Radius.circular(barWidth),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) => old.t != t || old.color != color;
}

/// Duration text for the right side of a track row.
class DurationLabel extends StatelessWidget {
  const DurationLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: context.numeric(size: 12, color: context.c.textFaint),
    );
  }
}
