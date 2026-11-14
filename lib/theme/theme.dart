import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'tokens.dart';
import 'type.dart';

/// Builds the full Material theme for one brightness and accent.
ThemeData buildTimbreTheme({
  required Brightness brightness,
  required Color accent,
  required Color onAccent,
  bool amoled = false,
  bool glass = true,
}) {
  final dark = brightness == Brightness.dark;
  final canvas = dark ? (amoled ? const Color(0xFF000000) : InkColors.base) : Paper.base;
  final surface = dark ? InkColors.card : Paper.card;
  final surfaceHigh = dark ? InkColors.cardHigh : Paper.cardHigh;
  final text = dark ? InkColors.text : Paper.text;
  final textDim = dark ? InkColors.textDim : Paper.textDim;
  final textFaint = dark ? InkColors.textFaint : Paper.textFaint;
  final line = dark ? InkColors.line : Paper.line;
  final lineStrong = dark ? InkColors.lineStrong : Paper.lineStrong;

  final scheme = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: brightness,
  ).copyWith(
    primary: accent,
    onPrimary: onAccent,
    primaryContainer: accent.withValues(alpha: 0.18),
    onPrimaryContainer: text,
    secondary: accent,
    onSecondary: onAccent,
    secondaryContainer: accent.withValues(alpha: 0.14),
    onSecondaryContainer: text,
    surface: canvas,
    onSurface: text,
    surfaceContainerLowest: canvas,
    surfaceContainerLow: surface,
    surfaceContainer: surface,
    surfaceContainerHigh: surfaceHigh,
    surfaceContainerHighest: surfaceHigh,
    outline: lineStrong,
    outlineVariant: line,
    onSurfaceVariant: textDim,
    error: const Color(0xFFD1453B),
    onError: Colors.white,
    shadow: Colors.black,
  );

  final textTheme = TextTheme(
    displayLarge: T.serif(size: 46, color: text),
    displayMedium: T.serif(size: 38, color: text),
    displaySmall: T.serif(size: 31, color: text),
    headlineLarge: T.serif(size: 27, color: text, spacing: -0.2),
    headlineMedium: T.serif(size: 23, color: text, spacing: -0.2),
    headlineSmall: T.sans(size: 19, weight: 600, color: text),
    titleLarge: T.sans(size: 17, weight: 600, color: text),
    titleMedium: T.sans(size: 15, weight: 600, color: text),
    titleSmall: T.sans(size: 13, weight: 600, color: text),
    bodyLarge: T.sans(size: 16, color: text, height: 1.45),
    bodyMedium: T.sans(size: 14, color: text, height: 1.45),
    bodySmall: T.sans(size: 12, color: textDim, height: 1.4),
    labelLarge: T.sans(size: 14, weight: 600, color: text),
    labelMedium: T.sans(size: 12, weight: 600, color: textDim),
    labelSmall: T.sans(size: 11, weight: 600, color: textFaint),
  );

  final colors = TimbreColors(
    canvas: canvas,
    surface: surface,
    surfaceHigh: surfaceHigh,
    line: line,
    lineStrong: lineStrong,
    text: text,
    textDim: textDim,
    textFaint: textFaint,
    accent: accent,
    onAccent: onAccent,
    isDark: dark,
    isAmoled: amoled,
    glass: glass,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: canvas,
    canvasColor: canvas,
    dividerColor: line,
    fontFamily: Fonts.sans,
    textTheme: textTheme,
    extensions: <ThemeExtension<dynamic>>[colors],
    splashFactory: InkRipple.splashFactory,
    highlightColor: accent.withValues(alpha: 0.06),
    hoverColor: accent.withValues(alpha: 0.04),
    splashColor: accent.withValues(alpha: 0.10),
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    appBarTheme: AppBarTheme(
      backgroundColor: canvas,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: text,
      centerTitle: false,
      titleTextStyle: T.sans(size: 16, weight: 600, color: text),
      iconTheme: IconThemeData(color: text, size: 22),
    ),
    iconTheme: IconThemeData(color: text, size: 22),
    dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
    listTileTheme: ListTileThemeData(
      iconColor: textDim,
      textColor: text,
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.page),
      titleTextStyle: T.sans(size: 15, weight: 500, color: text),
      subtitleTextStyle: T.sans(size: 12.5, color: textDim),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      modalBackgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      modalElevation: 0,
      dragHandleColor: lineStrong,
      dragHandleSize: const Size(38, 4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.xl),
        side: BorderSide(color: line),
      ),
      titleTextStyle: T.serif(size: 24, color: text),
      contentTextStyle: T.sans(size: 15, color: textDim, height: 1.5),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      backgroundColor: dark ? Paper.raised : InkColors.raised,
      contentTextStyle: T.sans(
        size: 14,
        weight: 500,
        color: dark ? Paper.text : InkColors.text,
      ),
      actionTextColor: accent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: surfaceHigh,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
        side: BorderSide(color: line),
      ),
      textStyle: T.sans(size: 14, color: text),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: accent,
      inactiveTrackColor: line,
      thumbColor: accent,
      overlayColor: accent.withValues(alpha: 0.12),
      trackHeight: 3,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
      valueIndicatorColor: accent,
      valueIndicatorTextStyle: T.sans(
        size: 12,
        weight: 600,
        color: onAccent,
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return onAccent;
        return dark ? InkColors.textDim : Colors.white;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return accent;
        return lineStrong;
      }),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: accent,
      linearTrackColor: line,
      circularTrackColor: line,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: accent,
      selectionColor: accent.withValues(alpha: 0.28),
      selectionHandleColor: accent,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: surfaceHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: line),
      ),
      textStyle: T.sans(size: 12, color: text),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: SoftPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: SoftPageTransitionsBuilder(),
        TargetPlatform.windows: SoftPageTransitionsBuilder(),
      },
    ),
  );
}

/// A quiet fade and rise, so page changes never feel like a slide deck.
class SoftPageTransitionsBuilder extends PageTransitionsBuilder {
  const SoftPageTransitionsBuilder();

  @override
  Widget buildTransitions<R>(
    PageRoute<R> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Motion.emphasis,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.018),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
