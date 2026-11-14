import 'package:flutter/material.dart';

/// Base colors for the two themes. Widgets should read [TimbreColors] from the
/// theme instead of using these directly.
abstract final class InkColors {
  static const base = Color(0xFF0A0B0D);
  static const raised = Color(0xFF101216);
  static const card = Color(0xFF16181C);
  static const cardHigh = Color(0xFF1D2025);
  static const line = Color(0x1FFFFFFF);
  static const lineStrong = Color(0x33FFFFFF);
  static const text = Color(0xFFF3F1EC);
  static const textDim = Color(0xFFA2A4A8);
  static const textFaint = Color(0xFF71747A);
}

abstract final class Paper {
  static const base = Color(0xFFF6F3EC);
  static const raised = Color(0xFFFFFFFF);
  static const card = Color(0xFFFFFFFF);
  static const cardHigh = Color(0xFFEFEAE0);
  static const line = Color(0x14000000);
  static const lineStrong = Color(0x29000000);
  static const text = Color(0xFF16181B);
  static const textDim = Color(0xFF5D6066);
  static const textFaint = Color(0xFF8A8D92);
}

/// A named accent the listener can pick.
@immutable
class Accent {
  const Accent(this.id, this.name, this.color, {this.deep});

  final String id;
  final String name;
  final Color color;

  /// A darker partner used for gradients and pressed states. Derived when
  /// empty.
  final Color? deep;

  Color get deepColor => deep ?? _darken(color, 0.28);

  bool get usesInkText => color.computeLuminance() > 0.55;

  static Color _darken(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.08, 1.0))
        .toColor();
  }
}

/// The eight built-in accents. Order matters: it is the order shown in the
/// customiser and the order of the quick swatches.
const accents = <Accent>[
  Accent('ember', 'Ember', Color(0xFFE0562D)),
  Accent('marigold', 'Marigold', Color(0xFFE3A13C)),
  Accent('moss', 'Moss', Color(0xFF6E8F5B)),
  Accent('lagoon', 'Lagoon', Color(0xFF2B8C8C)),
  Accent('cobalt', 'Cobalt', Color(0xFF3D63DB)),
  Accent('iris', 'Iris', Color(0xFF7A5AD8)),
  Accent('rose', 'Rose', Color(0xFFD34C6D)),
  Accent('sand', 'Sand', Color(0xFFC2A878)),
];

const defaultAccentId = 'ember';

Accent accentById(String? id) {
  for (final a in accents) {
    if (a.id == id) return a;
  }
  return accents.first;
}

/// Spacing scale, 4pt based.
abstract final class Space {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;

  /// Standard horizontal page inset.
  static const page = 20.0;

  /// Space reserved at the bottom of a pushed page. It clears the system
  /// navigation bar and leaves a small gap below the last row.
  static const bottomClear = 96.0;

  /// Space reserved at the bottom of the four tab pages. The floating mini
  /// player and tab bar sit 188 logical pixels above the bottom edge, so this
  /// leaves a small gap instead of letting the last row slide underneath.
  static const shellClear = 200.0;
}

abstract final class Radii {
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const xl = 28.0;
  static const xxl = 36.0;
  static const pill = 999.0;
}

abstract final class Motion {
  static const fast = Duration(milliseconds: 140);
  static const base = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 340);
  static const page = Duration(milliseconds: 420);

  static const curve = Curves.easeOutCubic;
  static const emphasis = Cubic(0.2, 0, 0, 1);
  static const spring = Curves.easeOutBack;
}
