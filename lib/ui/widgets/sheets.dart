import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../theme/type.dart';

/// Opens a rounded sheet that matches the rest of the app.
Future<R?> showTimbreSheet<R>(
  BuildContext context, {
  required Widget child,
  bool dismissible = true,
  double maxHeightFactor = 0.92,
}) {
  final height = MediaQuery.sizeOf(context).height * maxHeightFactor;
  return showModalBottomSheet<R>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    isDismissible: dismissible,
    enableDrag: dismissible,
    builder: (sheetContext) {
      final c = sheetContext.c;
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: Container(
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          constraints: BoxConstraints(maxHeight: height),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(Radii.xl),
            border: Border.all(color: c.line),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Radii.xl),
            child: child,
          ),
        ),
      );
    },
  );
}

/// Drag handle plus serif title, used at the top of every sheet.
class SheetHeader extends StatelessWidget {
  const SheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.showHandle = true,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool showHandle;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHandle)
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 14),
              decoration: BoxDecoration(
                color: c.lineStrong,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          )
        else
          const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.serif(size: 24, height: 1.1)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: context.sans(
                          size: 12.5,
                          color: c.textDim,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 10), trailing!],
            ],
          ),
        ),
      ],
    );
  }
}

/// A sheet row with an icon, a label and optional trailing widget.
class SheetTile extends StatelessWidget {
  const SheetTile({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tint = destructive
        ? const Color(0xFFD1453B)
        : (selected ? c.accent : c.text);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: destructive
                    ? tint.withValues(alpha: 0.12)
                    : (selected ? c.accentSoft : c.surfaceHigh),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: tint),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: context.sans(size: 14.5, weight: 500, color: tint),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: context.sans(
                        size: 12,
                        color: c.textFaint,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// A compact frosted chip used for counts and labels inside sheets.
class SheetChip extends StatelessWidget {
  const SheetChip(this.label, {super.key, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? c.accent).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: (color ?? c.accent).withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        style: context.sans(
          size: 10.5,
          weight: 600,
          color: color ?? c.accent,
          height: 1.2,
        ),
      ),
    );
  }
}

/// A blurred overlay panel, used behind the full player.
class BlurPanel extends StatelessWidget {
  const BlurPanel({super.key, required this.child, this.blur = 40});

  final Widget child;
  final double blur;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: child,
      ),
    );
  }
}
