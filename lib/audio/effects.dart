import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/prefs.dart';

/// Platform equalizer support. Present on Android, absent on iOS where the
/// system offers no per-app equalizer.
class EqualizerBand {
  const EqualizerBand(this.frequencyHz, this.levelMb);

  final int frequencyHz;
  final int levelMb;

  String get label =>
      frequencyHz >= 1000 ? '${frequencyHz ~/ 1000}k' : '$frequencyHz';
}

class EqualizerInfo {
  const EqualizerInfo({
    this.supported = false,
    this.bands = const [],
    this.presets = const [],
    this.minLevel = -1500,
    this.maxLevel = 1500,
    this.bandLevels = const [],
    this.hasBassBoost = false,
    this.bassStrength = 0,
    this.enabled = false,
    this.sessionId = 0,
  });

  final bool supported;
  final List<int> bands;
  final List<String> presets;
  final int minLevel;
  final int maxLevel;
  final List<int> bandLevels;
  final bool hasBassBoost;
  final int bassStrength;
  final bool enabled;
  final int sessionId;

  factory EqualizerInfo.fromMap(Map<Object?, Object?> map) {
    List<int> ints(Object? value) =>
        value is List ? value.map((e) => (e as num).toInt()).toList() : const [];
    List<String> strings(Object? value) =>
        value is List ? value.map((e) => '$e').toList() : const [];
    return EqualizerInfo(
      supported: map['supported'] == true,
      bands: ints(map['bands']),
      presets: strings(map['presets']),
      minLevel: (map['minLevel'] as num?)?.toInt() ?? -1500,
      maxLevel: (map['maxLevel'] as num?)?.toInt() ?? 1500,
      bandLevels: ints(map['bandLevels']),
      hasBassBoost: map['hasBassBoost'] == true,
      bassStrength: (map['bassStrength'] as num?)?.toInt() ?? 0,
      enabled: map['enabled'] == true,
      sessionId: (map['sessionId'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Live equalizer state, mirrored to preferences so it survives a restart.
class AudioEffects extends ChangeNotifier {
  AudioEffects() {
    _levels = savedLevels();
  }

  static const _channel = MethodChannel('timbre/effects');

  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  EqualizerInfo info = const EqualizerInfo();

  bool _enabled = Prefs.getBool(_kEnabled);
  double _bass = Prefs.getDouble(_kBass, fallback: 0);
  int _preset = Prefs.getInt(_kPreset, fallback: -1);
  List<int> _levels = const [];
  int _sessionId = 0;

  bool get enabled => _enabled;
  double get bass => _bass;
  int get sessionId => _sessionId;
  int get preset => _preset;
  List<int> get levels => _levels;
  bool get hasBands => info.bands.isNotEmpty;
  bool get isFlat =>
      _levels.every((l) => l == 0) && _bass == 0 && _preset < 0;

  static const _kEnabled = 'eq.enabled';
  static const _kBass = 'eq.bass';
  static const _kPreset = 'eq.preset';
  static const _kLevels = 'eq.levels';

  Future<void> refresh() async {
    if (!isSupported) return;
    try {
      final raw = await _channel.invokeMapMethod<Object?, Object?>('info');
      if (raw != null) {
        info = EqualizerInfo.fromMap(raw);
        if (info.bandLevels.isNotEmpty) _levels = info.bandLevels;
        notifyListeners();
      }
    } on PlatformException {
      // Keep the last known state.
    }
  }

  /// Bundles the platform equalizer to a playing audio session.
  Future<void> attach(int sessionId) async {
    if (!isSupported || sessionId <= 0) return;
    _sessionId = sessionId;
    try {
      final raw = await _channel.invokeMapMethod<Object?, Object?>('attach', {
        'sessionId': sessionId,
      });
      if (raw != null) {
        info = EqualizerInfo.fromMap(raw);
        if (_levels.isEmpty) {
          _levels = info.bandLevels.isEmpty
              ? List<int>.filled(info.bands.length, 0)
              : info.bandLevels;
        }
        await _pushAll();
        notifyListeners();
      }
    } on PlatformException {
      // Device without an equalizer effect. The UI hides the bands.
    } on MissingPluginException {
      // Not on this platform.
    }
  }

  Future<void> _pushAll() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('setEnabled', {'enabled': _enabled});
      if (_levels.isNotEmpty) {
        await _channel.invokeMethod<void>('setBandLevels', {'levels': _levels});
      }
      if (info.hasBassBoost) {
        await _channel.invokeMethod<void>('setBassBoost', {
          'strength': (_bass * 1000).round(),
        });
      }
      if (_enabled && _preset >= 0) {
        await _channel.invokeMethod<void>('setPreset', {'index': _preset});
      }
    } on PlatformException {
      // Ignore one-off effect failures; the next change retries.
    }
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    await Prefs.setBool(_kEnabled, value);
    await _pushAll();
    notifyListeners();
  }

  Future<void> setBandLevel(int index, int millibels) async {
    if (index < 0 || index >= _levels.length) return;
    final next = [..._levels];
    next[index] = millibels.clamp(info.minLevel, info.maxLevel);
    _levels = next;
    _preset = -1;
    await Prefs.setString(_kLevels, next.join(','));
    await Prefs.setInt(_kPreset, -1);
    if (!isSupported) {
      notifyListeners();
      return;
    }
    try {
      await _channel.invokeMethod<void>('setBandLevels', {'levels': _levels});
    } on PlatformException {
      // Ignore.
    }
    notifyListeners();
  }

  Future<void> setPreset(int index, List<int> levels) async {
    _preset = index;
    _levels = levels.isEmpty ? _levels : levels;
    await Prefs.setInt(_kPreset, index);
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('setPreset', {'index': index});
      if (_levels.isNotEmpty) {
        await _channel.invokeMethod<void>('setBandLevels', {'levels': _levels});
      }
      await refresh();
    } on PlatformException {
      // Ignore.
    }
    notifyListeners();
  }

  Future<void> setBass(double value) async {
    _bass = value.clamp(0, 1);
    await Prefs.setDouble(_kBass, _bass);
    if (!isSupported || !info.hasBassBoost) {
      notifyListeners();
      return;
    }
    try {
      await _channel.invokeMethod<void>('setBassBoost', {
        'strength': (_bass * 1000).round(),
      });
    } on PlatformException {
      // Ignore.
    }
    notifyListeners();
  }

  Future<void> reset() async {
    _bass = 0;
    _preset = -1;
    _levels = List<int>.filled(info.bands.length, 0);
    await Prefs.setDouble(_kBass, 0);
    await Prefs.setInt(_kPreset, -1);
    await _pushAll();
    notifyListeners();
  }

  Future<bool> openSystemPanel() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('openSystemPanel') ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> release() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('release');
    } on PlatformException {
      // Ignore.
    }
    _sessionId = 0;
  }

  static void restoreLevels(List<int> levels) {
    if (levels.isEmpty) return;
    Prefs.setString(_kLevels, levels.join(','));
  }

  List<int> savedLevels() {
    final raw = Prefs.getString(_kLevels);
    if (raw == null || raw.isEmpty) return const [];
    return raw
        .split(',')
        .map((e) => int.tryParse(e) ?? 0)
        .toList();
  }
}
