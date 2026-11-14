import 'package:flutter/foundation.dart';

import '../../core/prefs.dart';

/// Playback and listening preferences that are not part of the theme.
class AppSettings extends ChangeNotifier {
  AppSettings() {
    _dailyGoal = Prefs.getInt(_kGoal, fallback: 30).clamp(5, 600);
    _pauseOnUnplug = Prefs.getBool(_kPauseUnplug, fallback: true);
    _resumeOnPlug = Prefs.getBool(_kResumePlug, fallback: false);
    _fade = Prefs.getBool(_kFade, fallback: true);
    _sleepFade = Prefs.getBool(_kSleepFade, fallback: true);
    _skipSilence = Prefs.getBool(_kSkipSilence, fallback: false);
    _hideShort = Prefs.getBool(_kHideShort, fallback: false);
    _normalizeVolume = Prefs.getBool(_kNormalize, fallback: false);
    _widgets = Prefs.getBool(_kWidgets, fallback: true);
    _onboarded = Prefs.getBool(_kOnboarded, fallback: false);
    _crossfade = Prefs.getInt(_kCrossfade, fallback: 0).clamp(0, 12);
  }

  static const _kGoal = 'listen.dailyGoal';
  static const _kPauseUnplug = 'listen.pauseOnUnplug';
  static const _kResumePlug = 'listen.resumeOnPlug';
  static const _kFade = 'listen.fade';
  static const _kSleepFade = 'listen.sleepFade';
  static const _kSkipSilence = 'listen.skipSilence';
  static const _kHideShort = 'listen.hideShort';
  static const _kNormalize = 'listen.normalize';
  static const _kWidgets = 'listen.widgets';
  static const _kOnboarded = 'app.onboarded';
  static const _kCrossfade = 'listen.crossfade';

  late int _dailyGoal;
  late bool _pauseOnUnplug;
  late bool _resumeOnPlug;
  late bool _fade;
  late bool _sleepFade;
  late bool _skipSilence;
  late bool _hideShort;
  late bool _normalizeVolume;
  late bool _widgets;
  late bool _onboarded;
  late int _crossfade;

  int get dailyGoalMinutes => _dailyGoal;
  bool get pauseOnUnplug => _pauseOnUnplug;
  bool get resumeOnPlug => _resumeOnPlug;
  bool get fade => _fade;
  bool get sleepFade => _sleepFade;
  bool get skipSilence => _skipSilence;
  bool get hideShortClips => _hideShort;
  bool get normalizeVolume => _normalizeVolume;
  bool get widgetsEnabled => _widgets;
  bool get onboarded => _onboarded;
  int get crossfadeSeconds => _crossfade;

  Future<void> setDailyGoal(int minutes) async {
    _dailyGoal = minutes.clamp(5, 600);
    notifyListeners();
    await Prefs.setInt(_kGoal, _dailyGoal);
  }

  Future<void> setPauseOnUnplug(bool value) async {
    _pauseOnUnplug = value;
    notifyListeners();
    await Prefs.setBool(_kPauseUnplug, value);
  }

  Future<void> setResumeOnPlug(bool value) async {
    _resumeOnPlug = value;
    notifyListeners();
    await Prefs.setBool(_kResumePlug, value);
  }

  Future<void> setFade(bool value) async {
    _fade = value;
    notifyListeners();
    await Prefs.setBool(_kFade, value);
  }

  Future<void> setSleepFade(bool value) async {
    _sleepFade = value;
    notifyListeners();
    await Prefs.setBool(_kSleepFade, value);
  }

  Future<void> setSkipSilence(bool value) async {
    _skipSilence = value;
    notifyListeners();
    await Prefs.setBool(_kSkipSilence, value);
  }

  Future<void> setHideShortClips(bool value) async {
    _hideShort = value;
    notifyListeners();
    await Prefs.setBool(_kHideShort, value);
  }

  Future<void> setNormalizeVolume(bool value) async {
    _normalizeVolume = value;
    notifyListeners();
    await Prefs.setBool(_kNormalize, value);
  }

  Future<void> setWidgetsEnabled(bool value) async {
    _widgets = value;
    notifyListeners();
    await Prefs.setBool(_kWidgets, value);
  }

  Future<void> setCrossfadeSeconds(int seconds) async {
    _crossfade = seconds.clamp(0, 12);
    notifyListeners();
    await Prefs.setInt(_kCrossfade, _crossfade);
  }

  Future<void> setOnboarded(bool value) async {
    _onboarded = value;
    notifyListeners();
    await Prefs.setBool(_kOnboarded, value);
  }
}
