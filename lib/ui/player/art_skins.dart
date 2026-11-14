import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/type.dart';
import '../widgets/cover.dart';

/// Three original looks for the full player.
enum PlayerSkin { sleeve, vinyl, spectrum }

extension PlayerSkinLabel on PlayerSkin {
  String get label => switch (this) {
    PlayerSkin.sleeve => 'Sleeve',
    PlayerSkin.vinyl => 'Vinyl',
    PlayerSkin.spectrum => 'Spectrum',
  };
}

/// The album cover, presented as a print sleeve.
class SleeveArt extends StatelessWidget {
  const SleeveArt({
    super.key,
    required this.coverPath,
    required this.seed,
    required this.title,
    required this.artist,
  });

  final String? coverPath;
  final String seed;
  final String title;
  final String artist;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        return Center(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.42),
                  blurRadius: 44,
                  offset: const Offset(0, 22),
                  spreadRadius: -12,
                ),
              ],
            ),
            child: Cover(
              path: coverPath,
              seed: seed,
              title: title,
              artist: artist,
              radius: 26,
              hairline: true,
            ),
          ),
        );
      },
    );
  }
}

/// A spinning record with the cover as its label.
class VinylArt extends StatefulWidget {
  const VinylArt({
    super.key,
    required this.coverPath,
    required this.seed,
    required this.title,
    required this.artist,
    required this.playing,
  });

  final String? coverPath;
  final String seed;
  final String title;
  final String artist;
  final bool playing;

  @override
  State<VinylArt> createState() => _VinylArtState();
}

class _VinylArtState extends State<VinylArt> with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  );

  @override
  void initState() {
    super.initState();
    if (widget.playing) _spin.repeat();
  }

  @override
  void didUpdateWidget(covariant VinylArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playing && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!widget.playing && _spin.isAnimating) {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        return Center(
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                RotationTransition(
                  turns: _spin,
                  child: Container(
                    width: size * 0.94,
                    height: size * 0.94,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF0D0D0F),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 40,
                          offset: Offset(0, 18),
                          spreadRadius: -10,
                        ),
                      ],
                    ),
                    child: CustomPaint(
                      painter: _VinylPainter(),
                      child: Center(
                        child: ClipOval(
                          child: SizedBox(
                            width: size * 0.38,
                            height: size * 0.38,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Cover(
                                  path: widget.coverPath,
                                  seed: widget.seed,
                                  title: widget.title,
                                  artist: widget.artist,
                                  hairline: false,
                                ),
                                Center(
                                  child: Container(
                                    width: size * 0.035,
                                    height: size * 0.035,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF1A1A1C),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: size * 0.02,
                  right: size * 0.02,
                  child: CustomPaint(
                    size: Size(size * 0.3, size * 0.42),
                    painter: _TonearmPainter(engaged: widget.playing),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _VinylPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.045);
    for (var i = 1; i <= 14; i++) {
      canvas.drawCircle(center, radius * (0.44 + i * 0.036), groove);
    }
    // A single light sweep makes the record read as glossy, not flat black.
    final sheen = Paint()
      ..shader = SweepGradient(
        startAngle: -0.9,
        endAngle: 0.5,
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.07),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, sheen);
    canvas.drawCircle(
      center,
      radius * 0.995,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.06),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TonearmPainter extends CustomPainter {
  _TonearmPainter({required this.engaged});

  final bool engaged;

  @override
  void paint(Canvas canvas, Size size) {
    final pivot = Offset(size.width * 0.82, size.height * 0.09);
    final tip = engaged
        ? Offset(size.width * 0.5, size.height * 0.52)
        : Offset(size.width * 0.38, size.height * 0.4);
    final arm = Paint()
      ..color = const Color(0xFFE8E6E1).withValues(alpha: 0.82)
      ..strokeWidth = size.width * 0.055
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(pivot, tip, arm);
    canvas.drawCircle(
      pivot,
      size.width * 0.09,
      Paint()..color = const Color(0xFF2A2A2E),
    );
    canvas.drawCircle(
      pivot,
      size.width * 0.09,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.2),
    );
    canvas.drawCircle(
      tip,
      size.width * 0.045,
      Paint()..color = const Color(0xFFE8E6E1).withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(_TonearmPainter old) => old.engaged != engaged;
}

/// A calm spectrum that moves with the song. No cover needed.
class SpectrumArt extends StatefulWidget {
  const SpectrumArt({super.key, required this.playing, required this.seed});

  final bool playing;
  final String seed;

  @override
  State<SpectrumArt> createState() => _SpectrumArtState();
}

class _SpectrumArtState extends State<SpectrumArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void initState() {
    super.initState();
    if (widget.playing) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant SpectrumArt oldWidget) {
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
    final c = context.c;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        return Center(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: c.line),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  c.accent.withValues(alpha: 0.22),
                  c.surface.withValues(alpha: 0.6),
                ],
              ),
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: _SpectrumPainter(
                    t: _controller.value,
                    color: c.accent,
                    seed: widget.seed,
                  ),
                  size: Size(size, size),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _SpectrumPainter extends CustomPainter {
  _SpectrumPainter({required this.t, required this.color, required this.seed});

  final double t;
  final Color color;
  final String seed;

  @override
  void paint(Canvas canvas, Size size) {
    const count = 34;
    final gap = size.width * 0.012;
    final barWidth = (size.width * 0.78 - gap * (count - 1)) / count;
    final left0 = size.width * 0.11;
    final base = seed.codeUnits.fold<int>(0, (a, b) => a + b);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [color.withValues(alpha: 0.95), color.withValues(alpha: 0.35)],
      ).createShader(
        Rect.fromLTWH(left0, size.height * 0.2, size.width * 0.78, size.height * 0.6),
      );

    for (var i = 0; i < count; i++) {
      final phase = t * math.pi * 2 + i * 0.42 + (base % 7);
      final wave = 0.5 + 0.5 * math.sin(phase);
      final second = 0.5 + 0.5 * math.sin(phase * 1.7 + 1.2);
      final level = 0.14 + 0.72 * (wave * 0.6 + second * 0.4);
      final height = size.height * 0.58 * level;
      final x = left0 + i * (barWidth + gap);
      final y = size.height * 0.5 - height / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, height),
          Radius.circular(barWidth),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SpectrumPainter old) =>
      old.t != t || old.color != color || old.seed != seed;
}
