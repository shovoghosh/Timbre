import 'dart:math' as math;

import '../models/play_event.dart';
import '../models/track.dart';

/// A day's listening, used by the weekly chart.
class DayTotal {
  const DayTotal({
    required this.day,
    required this.milliseconds,
    required this.plays,
  });

  final DateTime day;
  final int milliseconds;
  final int plays;

  double get minutes => milliseconds / 60000;
}

class TopEntry {
  const TopEntry({
    required this.name,
    this.subtitle = '',
    required this.milliseconds,
    required this.plays,
    this.trackId,
  });

  final String name;
  final String subtitle;
  final int milliseconds;
  final int plays;
  final String? trackId;

  String get minutesLabel => '${(milliseconds / 60000).round()} min';
}

class GenreTotal {
  const GenreTotal(this.name, this.milliseconds, this.share);

  final String name;
  final int milliseconds;
  final double share;
}

class HourTotal {
  const HourTotal(this.hour, this.milliseconds);

  final int hour;
  final int milliseconds;

  double get minutes => milliseconds / 60000;
}

/// Everything Home and the stats page need, computed once per change.
class StatsSnapshot {
  const StatsSnapshot({
    required this.todayMs,
    required this.weekMs,
    required this.previousWeekMs,
    required this.allTimeMs,
    required this.todayPlays,
    required this.weekPlays,
    required this.days,
    required this.artists,
    required this.albums,
    required this.tracks,
    required this.hours,
    required this.genres,
    required this.longestSessionMs,
    required this.streakDays,
    required this.goalMs,
    required this.exploredTracks,
    required this.librarySize,
    required this.totalPlays,
    required this.favouriteShare,
  });

  final int todayMs;
  final int weekMs;
  final int previousWeekMs;
  final int allTimeMs;
  final int todayPlays;
  final int weekPlays;
  final List<DayTotal> days;
  final List<TopEntry> artists;
  final List<TopEntry> albums;
  final List<TopEntry> tracks;
  final List<HourTotal> hours;
  final List<GenreTotal> genres;
  final int longestSessionMs;
  final int streakDays;
  final int goalMs;
  final int exploredTracks;
  final int librarySize;
  final int totalPlays;
  final double favouriteShare;

  double get goalProgress =>
      goalMs <= 0 ? 0 : (todayMs / goalMs).clamp(0.0, 1.0);

  bool get goalMet => todayMs >= goalMs && goalMs > 0;

  int get weekMinutes => (weekMs / 60000).round();

  int get changePercent {
    if (previousWeekMs <= 0) return weekMs > 0 ? 100 : 0;
    return ((weekMs - previousWeekMs) / previousWeekMs * 100).round();
  }

  double get exploredShare =>
      librarySize <= 0 ? 0 : (exploredTracks / librarySize).clamp(0.0, 1.0);

  TopEntry? get topArtist => artists.isEmpty ? null : artists.first;
  TopEntry? get topAlbum => albums.isEmpty ? null : albums.first;
  TopEntry? get topTrack => tracks.isEmpty ? null : tracks.first;

  double get peakHour => hours.isEmpty
      ? 0
      : hours.reduce((a, b) => a.milliseconds >= b.milliseconds ? a : b).hour
            .toDouble();

  DayTotal? get bestDay {
    if (days.isEmpty) return null;
    return days.reduce((a, b) => a.milliseconds >= b.milliseconds ? a : b);
  }

  static const empty = StatsSnapshot(
    todayMs: 0,
    weekMs: 0,
    previousWeekMs: 0,
    allTimeMs: 0,
    todayPlays: 0,
    weekPlays: 0,
    days: [],
    artists: [],
    albums: [],
    tracks: [],
    hours: [],
    genres: [],
    longestSessionMs: 0,
    streakDays: 0,
    goalMs: 30 * 60000,
    exploredTracks: 0,
    librarySize: 0,
    totalPlays: 0,
    favouriteShare: 0,
  );
}

