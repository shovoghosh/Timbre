import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/haptics.dart';
import 'core/services.dart';
import 'theme/theme_controller.dart';
import 'ui/pages/onboarding_page.dart';
import 'ui/shell/app_shell.dart';

/// Root of the app. Rebuilds when the theme changes and keeps system bars in
/// step with the canvas.
class TimbreApp extends StatelessWidget {
  const TimbreApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeController theme = Services.i.theme;
    return AnimatedBuilder(
      animation: theme,
      builder: (context, _) {
        Haptics.enabled = theme.haptics;
        final systemBrightness =
            WidgetsBinding.instance.platformDispatcher.platformBrightness;
        final isDark = switch (theme.mode) {
          ThemeMode.dark => true,
          ThemeMode.light => false,
          ThemeMode.system => systemBrightness == Brightness.dark,
        };
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarContrastEnforced: false,
            systemNavigationBarDividerColor: Colors.transparent,
          ),
          child: MaterialApp(
            title: 'Timbre',
            debugShowCheckedModeBanner: false,
            theme: theme.light,
            darkTheme: theme.dark,
            themeMode: theme.mode,
            themeAnimationDuration: const Duration(milliseconds: 280),
            themeAnimationCurve: Curves.easeOutCubic,
            builder: (context, child) {
              final media = MediaQuery.maybeOf(context);
              if (media == null) return child ?? const SizedBox.shrink();
              return MediaQuery(
                data: media.copyWith(
                  textScaler: media.textScaler.clamp(
                    minScaleFactor: 1,
                    maxScaleFactor: 1.25,
                  ),
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: Services.i.settings.onboarded
                ? const AppShell()
                : const OnboardingPage(),
          ),
        );
      },
    );
  }
}
