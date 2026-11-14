import 'dart:async';

import 'package:flutter/foundation.dart';

import '../library/library_controller.dart';
import '../library/saved_store.dart';
import '../models/play_event.dart';
import '../settings/app_settings.dart';
import 'history_store.dart';
import 'stats.dart';

/// Keeps one up-to-date picture of listening habits and the generated mixes.
///
/// Recomputes are debounced, so a song that updates its played time every few
/// seconds never stalls the UI.
class StatsController extends ChangeNotifier {
  StatsController({
    required this.history,
    required this.library,
    required this.favorites,
    required this.ratings,
    required this.settings,
  }) {
    history.addListener(_schedule);
    library.addListener(_schedule);
    favorites.addListener(_schedule);
    ratings.addListener(_schedule);
    settings.addListener(_schedule);
  }

  final HistoryStore history;
  final LibraryController library;
  final FavoritesStore favorites;
  final RatingsStore ratings;
  final AppSettings settings;

  StatsSnapshot _stats = StatsSnapshot.empty;
  List<Mix> _mixes = const [];
  WeeklyRecap _recap = WeeklyRecap.from(StatsSnapshot.empty);
  bool _loading = true;
  bool _dirty = false;
  bool _computing = false;
  List<PlayEvent> _events = const [];
  Timer? _debounce;

  StatsSnapshot get stats => _stats;
  List<Mix> get mixes => _mixes;
  WeeklyRecap get recap => _recap;
  bool get loading => _loading;

  /// Recent plays, newest first, for the "continue listening" card.
  List<PlayEvent> get recentPlays =>
      _events.take(12).toList(growable: false);

  Future<void> load({bool silent = false}) async {
    if (_computing) {
      _dirty = true;
      return;
    }
    _computing = true;
    try {
      _events = await history.all(limit: 20000);
      _stats = computeStats(
        events: _events,
        library: library.tracks,
        goalMinutes: settings.dailyGoalMinutes,
        favouriteIds: favorites.ids,
      );
      _mixes = buildMixes(
        events: _events,
        library: library.tracks,
        favouriteIds: favorites.ids,
        ratings: ratings.all,
      );
      _recap = WeeklyRecap.from(_stats);
      _loading = false;
      if (!silent) notifyListeners();
    } finally {
      _computing = false;
      if (_dirty) {
        _dirty = false;
        unawaited(load(silent: true));
      }
    }
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1200), () => load());
  }

  TrackHistory? historyFor(String trackId) {
    var plays = 0;
    var ms = 0;
    var last = 0;
    for (final event in _events) {
      if (event.trackId != trackId) continue;
      plays++;
      ms += event.listenedMs;
      last = last < event.startedAt ? event.startedAt : last;
    }
    if (plays == 0) return null;
    return TrackHistory(plays: plays, milliseconds: ms, lastPlayed: last);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    history.removeListener(_schedule);
    library.removeListener(_schedule);
    favorites.removeListener(_schedule);
    ratings.removeListener(_schedule);
    settings.removeListener(_schedule);
    super.dispose();
  }
}

class TrackHistory {
  const TrackHistory({
    required this.plays,
    required this.milliseconds,
    required this.lastPlayed,
  });

  final int plays;
  final int milliseconds;
  final int lastPlayed;
}
