import 'package:flutter/material.dart';

import '../core/prefs.dart';
import 'theme.dart';
import 'tokens.dart';

/// The five ways a listener can think about the theme.
enum ThemeChoice {
  system('Follow system'),
  light('Light'),
  dark('Dark'),
  black('Black');

  const ThemeChoice(this.label);
  final String label;
}

/// Owns theme settings and turns them into [ThemeData]. Persists every change.
class ThemeController extends ChangeNotifier {
  ThemeController() {
    _choice = ThemeChoice.values.firstWhere(
      (c) => c.name == Prefs.getString(_kChoice),
      orElse: () => ThemeChoice.system,
    );
    _accent = accentById(Prefs.getString(_kAccent));
    _glass = Prefs.getBool(_kGlass, fallback: true);
    _dynamic = Prefs.getBool(_kDynamic, fallback: true);
    _haptics = Prefs.getBool(_kHaptics, fallback: true);
  }

  static const _kChoice = 'theme.choice';
  static const _kAccent = 'theme.accent';
  static const _kGlass = 'theme.glass';
  static const _kDynamic = 'theme.dynamicAccent';
  static const _kHaptics = 'theme.haptics';

  late ThemeChoice _choice;
  late Accent _accent;
  late bool _glass;
  late bool _dynamic;
  late bool _haptics;

  Color? _artworkAccent;

  ThemeChoice get choice => _choice;
  Accent get accent => _accent;
  bool get glass => _glass;
  bool get dynamicAccent => _dynamic;
  bool get haptics => _haptics;

  /// Accent sampled from the current cover, when dynamic accent is on.
  Color? get artworkAccent => _artworkAccent;

  bool get followsArtwork => _dynamic && _artworkAccent != null;

  Color get activeAccent =>
      followsArtwork ? _artworkAccent! : _accent.color;

  Color get activeOnAccent =>
      activeAccent.computeLuminance() > 0.55 ? InkColors.base : Colors.white;

  ThemeMode get mode => switch (_choice) {
    ThemeChoice.system => ThemeMode.system,
    ThemeChoice.light => ThemeMode.light,
    ThemeChoice.dark || ThemeChoice.black => ThemeMode.dark,
  };

  ThemeData get light => buildTimbreTheme(
    brightness: Brightness.light,
    accent: activeAccent,
    onAccent: activeOnAccent,
    glass: _glass,
  );

  ThemeData get dark => buildTimbreTheme(
    brightness: Brightness.dark,
    accent: activeAccent,
    onAccent: activeOnAccent,
    amoled: _choice == ThemeChoice.black,
    glass: _glass,
  );

  Future<void> setChoice(ThemeChoice value) async {
    if (value == _choice) return;
    _choice = value;
    notifyListeners();
    await Prefs.setString(_kChoice, value.name);
  }

  Future<void> setAccent(Accent value) async {
    if (value.id == _accent.id && !followsArtwork) return;
    _accent = value;
    // Picking by hand means the listener wants that color.
    if (_dynamic) {
      _dynamic = false;
      await Prefs.setBool(_kDynamic, false);
    }
    notifyListeners();
    await Prefs.setString(_kAccent, value.id);
  }

  Future<void> setDynamicAccent(bool value) async {
    if (value == _dynamic) return;
    _dynamic = value;
    notifyListeners();
    await Prefs.setBool(_kDynamic, value);
  }

  Future<void> setGlass(bool value) async {
    if (value == _glass) return;
    _glass = value;
    notifyListeners();
    await Prefs.setBool(_kGlass, value);
  }

  Future<void> setHaptics(bool value) async {
    if (value == _haptics) return;
    _haptics = value;
    notifyListeners();
    await Prefs.setBool(_kHaptics, value);
  }

  /// Called by playback when the cover changes. Nothing rebuilds unless the
  /// sampled color actually moved.
  void setArtworkAccent(Color? value) {
    if (value == _artworkAccent) return;
    _artworkAccent = value;
    if (_dynamic) notifyListeners();
  }

  /// Restores defaults, used by "Reset theme" and after a backup restore.
  Future<void> reset() async {
    _choice = ThemeChoice.system;
    _accent = accentById(defaultAccentId);
    _glass = true;
    _dynamic = true;
    _haptics = true;
    _artworkAccent = null;
    notifyListeners();
    await Future.wait([
      Prefs.setString(_kChoice, _choice.name),
      Prefs.setString(_kAccent, _accent.id),
      Prefs.setBool(_kGlass, _glass),
      Prefs.setBool(_kDynamic, _dynamic),
      Prefs.setBool(_kHaptics, _haptics),
    ]);
  }
}