/// A generated list of songs for a moment, not a stored playlist.
class Mix {
  const Mix({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.tracks,
    required this.kind,
  });

  final String id;
  final String title;
  final String subtitle;
  final List<Track> tracks;
  final String kind;
}

int _dayKey(DateTime date) =>
    DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;

DateTime _startOfDay(DateTime date) =>
    DateTime(date.year, date.month, date.day);

StatsSnapshot computeStats({
  required List<PlayEvent> events,
  required List<Track> library,
  required int goalMinutes,
  required Set<String> favouriteIds,
  DateTime? now,
}) {
  final today = _startOfDay(now ?? DateTime.now());
  final todayKey = _dayKey(today);
  final weekStart = today.subtract(const Duration(days: 6));
  final prevWeekStart = today.subtract(const Duration(days: 13));
  final goalMs = math.max(1, goalMinutes) * 60000;

  var todayMs = 0;
  var weekMs = 0;
  var prevWeekMs = 0;
  var allMs = 0;
  var todayPlays = 0;
  var weekPlays = 0;
  var totalPlays = 0;

  final dayMs = <int, int>{};
  final dayPlays = <int, int>{};
  final artistMs = <String, int>{};
  final artistPlays = <String, int>{};
  final albumMs = <String, int>{};
  final albumPlays = <String, int>{};
  final trackMs = <String, int>{};
  final trackPlays = <String, int>{};
  final trackMeta = <String, PlayEvent>{};
  final hourMs = List<int>.filled(24, 0);
  final genreMs = <String, int>{};
  final explored = <String>{};

  for (final event in events) {
    final started = DateTime.fromMillisecondsSinceEpoch(event.startedAt);
    final key = _dayKey(started);
    final listened = math.max(0, event.listenedMs);
    allMs += listened;
    totalPlays += 1;
    explored.add(event.trackId);
    dayMs[key] = (dayMs[key] ?? 0) + listened;
    dayPlays[key] = (dayPlays[key] ?? 0) + 1;
    hourMs[started.hour] += listened;
    genreMs[event.displayGenre] = (genreMs[event.displayGenre] ?? 0) + listened;

    if (key == todayKey) {
      todayMs += listened;
      todayPlays += 1;
    }
    if (key >= _dayKey(weekStart)) {
      weekMs += listened;
      weekPlays += 1;
      artistMs[event.artist] = (artistMs[event.artist] ?? 0) + listened;
      artistPlays[event.artist] = (artistPlays[event.artist] ?? 0) + 1;
      albumMs[event.album] = (albumMs[event.album] ?? 0) + listened;
      albumPlays[event.album] = (albumPlays[event.album] ?? 0) + 1;
      trackMs[event.trackId] = (trackMs[event.trackId] ?? 0) + listened;
      trackPlays[event.trackId] = (trackPlays[event.trackId] ?? 0) + 1;
      trackMeta.putIfAbsent(event.trackId, () => event);
    }
    if (key >= _dayKey(prevWeekStart) && key < _dayKey(weekStart)) {
      prevWeekMs += listened;
    }
  }

  final days = <DayTotal>[];
  for (var i = 6; i >= 0; i--) {
    final day = today.subtract(Duration(days: i));
    final key = _dayKey(day);
    days.add(
      DayTotal(
        day: day,
        milliseconds: dayMs[key] ?? 0,
        plays: dayPlays[key] ?? 0,
      ),
    );
  }

  List<TopEntry> top(Map<String, int> ms, Map<String, int> plays) {
    final entries = ms.entries
        .map(
          (entry) => TopEntry(
            name: entry.key,
            milliseconds: entry.value,
            plays: plays[entry.key] ?? 0,
          ),
        )
        .toList()
      ..sort((a, b) => b.milliseconds.compareTo(a.milliseconds));
    return entries.take(5).toList();
  }

  final trackEntries = trackMs.entries.map((entry) {
    final meta = trackMeta[entry.key];
    return TopEntry(
      name: meta?.title ?? 'Unknown',
      subtitle: meta?.artist ?? '',
      milliseconds: entry.value,
      plays: trackPlays[entry.key] ?? 0,
      trackId: entry.key,
    );
  }).toList()
    ..sort((a, b) => b.milliseconds.compareTo(a.milliseconds));

  var genreTotal = 0;
  for (final value in genreMs.values) {
    genreTotal += value;
  }
  final genres = genreMs.entries
      .map(
        (entry) => GenreTotal(
          entry.key,
          entry.value,
          genreTotal <= 0 ? 0 : entry.value / genreTotal,
        ),
      )
      .toList()
    ..sort((a, b) => b.milliseconds.compareTo(a.milliseconds));

  // Longest stretch of listening, allowing 30 minute gaps.
  var longest = 0;
  final ordered = [...events]
    ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
  var sessionMs = 0;
  var lastEnd = 0;
  for (final event in ordered) {
    final end = event.startedAt + event.listenedMs;
    if (lastEnd > 0 && event.startedAt - lastEnd > 30 * 60000) {
      longest = math.max(longest, sessionMs);
      sessionMs = 0;
    }
    sessionMs += event.listenedMs;
    lastEnd = math.max(lastEnd, end);
  }
  longest = math.max(longest, sessionMs);

  // Streak counts back from today, or yesterday when today is still open.
  var streak = 0;
  var cursor = today;
  if ((dayMs[_dayKey(cursor)] ?? 0) < goalMs) {
    cursor = cursor.subtract(const Duration(days: 1));
  }
  while ((dayMs[_dayKey(cursor)] ?? 0) >= goalMs) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }

  final libraryIds = library.map((track) => track.id).toSet();
  final exploredCount = explored.intersection(libraryIds).length;
  final favouriteExplored = explored.intersection(favouriteIds).length;

  return StatsSnapshot(
    todayMs: todayMs,
    weekMs: weekMs,
    previousWeekMs: prevWeekMs,
    allTimeMs: allMs,
    todayPlays: todayPlays,
    weekPlays: weekPlays,
    days: days,
    artists: top(artistMs, artistPlays),
    albums: top(albumMs, albumPlays),
    tracks: trackEntries.take(5).toList(),
    hours: [
      for (var hour = 0; hour < 24; hour++) HourTotal(hour, hourMs[hour]),
    ],
    genres: genres.take(5).toList(),
    longestSessionMs: longest,
    streakDays: streak,
    goalMs: goalMs,
    exploredTracks: exploredCount,
    librarySize: library.length,
    totalPlays: totalPlays,
    favouriteShare: favouriteIds.isEmpty
        ? 0
        : favouriteExplored / favouriteIds.length,
  );
}

