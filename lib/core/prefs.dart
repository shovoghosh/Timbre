import 'package:shared_preferences/shared_preferences.dart';

/// Thin, synchronous wrapper around [SharedPreferences].
///
/// Values are cached in memory after [init], so reading settings during a
/// build is cheap and never blocks a frame.
abstract final class Prefs {
  static SharedPreferences? _p;

  static Future<void> init() async {
    _p ??= await SharedPreferences.getInstance();
  }

  static SharedPreferences get _prefs {
    final p = _p;
    if (p == null) {
      throw StateError('Prefs.init() must run before reading settings');
    }
    return p;
  }

  static String? getString(String key) => _prefs.getString(key);
  static bool getBool(String key, {bool fallback = false}) =>
      _prefs.getBool(key) ?? fallback;
  static int getInt(String key, {int fallback = 0}) =>
      _prefs.getInt(key) ?? fallback;
  static double getDouble(String key, {double fallback = 0}) =>
      _prefs.getDouble(key) ?? fallback;
  static List<String> getStringList(String key) =>
      _prefs.getStringList(key) ?? const [];

  static Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);
  static Future<void> setBool(String key, bool value) =>
      _prefs.setBool(key, value);
  static Future<void> setInt(String key, int value) =>
      _prefs.setInt(key, value);
  static Future<void> setDouble(String key, double value) =>
      _prefs.setDouble(key, value);
  static Future<void> setStringList(String key, List<String> value) =>
      _prefs.setStringList(key, value);
  static Future<void> remove(String key) => _prefs.remove(key);

  static Set<String> keys() => _prefs.getKeys();

  static Future<void> clearAll() => _prefs.clear();
}
