import 'package:flutter/material.dart';

import '../../core/haptics.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';

/// A segmented picker that fits the rest of the surface language.
class Segmented<V> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelect,
    this.expand = true,
    this.compact = false,
  });

  final List<(V, String)> items;
  final V selected;
  final ValueChanged<V> onSelect;
  final bool expand;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final row = Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surfaceHigh,
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: c.line),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (final item in items)
            if (expand)
              Expanded(child: _Segment(item: item, selected: item.$1 == selected, onTap: onSelect, compact: compact))
            else
              _Segment(item: item, selected: item.$1 == selected, onTap: onSelect, compact: compact),
        ],
      ),
    );
    return row;
  }
}

class _Segment<V> extends StatelessWidget {
  const _Segment({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.compact,
  });

  final (V, String) item;
  final bool selected;
  final ValueChanged<V> onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (selected) return;
        Haptics.tap();
        onTap(item.$1);
      },
      child: AnimatedContainer(
        duration: Motion.base,
        curve: Motion.curve,
        height: compact ? 30 : 36,
        padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 10),
        decoration: BoxDecoration(
          color: selected ? c.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: Center(
          child: Text(
            item.$2,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.sans(
              size: compact ? 12 : 13,
              weight: selected ? 600 : 500,
              color: selected ? c.onAccent : c.textDim,
              height: 1.1,
            ),
          ),
        ),
      ),
    );
  }
}