extension on PlayEvent {
  String get displayGenre => genre.trim().isEmpty ? 'Unknown' : genre;
}

/// Builds the four mixes on Home from plays, ratings and favorites.
List<Mix> buildMixes({
  required List<PlayEvent> events,
  required List<Track> library,
  required Set<String> favouriteIds,
  required Map<String, int> ratings,
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  final monthAgo = at.subtract(const Duration(days: 30)).millisecondsSinceEpoch;
  final byId = {for (final track in library) track.id: track};
  final recentMs = <String, int>{};
  final recentPlays = <String, int>{};
  final lastPlayed = <String, int>{};
  for (final event in events) {
    lastPlayed[event.trackId] = math.max(
      lastPlayed[event.trackId] ?? 0,
      event.startedAt,
    );
    if (event.startedAt >= monthAgo) {
      recentMs[event.trackId] = (recentMs[event.trackId] ?? 0) + event.listenedMs;
      recentPlays[event.trackId] = (recentPlays[event.trackId] ?? 0) + 1;
    }
  }

  final mixes = <Mix>[];

  final repeat = recentPlays.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final repeatTracks = repeat
      .map((entry) => byId[entry.key])
      .whereType<Track>()
      .take(30)
      .toList();
  if (repeatTracks.length >= 3) {
    mixes.add(
      Mix(
        id: 'repeat',
        title: 'On repeat',
        subtitle: 'What you keep coming back to',
        tracks: repeatTracks,
        kind: 'repeat',
      ),
    );
  }

  final forgotten = library.where((track) {
    final loved =
        favouriteIds.contains(track.id) || (ratings[track.id] ?? 0) >= 4;
    if (!loved) return false;
    final last = lastPlayed[track.id] ?? 0;
    return last == 0 || last < monthAgo;
  }).take(30).toList();
  if (forgotten.isNotEmpty) {
    mixes.add(
      Mix(
        id: 'forgotten',
        title: 'Worth another listen',
        subtitle: 'Loved, but quiet lately',
        tracks: forgotten,
        kind: 'forgotten',
      ),
    );
  }

  final fresh = library
      .where(
        (track) =>
            track.addedAt >= monthAgo && (lastPlayed[track.id] ?? 0) == 0,
      )
      .take(30)
      .toList();
  if (fresh.isNotEmpty) {
    mixes.add(
      Mix(
        id: 'fresh',
        title: 'Fresh finds',
        subtitle: 'New here, not played yet',
        tracks: fresh,
        kind: 'fresh',
      ),
    );
  }

  final topArtists = <String, int>{};
  recentMs.forEach((trackId, ms) {
    final track = byId[trackId];
    if (track == null) return;
    topArtists[track.displayArtist] =
        (topArtists[track.displayArtist] ?? 0) + ms;
  });
  final favourites = topArtists.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final deep = <Track>[];
  for (final artist in favourites.take(4)) {
    final songs = library
        .where((track) => track.displayArtist == artist.key)
        .toList()
      ..sort(
        (a, b) => (recentMs[a.id] ?? 0).compareTo(recentMs[b.id] ?? 0),
      );
    deep.addAll(songs.take(4));
  }
  if (deep.length >= 4) {
    mixes.add(
      Mix(
        id: 'deep',
        title: 'Deep cuts',
        subtitle: 'Less played songs by your favourites',
        tracks: deep.take(30).toList(),
        kind: 'deep',
      ),
    );
  }

  return mixes;
}

/// The Sunday story: numbers worth sharing.
class WeeklyRecap {
  const WeeklyRecap({
    required this.weekStart,
    required this.minutes,
    required this.plays,
    required this.topArtist,
    required this.topAlbum,
    required this.topTrack,
    required this.peakHour,
    required this.changePercent,
    required this.daysActive,
  });

  final DateTime weekStart;
  final int minutes;
  final int plays;
  final TopEntry? topArtist;
  final TopEntry? topAlbum;
  final TopEntry? topTrack;
  final int peakHour;
  final int changePercent;
  final int daysActive;

  bool get isEmpty => minutes == 0 && plays == 0;

  String get peakLabel {
    final hour = peakHour % 24;
    final suffix = hour < 12 ? 'am' : 'pm';
    final shown = hour % 12 == 0 ? 12 : hour % 12;
    return '$shown$suffix';
  }

  static WeeklyRecap from(StatsSnapshot stats) {
    final daysActive = stats.days.where((day) => day.milliseconds > 0).length;
    return WeeklyRecap(
      weekStart: stats.days.isEmpty
          ? DateTime.now()
          : stats.days.first.day,
      minutes: stats.weekMinutes,
      plays: stats.weekPlays,
      topArtist: stats.topArtist,
      topAlbum: stats.topAlbum,
      topTrack: stats.topTrack,
      peakHour: stats.peakHour.round(),
      changePercent: stats.changePercent,
      daysActive: daysActive,
    );
  }
}
