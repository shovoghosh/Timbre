import 'package:flutter/material.dart';

import '../../core/haptics.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import 'pressable.dart';

/// The main call to action.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = false,
    this.loading = false,
    this.color,
    this.height = 52,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final bool loading;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final enabled = onPressed != null && !loading;
    final fill = color ?? c.accent;
    final fg = Color.lerp(fill, Colors.white, 0.92)!;
    final ink = fill.computeLuminance() > 0.55 ? Colors.black : fg;

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: ink),
          )
        else if (icon != null)
          Icon(icon, size: 19, color: enabled ? ink : c.textFaint),
        if (icon != null || loading) const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.sans(
              size: 15,
              weight: 600,
              color: enabled ? ink : c.textFaint,
              height: 1.1,
            ),
          ),
        ),
      ],
    );

    return Pressable(
      onTap: enabled ? onPressed : null,
      scale: 0.97,
      child: AnimatedContainer(
        duration: Motion.fast,
        height: height,
        width: expand ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: enabled ? fill : c.surfaceHigh,
          borderRadius: BorderRadius.circular(Radii.pill),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: fill.withValues(alpha: 0.28),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                    spreadRadius: -8,
                  ),
                ]
              : null,
        ),
        child: Center(widthFactor: expand ? null : 1, child: content),
      ),
    );
  }
}

/// A quieter button that sits on the same surface as the page.
class QuietButton extends StatelessWidget {
  const QuietButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = false,
    this.height = 48,
    this.selected = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final double height;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Pressable(
      onTap: onPressed,
      scale: 0.97,
      child: Container(
        height: height,
        width: expand ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: selected ? c.accentSoft : c.surfaceHigh,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: selected ? c.accentLine : c.line),
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 18,
                color: selected ? c.accent : c.textDim,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.sans(
                size: 14,
                weight: 600,
                color: selected ? c.accent : c.text,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A round icon button used in headers and player controls.
class CircleButton extends StatelessWidget {
  const CircleButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 42,
    this.iconSize = 20,
    this.filled = false,
    this.color,
    this.tooltip,
    this.badge,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final bool filled;
  final Color? color;
  final String? tooltip;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tint = color ?? (filled ? c.onAccent : c.text);

    Widget button = Pressable(
      onTap: onPressed,
      scale: 0.92,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: filled ? c.accent : c.surfaceHigh,
          shape: BoxShape.circle,
          border: filled ? null : Border.all(color: c.line),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: iconSize, color: tint),
            if (badge != null)
              Positioned(right: size * 0.16, top: size * 0.16, child: badge!),
          ],
        ),
      ),
    );

    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }
    return Semantics(button: true, label: tooltip, child: button);
  }
}

/// Small accent-colored text action, e.g. "See all".
class TextAction extends StatelessWidget {
  const TextAction({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: onPressed == null
          ? null
          : () {
              Haptics.tap();
              onPressed!();
            },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: context.sans(
                size: 13,
                weight: 600,
                color: c.accent,
              ),
            ),
            if (icon != null) ...[
              const SizedBox(width: 4),
              Icon(icon, size: 15, color: c.accent),
            ],
          ],
        ),
      ),
    );
  }
}
