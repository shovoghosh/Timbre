import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// The five generated looks a song gets when the file carries no picture.
enum CoverStyle { bars, rings, dots, wave, type }

/// Deterministic brand artwork, seeded by a song or album key.
class BrandCover extends StatelessWidget {
  const BrandCover({
    super.key,
    required this.seed,
    this.title = '',
    this.artist = '',
    this.style,
    this.radius = 0,
  });

  final String seed;
  final String title;
  final String artist;
  final CoverStyle? style;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final resolved = style ?? coverStyleFor(seed);
    final pair = coverColorsFor(seed);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CustomPaint(
        painter: _BrandCoverPainter(
          style: resolved,
          base: pair.$1,
          top: pair.$2,
          mark: pair.$3,
          initials: _initials(title: title, artist: artist),
        ),
        size: Size.infinite,
      ),
    );
  }
}

String _initials({required String title, required String artist}) {
  final source = title.trim().isNotEmpty ? title.trim() : artist.trim();
  if (source.isEmpty) return 'T';
  final words = source
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty && RegExp(r'[A-Za-z0-9]').hasMatch(w))
      .toList();
  if (words.isEmpty) return source[0].toUpperCase();
  if (words.length == 1) {
    final w = words.first;
    return w.substring(0, math.min(2, w.length)).toUpperCase();
  }
  return (words[0][0] + words[1][0]).toUpperCase();
}

