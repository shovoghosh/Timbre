import 'package:flutter_test/flutter_test.dart';
import 'package:timbre/data/history/stats.dart';
import 'package:timbre/data/models/play_event.dart';
import 'package:timbre/data/models/track.dart';

Track track(String id, {String title = 'Song', String artist = 'Artist'}) {
  return Track(
    id: id,
    uri: 'file:///$id',
    path: '/music/$id.mp3',
    title: title,
    artist: artist,
    album: 'Album',
    durationMs: 240000,
    addedAt: 1000,
  );
}

PlayEvent event({
  required String trackId,
  required DateTime at,
  int minutes = 10,
  String artist = 'Artist',
  String title = 'Song',
  String genre = 'Pop',
}) {
  return PlayEvent(
    trackId: trackId,
    title: title,
    artist: artist,
    album: 'Album',
    genre: genre,
    startedAt: at.millisecondsSinceEpoch,
    listenedMs: minutes * 60000,
    completed: false,
  );
}

void main() {
  group('computeStats', () {
    final now = DateTime(2026, 11, 13, 20, 30);

    test('totals, week and previous week', () {
      final events = [
        event(trackId: 'a', at: DateTime(2026, 11, 13, 9)),
        event(trackId: 'b', at: DateTime(2026, 11, 12, 9), minutes: 5),
        event(trackId: 'c', at: DateTime(2026, 11, 1, 9), minutes: 3),
      ];
      final stats = computeStats(
        events: events,
        library: [track('a'), track('b'), track('c'), track('d')],
        goalMinutes: 30,
        favouriteIds: const {'a'},
        now: now,
      );
      expect(stats.todayMs, 10 * 60000);
      expect(stats.weekMs, 15 * 60000);
      expect(stats.weekPlays, 2);
      expect(stats.allTimeMs, 18 * 60000);
      expect(stats.exploredTracks, 3);
      expect(stats.exploredShare, closeTo(0.75, 0.001));
      expect(stats.favouriteShare, 1.0);
      expect(stats.days.length, 7);
      expect(stats.days.last.milliseconds, 10 * 60000);
    });

    test('streak counts back over consecutive goal days', () {
      final events = [
        event(trackId: 'a', at: DateTime(2026, 11, 13, 9), minutes: 31),
        event(trackId: 'a', at: DateTime(2026, 11, 12, 9), minutes: 31),
        event(trackId: 'a', at: DateTime(2026, 11, 10, 9), minutes: 31),
      ];
      final stats = computeStats(
        events: events,
        library: [track('a')],
        goalMinutes: 30,
        favouriteIds: const {},
        now: now,
      );
      expect(stats.streakDays, 2);
      expect(stats.goalMet, isTrue);
    });

    test('longest session allows short gaps only', () {
      final events = [
        event(trackId: 'a', at: DateTime(2026, 11, 13, 18, 0), minutes: 10),
        event(trackId: 'a', at: DateTime(2026, 11, 13, 18, 15), minutes: 10),
        event(trackId: 'a', at: DateTime(2026, 11, 13, 22, 0), minutes: 4),
      ];
      final stats = computeStats(
        events: events,
        library: [track('a')],
        goalMinutes: 30,
        favouriteIds: const {},
        now: now,
      );
      expect(stats.longestSessionMs, 20 * 60000);
    });

    test('top lists and genres rank by time', () {
      final events = [
        event(trackId: 'a', at: now.subtract(const Duration(hours: 1)), minutes: 20, artist: 'Mara', title: 'One', genre: 'Synth'),
        event(trackId: 'b', at: now.subtract(const Duration(hours: 2)), minutes: 5, artist: 'Juno', title: 'Two', genre: 'Folk'),
      ];
      final stats = computeStats(
        events: events,
        library: [track('a'), track('b')],
        goalMinutes: 30,
        favouriteIds: const {},
        now: now,
      );
      expect(stats.artists.first.name, 'Mara');
      expect(stats.tracks.first.name, 'One');
      expect(stats.genres.first.name, 'Synth');
      expect(stats.peakHour, 19);
    });

    test('empty input is safe', () {
      final stats = computeStats(
        events: const [],
        library: const [],
        goalMinutes: 30,
        favouriteIds: const {},
        now: now,
      );
      expect(stats.weekMinutes, 0);
      expect(stats.streakDays, 0);
      expect(stats.artists, isEmpty);
      expect(stats.changePercent, 0);
    });
  });

  group('buildMixes', () {
    final now = DateTime(2026, 11, 13, 20);

    test('on repeat needs at least three songs', () {
      final library = [track('a'), track('b'), track('c'), track('d')];
      final events = [
        for (var i = 0; i < 3; i++)
          event(trackId: 'a', at: now.subtract(Duration(days: i))),
        event(trackId: 'b', at: now.subtract(const Duration(days: 1))),
        event(trackId: 'c', at: now.subtract(const Duration(days: 2))),
      ];
      final mixes = buildMixes(
        events: events,
        library: library,
        favouriteIds: const {},
        ratings: const {},
        now: now,
      );
      expect(mixes.any((mix) => mix.id == 'repeat'), isTrue);
    });

    test('fresh finds are recent and unplayed', () {
      final fresh = Track(
        id: 'new',
        uri: 'file:///new',
        path: '/music/new.mp3',
        title: 'New',
        artist: 'Someone',
        album: 'Album',
        durationMs: 1000,
        addedAt: now.subtract(const Duration(days: 2)).millisecondsSinceEpoch,
      );
      final mixes = buildMixes(
        events: const [],
        library: [fresh],
        favouriteIds: const {},
        ratings: const {},
        now: now,
      );
      final mix = mixes.firstWhere((item) => item.id == 'fresh');
      expect(mix.tracks.single.id, 'new');
    });
  });
}
