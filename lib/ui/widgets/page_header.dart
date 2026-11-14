import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../theme/type.dart';
import 'brand.dart';
import 'buttons.dart';

/// Page background with a very soft accent wash at the top. Reads as depth, not
/// as a glow.
class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.child,
    this.wash = true,
    this.resizeToAvoidBottomInset = true,
  });

  final Widget child;
  final bool wash;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.canvas,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: Stack(
        children: [
          if (wash)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 320,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        c.accent.withValues(alpha: c.isDark ? 0.10 : 0.07),
                        c.accent.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          SafeArea(bottom: false, child: child),
        ],
      ),
    );
  }
}

/// Large editorial page title with an optional kicker and trailing action.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    this.kicker,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(Space.page, 18, Space.page, 10),
    this.titleSize = 36,
  });

  final String? kicker;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsets padding;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (kicker != null) ...[
                      Kicker(kicker!),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      title,
                      style: context.serif(size: titleSize, height: 1.0),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 8),
                      Text(subtitle!, style: context.sans(color: context.c.textDim)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                Padding(padding: const EdgeInsets.only(top: 4), child: trailing!),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Section heading with a serif title and an optional action.
class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    this.action,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(Space.page, 26, Space.page, 12),
    this.size = 22,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsets padding;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              title,
              style: context.serif(size: size, height: 1.1),
            ),
          ),
          if (action != null)
            TextAction(label: action!, onPressed: onAction, icon: Icons.chevron_right),
        ],
      ),
    );
  }
}

/// Friendly empty state with brand art and up to two actions.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.compact = false,
  });

  final String title;
  final String message;
  final IconData? icon;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Space.xxl,
        vertical: compact ? Space.xl : Space.xxxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: c.accentSoft,
              shape: BoxShape.circle,
              border: Border.all(color: c.accentLine),
            ),
            child: Center(
              child: icon == null
                  ? const BrandMark(size: 34)
                  : Icon(icon, size: 30, color: c.accent),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: context.serif(size: compact ? 21 : 25, height: 1.15),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: context.sans(size: 14, color: c.textDim, height: 1.5),
            ),
          ),
          if (primaryLabel != null) ...[
            const SizedBox(height: 22),
            PrimaryButton(label: primaryLabel!, onPressed: onPrimary),
          ],
          if (secondaryLabel != null) ...[
            const SizedBox(height: 10),
            QuietButton(label: secondaryLabel!, onPressed: onSecondary),
          ],
        ],
      ),
    );
  }
}

/// A hairline that matches the theme, with predictable spacing.
class Hairline extends StatelessWidget {
  const Hairline({
    super.key,
    this.indent = 0,
    this.endIndent = 0,
    this.margin = EdgeInsets.zero,
  });

  final double indent;
  final double endIndent;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Divider(height: 1, thickness: 1, indent: indent, endIndent: endIndent),
    );
  }
}