int _hash(String value) {
  var h = 0x811C9DC5;
  for (final unit in value.codeUnits) {
    h ^= unit;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h;
}

CoverStyle coverStyleFor(String seed) {
  final styles = CoverStyle.values;
  return styles[_hash(seed) % styles.length];
}

/// Base, top and mark colors for a seed. Deliberately separate from the accent
/// palette so generated art still looks good on every theme.
(Color, Color, Color) coverColorsFor(String seed) {
  const pairs = <(Color, Color)>[
    (Color(0xFF1E2E33), Color(0xFF4F8486)),
    (Color(0xFF2E2226), Color(0xFFB4694E)),
    (Color(0xFF252735), Color(0xFF5A6AAE)),
    (Color(0xFF2B2C22), Color(0xFF8B8F5A)),
    (Color(0xFF2A202C), Color(0xFF925E80)),
    (Color(0xFF232629), Color(0xFF70757C)),
    (Color(0xFF332A20), Color(0xFFC18A4C)),
    (Color(0xFF1D2627), Color(0xFF51806D)),
  ];
  final pair = pairs[_hash(seed) % pairs.length];
  final mark = Color.lerp(pair.$2, Colors.white, 0.72)!;
  return (pair.$1, pair.$2, mark);
}

class _BrandCoverPainter extends CustomPainter {
  _BrandCoverPainter({
    required this.style,
    required this.base,
    required this.top,
    required this.mark,
    required this.initials,
  });

  final CoverStyle style;
  final Color base;
  final Color top;
  final Color mark;
  final String initials;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.clipRect(rect);

    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topLeft,
          rect.bottomRight,
          [top, base],
        ),
    );

    // A soft light from the top left gives the flat gradient some depth.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.18, size.height * 0.06),
          size.longestSide * 0.9,
          [Colors.white.withValues(alpha: 0.16), Colors.white.withValues(alpha: 0)],
        ),
    );

    switch (style) {
      case CoverStyle.bars:
        _bars(canvas, size);
      case CoverStyle.rings:
        _rings(canvas, size);
      case CoverStyle.dots:
        _dots(canvas, size);
      case CoverStyle.wave:
        _wave(canvas, size);
      case CoverStyle.type:
        _type(canvas, size);
    }
  }

  void _bars(Canvas canvas, Size size) {
    final paint = Paint()..color = mark.withValues(alpha: 0.9);
    final count = 7;
    final barWidth = size.width * 0.055;
    final gap = (size.width * 0.62 - barWidth * count) / (count - 1);
    final startX = size.width * 0.19;
    const ratios = [0.30, 0.52, 0.78, 1.0, 0.72, 0.46, 0.26];
    for (var i = 0; i < count; i++) {
      final h = size.height * 0.46 * ratios[i];
      final x = startX + i * (barWidth + gap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height * 0.5 - h / 2, barWidth, h),
          Radius.circular(barWidth),
        ),
        paint,
      );
    }
  }

  void _rings(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.72, size.height * 0.72);
    for (var i = 0; i < 5; i++) {
      canvas.drawCircle(
        center,
        size.width * (0.10 + i * 0.115),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.014
          ..color = mark.withValues(alpha: 0.55 - i * 0.08),
      );
    }
    canvas.drawCircle(
      center,
      size.width * 0.05,
      Paint()..color = mark.withValues(alpha: 0.85),
    );
  }

  void _dots(Canvas canvas, Size size) {
    final paint = Paint()..color = mark.withValues(alpha: 0.75);
    final step = size.width * 0.115;
    final startX = size.width * 0.2;
    final startY = size.height * 0.3;
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 4; c++) {
        final fade = 1.0 - ((r + c) / 8);
        paint.color = mark.withValues(alpha: 0.18 + fade * 0.55);
        canvas.drawCircle(
          Offset(startX + c * step * 0.9, startY + r * step * 0.9),
          size.width * (0.012 + 0.012 * fade),
          paint,
        );
      }
    }
  }

  void _wave(Canvas canvas, Size size) {
    final path = Path();
    final amp = size.height * 0.13;
    final mid = size.height * 0.55;
    path.moveTo(0, mid);
    for (var x = 0.0; x <= size.width; x += size.width / 48) {
      final t = x / size.width;
      final y = mid + math.sin(t * math.pi * 3.1) * amp * (1 - t * 0.45);
      path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.018
        ..strokeCap = StrokeCap.round
        ..color = mark.withValues(alpha: 0.85),
    );
    // A second, quieter line for movement.
    final path2 = Path();
    path2.moveTo(0, mid + size.height * 0.16);
    for (var x = 0.0; x <= size.width; x += size.width / 48) {
      final t = x / size.width;
      final y =
          mid + size.height * 0.16 + math.sin(t * math.pi * 2.2 + 1.2) * amp * 0.55;
      path2.lineTo(x, y);
    }
    canvas.drawPath(
      path2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.01
        ..strokeCap = StrokeCap.round
        ..color = mark.withValues(alpha: 0.35),
    );
  }

  void _type(Canvas canvas, Size size) {
    final painter = TextPainter(
      text: TextSpan(
        text: initials,
        style: TextStyle(
          fontFamily: 'InstrumentSerif',
          fontSize: size.shortestSide * 0.42,
          height: 1,
          letterSpacing: -2,
          color: mark.withValues(alpha: 0.92),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(
        (size.width - painter.width) / 2,
        (size.height - painter.height) / 2,
      ),
    );
    final paint = Paint()..color = mark.withValues(alpha: 0.5);
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
        Offset(size.width * 0.12 + i * size.width * 0.045, size.height * 0.86),
        size.width * 0.008,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BrandCoverPainter old) =>
      old.style != style ||
      old.base != base ||
      old.top != top ||
      old.mark != mark ||
      old.initials != initials;
}

/// Album art for a track: the cached picture when there is one, generated brand
/// art when there is not.
class Cover extends StatelessWidget {
  const Cover({
    super.key,
    this.path,
    this.seed = '',
    this.title = '',
    this.artist = '',
    this.radius = Radii.md,
    this.size,
    this.fit = BoxFit.cover,
    this.hairline = true,
    this.style,
  });

  final String? path;
  final String seed;
  final String title;
  final String artist;
  final double radius;
  final double? size;
  final BoxFit fit;
  final bool hairline;
  final CoverStyle? style;

  @override
  Widget build(BuildContext context) {
    final filePath = path;
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0;
    final cacheWidth = size == null
        ? null
        : (size! * dpr * 1.15).round().clamp(64, 1400);

    Widget art;
    if (filePath == null || filePath.isEmpty) {
      art = BrandCover(
        seed: seed.isEmpty ? '$title$artist' : seed,
        title: title,
        artist: artist,
        style: style,
      );
    } else {
      art = Image.file(
        File(filePath),
        fit: fit,
        width: size,
        height: size,
        cacheWidth: cacheWidth,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => BrandCover(
          seed: seed.isEmpty ? '$title$artist' : seed,
          title: title,
          artist: artist,
          style: style,
        ),
        frameBuilder: (context, child, frame, wasSync) {
          if (wasSync || frame != null) {
            return AnimatedOpacity(
              opacity: 1,
              duration: Motion.fast,
              child: child,
            );
          }
          return BrandCover(
            seed: seed.isEmpty ? '$title$artist' : seed,
            title: title,
            artist: artist,
            style: style,
          );
        },
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            art,
            if (hairline)
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
