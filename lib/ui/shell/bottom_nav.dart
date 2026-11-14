import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../widgets/pressable.dart';

/// One row of the tab bar.
class NavItem {
  const NavItem(this.icon, this.activeIcon, this.label);
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

const navItems = <NavItem>[
  NavItem(Icons.waves_outlined, Icons.waves_rounded, 'Home'),
  NavItem(Icons.library_music_outlined, Icons.library_music_rounded, 'Library'),
  NavItem(Icons.search_rounded, Icons.search_rounded, 'Search'),
  NavItem(Icons.person_outline_rounded, Icons.person_rounded, 'You'),
];

/// Floating, tactile tab bar. The active item gets a soft accent pill so the
/// current place is obvious at a glance.
class BottomNav extends StatelessWidget {
  const BottomNav({
    super.key,
    required this.index,
    required this.onSelect,
    this.glass = true,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final shape = BorderRadius.circular(Radii.lg);
    final surface = c.glass && glass
        ? c.surface.withValues(alpha: 0.88)
        : c.surface;

    Widget bar = Container(
      height: 64,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: shape,
        border: Border.all(color: c.line),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final slot = constraints.maxWidth / navItems.length;
          const pillWidth = 44.0;
          final center = slot * (index + 0.5);
          final travel = constraints.maxWidth - pillWidth;
          final alignment = travel <= 0
              ? 0.0
              : ((center - pillWidth / 2) / travel) * 2 - 1;
          return Stack(
            children: [
              // One pill, sliding between tabs instead of fading in place.
              Positioned.fill(
                child: AnimatedAlign(
                  duration: Motion.base,
                  curve: Motion.curve,
                  alignment: Alignment(alignment, -0.36),
                  child: Container(
                    width: pillWidth,
                    height: 28,
                    decoration: BoxDecoration(
                      color: c.accentSoft,
                      borderRadius: BorderRadius.circular(Radii.pill),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < navItems.length; i++)
                    Expanded(
                      child: _NavButton(
                        item: navItems[i],
                        active: i == index,
                        onTap: () => onSelect(i),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );

    if (c.glass && glass) {
      bar = ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
          child: bar,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: shape,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: c.isDark ? 0.36 : 0.10),
              blurRadius: 30,
              offset: const Offset(0, 12),
              spreadRadius: -8,
            ),
          ],
        ),
        child: bar,
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final NavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Pressable(
      onTap: onTap,
      scale: 0.94,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        selected: active,
        button: true,
        label: item.label,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 44,
                height: 28,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(scale: animation, child: child),
                  ),
                  child: Icon(
                    active ? item.activeIcon : item.icon,
                    key: ValueKey(active),
                    size: 21,
                    color: active ? c.accent : c.textDim,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                style: context.sans(
                  size: 9.5,
                  weight: active ? 600 : 500,
                  color: active ? c.accent : c.textFaint,
                  height: 1.1,
                  spacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
