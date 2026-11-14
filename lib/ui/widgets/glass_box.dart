import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../theme/type.dart';

/// Frosted panel used by the tab bar, mini player and sheets.
///
/// Falls back to a solid surface when the listener turns glass off or when the
/// platform cannot blur cheaply.
class GlassBox extends StatelessWidget {
  const GlassBox({
    super.key,
    required this.child,
    this.radius = Radii.lg,
    this.padding,
    this.blur = 24,
    this.tint,
    this.border = true,
    this.shadow = true,
    this.clip = true,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final double blur;
  final Color? tint;
  final bool border;
  final bool shadow;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final glassOn = c.glass && !c.isAmoled;
    final shape = BorderRadius.circular(radius);
    final baseColor =
        tint ?? c.surface.withValues(alpha: glassOn ? 0.72 : 0.98);

    Widget panel = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: shape,
        border: border ? Border.all(color: c.line) : null,
      ),
      child: child,
    );

    if (glassOn) {
      panel = ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: panel,
        ),
      );
    } else if (clip) {
      panel = ClipRRect(borderRadius: shape, child: panel);
    }

    if (!shadow) return panel;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: c.isDark ? 0.34 : 0.10),
            blurRadius: 28,
            offset: const Offset(0, 10),
            spreadRadius: -6,
          ),
        ],
      ),
      child: panel,
    );
  }
}
