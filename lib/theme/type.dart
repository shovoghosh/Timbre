import 'package:flutter/material.dart';

/// Type system.
///
/// Two families: Instrument Serif for editorial display text, Instrument Sans
/// for everything functional. The sans is a variable font, so weight is set
/// through the `wght` axis and mirrored on [FontWeight] for fallback.
abstract final class Fonts {
  static const serif = 'InstrumentSerif';
  static const sans = 'InstrumentSans';
}

abstract final class T {
  static FontWeight _weight(int w) {
    final i = (w / 100).round().clamp(1, 9) - 1;
    return FontWeight.values[i];
  }

  static TextStyle sans({
    double size = 15,
    int weight = 400,
    double height = 1.4,
    double? spacing,
    FontStyle? style,
    Color? color,
    TextDecoration? decoration,
  }) {
    return TextStyle(
      fontFamily: Fonts.sans,
      fontSize: size,
      height: height,
      letterSpacing: spacing,
      fontStyle: style,
      color: color,
      decoration: decoration,
      fontWeight: _weight(weight),
      fontVariations: [
        FontVariation('wght', weight.toDouble()),
        const FontVariation('wdth', 100),
      ],
    );
  }

  /// Tight, tracked numerals for clocks and counters.
  static TextStyle numeric({
    double size = 13,
    int weight = 500,
    Color? color,
    double? spacing,
  }) {
    return sans(
      size: size,
      weight: weight,
      color: color,
      spacing: spacing,
      height: 1.1,
    ).copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  static TextStyle serif({
    double size = 32,
    double height = 1.06,
    double spacing = -0.4,
    Color? color,
    FontStyle? style,
  }) {
    return TextStyle(
      fontFamily: Fonts.serif,
      fontSize: size,
      height: height,
      letterSpacing: spacing,
      fontStyle: style,
      color: color,
      fontWeight: FontWeight.w400,
    );
  }

  static TextStyle overline({Color? color, double spacing = 1.4}) {
    return sans(
      size: 11,
      weight: 600,
      height: 1.2,
      spacing: spacing,
      color: color,
    );
  }

  static TextStyle label({Color? color, double size = 12, int weight = 600}) {
    return sans(size: size, weight: weight, height: 1.2, color: color);
  }
}

/// Convenience access to theme colors and type on a [BuildContext].
extension TimbreThemeX on BuildContext {
  TimbreColors get c => Theme.of(this).extension<TimbreColors>()!;

  /// Functional sans text, inheriting the theme's primary text color.
  TextStyle sans({
    double size = 15,
    int weight = 400,
    double height = 1.4,
    double? spacing,
    FontStyle? style,
    Color? color,
    TextDecoration? decoration,
  }) {
    return T.sans(
      size: size,
      weight: weight,
      height: height,
      spacing: spacing,
      style: style,
      color: color ?? c.text,
      decoration: decoration,
    );
  }

  /// Editorial serif text.
  TextStyle serif({
    double size = 32,
    double height = 1.06,
    double spacing = -0.4,
    Color? color,
    FontStyle? style,
  }) {
    return T.serif(
      size: size,
      height: height,
      spacing: spacing,
      color: color ?? c.text,
      style: style,
    );
  }

  TextStyle numeric({
    double size = 13,
    int weight = 500,
    Color? color,
    double? spacing,
  }) {
    return T.numeric(
      size: size,
      weight: weight,
      color: color ?? c.textDim,
      spacing: spacing,
    );
  }

  TextStyle overline({Color? color, double spacing = 1.4}) =>
      T.overline(color: color ?? c.textFaint, spacing: spacing);

  TextStyle label({Color? color, double size = 12, int weight = 600}) =>
      T.label(color: color ?? c.textDim, size: size, weight: weight);
}

/// Extra semantic colors that [ColorScheme] does not carry.
@immutable
class TimbreColors extends ThemeExtension<TimbreColors> {
  const TimbreColors({
    required this.canvas,
    required this.surface,
    required this.surfaceHigh,
    required this.line,
    required this.lineStrong,
    required this.text,
    required this.textDim,
    required this.textFaint,
    required this.accent,
    required this.onAccent,
    required this.isDark,
    required this.isAmoled,
    required this.glass,
  });

  final Color canvas;
  final Color surface;
  final Color surfaceHigh;
  final Color line;
  final Color lineStrong;
  final Color text;
  final Color textDim;
  final Color textFaint;
  final Color accent;
  final Color onAccent;
  final bool isDark;
  final bool isAmoled;
  final bool glass;

  Color get accentSoft => accent.withValues(alpha: isDark ? 0.16 : 0.12);

  Color get accentLine => accent.withValues(alpha: isDark ? 0.34 : 0.26);

  LinearGradient get accentWash => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent.withValues(alpha: 0.20), accent.withValues(alpha: 0.0)],
  );

  LinearGradient get accentFill => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, Color.lerp(accent, onAccent, 0.18)!],
  );

  @override
  TimbreColors copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceHigh,
    Color? line,
    Color? lineStrong,
    Color? text,
    Color? textDim,
    Color? textFaint,
    Color? accent,
    Color? onAccent,
    bool? isDark,
    bool? isAmoled,
    bool? glass,
  }) {
    return TimbreColors(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      line: line ?? this.line,
      lineStrong: lineStrong ?? this.lineStrong,
      text: text ?? this.text,
      textDim: textDim ?? this.textDim,
      textFaint: textFaint ?? this.textFaint,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      isDark: isDark ?? this.isDark,
      isAmoled: isAmoled ?? this.isAmoled,
      glass: glass ?? this.glass,
    );
  }

  @override
  TimbreColors lerp(TimbreColors? other, double t) {
    if (other == null) return this;
    return TimbreColors(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      line: Color.lerp(line, other.line, t)!,
      lineStrong: Color.lerp(lineStrong, other.lineStrong, t)!,
      text: Color.lerp(text, other.text, t)!,
      textDim: Color.lerp(textDim, other.textDim, t)!,
      textFaint: Color.lerp(textFaint, other.textFaint, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      isDark: t < 0.5 ? isDark : other.isDark,
      isAmoled: t < 0.5 ? isAmoled : other.isAmoled,
      glass: t < 0.5 ? glass : other.glass,
    );
  }
}
