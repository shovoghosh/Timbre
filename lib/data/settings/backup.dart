import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/services.dart';
import '../models/play_event.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import '../settings/app_settings.dart';
import '../../audio/playback_controller.dart';
import '../../theme/theme_controller.dart';
import '../../theme/tokens.dart';

class BackupPreview {
  const BackupPreview({
    required this.exportedAt,
    required this.playlists,
    required this.favorites,
    required this.plays,
    required this.lyrics,
    required this.matchedTracks,
    required this.totalRefs,
  });

  final String exportedAt;
  final int playlists;
  final int favorites;
  final int plays;
  final int lyrics;
  final int matchedTracks;
  final int totalRefs;
}

class RestoreSummary {
  const RestoreSummary({
    required this.playlists,
    required this.favorites,
    required this.plays,
    required this.matched,
    required this.missing,
  });

  final int playlists;
  final int favorites;
  final int plays;
  final int matched;
  final int missing;
}

/// One JSON file with the listener's setup, lists and history.
///
/// Audio is never copied. Restores find songs again by file path, falling back
/// to a unique file name and finally to title plus artist.
class BackupService {
  const BackupService();

  static const formatVersion = 1;

  Future<File> export() async {
    final services = Services.i;
    final library = services.library;
    final paths = <String, String>{};
    for (final track in library.tracks) {
      paths[track.id] = track.path;
    }

    final history = await services.history.all(limit: 20000);
    final theme = services.theme;
    final settings = services.settings;
    final playback = services.playback;

    final data = <String, dynamic>{
      'app': 'timbre',
      'version': formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'theme': {
        'choice': theme.choice.name,
        'accent': theme.accent.id,
        'glass': theme.glass,
        'dynamic': theme.dynamicAccent,
        'haptics': theme.haptics,
      },
      'settings': {
        'dailyGoal': settings.dailyGoalMinutes,
        'pauseOnUnplug': settings.pauseOnUnplug,
        'resumeOnPlug': settings.resumeOnPlug,
        'fade': settings.fade,
        'sleepFade': settings.sleepFade,
        'skipSilence': settings.skipSilence,
        'hideShort': settings.hideShortClips,
        'normalize': settings.normalizeVolume,
        'widgets': settings.widgetsEnabled,
        'crossfade': settings.crossfadeSeconds,
      },
      'playback': {
        'repeat': playback.repeat.name,
        'shuffle': playback.isShuffled,
        'volume': playback.volume,
        'speeds': {for (final track in library.tracks) track.id: playback.speedFor(track)},
      },
      'favorites': [
        for (final id in services.favorites.ids)
          {'id': id, 'path': paths[id]},
      ],
      'ratings': [
        for (final entry in services.ratings.all.entries)
          {'id': entry.key, 'path': paths[entry.key], 'stars': entry.value},
      ],
      'lyrics': [
        for (final entry in services.lyrics.exportAll().entries)
          {'id': entry.key, 'path': paths[entry.key], 'text': entry.value},
      ],
      'playlists': [
        for (final playlist in services.playlists.items)
          {
            'id': playlist.id,
            'name': playlist.name,
            'description': playlist.description,
            'createdAt': playlist.createdAt,
            'updatedAt': playlist.updatedAt,
            'tracks': [
              for (final id in playlist.trackIds)
                {'id': id, 'path': paths[id]},
            ],
          },
      ],
      'history': [
        for (final event in history)
          {
            'trackId': event.trackId,
            'path': paths[event.trackId],
            'title': event.title,
            'artist': event.artist,
            'album': event.album,
            'genre': event.genre,
            'startedAt': event.startedAt,
            'listenedMs': event.listenedMs,
            'completed': event.completed,
          },
      ],
    };

    final directory = await getTemporaryDirectory();
    final now = DateTime.now();
    final name =
        'timbre-backup-${now.year}${_two(now.month)}${_two(now.day)}-${_two(now.hour)}${_two(now.minute)}.json';
    final file = File(p.join(directory.path, name));
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    return file;
  }

  Future<BackupPreview?> inspect(File file) async {
    final data = await _read(file);
    if (data == null) return null;
    final library = Services.i.library;
    final resolver = _Resolver(library.tracks);
    final playlists = (data['playlists'] as List?) ?? const [];
    final favorites = (data['favorites'] as List?) ?? const [];
    final history = (data['history'] as List?) ?? const [];
    final lyrics = (data['lyrics'] as List?) ?? const [];

    var total = 0;
    var matched = 0;
    void count(Object? entry) {
      if (entry is! Map) return;
      total++;
      if (resolver.resolve(
            path: entry['path'] as String?,
            title: entry['title'] as String?,
            artist: entry['artist'] as String?,
          ) !=
          null) {
        matched++;
      }
    }

    for (final playlist in playlists) {
      if (playlist is Map) {
        for (final track in (playlist['tracks'] as List?) ?? const []) {
          count(track);
        }
      }
    }
    for (final favorite in favorites) {
      count(favorite);
    }
    for (final event in history.take(2000)) {
      count(event);
    }
    for (final line in lyrics) {
      count(line);
    }

    return BackupPreview(
      exportedAt: '${data['exportedAt'] ?? 'Unknown date'}',
      playlists: playlists.length,
      favorites: favorites.length,
      plays: history.length,
      lyrics: lyrics.length,
      matchedTracks: matched,
      totalRefs: total,
    );
  }

  Future<RestoreSummary?> restore(File file) async {
    final data = await _read(file);
    if (data == null) return null;
    final services = Services.i;
    final resolver = _Resolver(services.library.tracks);

    final theme = data['theme'];
    if (theme is Map) {
      final choice = ThemeChoice.values.firstWhere(
        (value) => value.name == theme['choice'],
        orElse: () => ThemeChoice.system,
      );
      await services.theme.setChoice(choice);
      await services.theme.setAccent(accentById(theme['accent'] as String?));
      await services.theme.setGlass(theme['glass'] as bool? ?? true);
      await services.theme.setDynamicAccent(theme['dynamic'] as bool? ?? true);
      await services.theme.setHaptics(theme['haptics'] as bool? ?? true);
    }

    final settings = data['settings'];
    if (settings is Map) {
      await _applySettings(settings, services.settings);
    }

    final playbackData = data['playback'];
    if (playbackData is Map) {
      final repeat = PlayerRepeatMode.values.firstWhere(
        (mode) => mode.name == playbackData['repeat'],
        orElse: () => PlayerRepeatMode.off,
      );
      final speeds = <String, double>{};
      final rawSpeeds = playbackData['speeds'];
      if (rawSpeeds is Map) {
        rawSpeeds.forEach((key, value) {
          if (value is num) speeds['$key'] = value.toDouble();
        });
      }
      await services.playback.restorePreferences(
        repeat: repeat,
        shuffle: playbackData['shuffle'] as bool? ?? false,
        volume: (playbackData['volume'] as num?)?.toDouble() ?? 1,
        speeds: speeds,
      );
    }

    var matched = 0;
    var missing = 0;
    int resolveId(Map entry) {
      final id = resolver.resolve(
        path: entry['path'] as String?,
        title: entry['title'] as String?,
        artist: entry['artist'] as String?,
      );
      if (id == null) {
        missing++;
        return 0;
      }
      matched++;
      return 1;
    }

    final favorites = <String>[];
    for (final entry in (data['favorites'] as List?) ?? const []) {
      if (entry is! Map) continue;
      resolveId(entry);
      final id = resolver.resolve(
        path: entry['path'] as String?,
        title: entry['title'] as String?,
        artist: entry['artist'] as String?,
      );
      if (id != null) favorites.add(id);
    }
    if (favorites.isNotEmpty) await services.favorites.restore(favorites);

    final ratings = <String, int>{};
    for (final entry in (data['ratings'] as List?) ?? const []) {
      if (entry is! Map) continue;
      final id = resolver.resolve(
        path: entry['path'] as String?,
        title: entry['title'] as String?,
        artist: entry['artist'] as String?,
      );
      if (id != null) {
        ratings[id] = (entry['stars'] as num?)?.toInt().clamp(0, 5) ?? 0;
      }
    }
    if (ratings.isNotEmpty) await services.ratings.restore(ratings);

    final lyrics = <String, String>{};
    for (final entry in (data['lyrics'] as List?) ?? const []) {
      if (entry is! Map) continue;
      final text = entry['text'] as String?;
      if (text == null || text.trim().isEmpty) continue;
      final id = resolver.resolve(
        path: entry['path'] as String?,
        title: entry['title'] as String?,
        artist: entry['artist'] as String?,
      );
      if (id != null) lyrics[id] = text;
    }
    if (lyrics.isNotEmpty) await services.lyrics.restore(lyrics);

    final playlists = <Playlist>[];
    for (final entry in (data['playlists'] as List?) ?? const []) {
      if (entry is! Map) continue;
      final ids = <String>[];
      for (final track in (entry['tracks'] as List?) ?? const []) {
        if (track is! Map) continue;
        final id = resolver.resolve(
          path: track['path'] as String?,
          title: track['title'] as String?,
          artist: track['artist'] as String?,
        );
        if (id != null && !ids.contains(id)) ids.add(id);
      }
      playlists.add(
        Playlist(
          id: '${entry['id'] ?? 'restored-${playlists.length}'}',
          name: '${entry['name'] ?? 'Playlist'}',
          trackIds: ids,
          createdAt: (entry['createdAt'] as num?)?.toInt() ?? 0,
          updatedAt: (entry['updatedAt'] as num?)?.toInt() ?? 0,
          description: '${entry['description'] ?? ''}',
        ),
      );
    }
    if (playlists.isNotEmpty) await services.playlists.restore(playlists);

    final events = <PlayEvent>[];
    for (final entry in (data['history'] as List?) ?? const []) {
      if (entry is! Map) continue;
      final id = resolver.resolve(
        path: entry['path'] as String?,
        title: entry['title'] as String?,
        artist: entry['artist'] as String?,
      );
      events.add(
        PlayEvent(
          trackId: id ?? '${entry['trackId'] ?? ''}',
          title: '${entry['title'] ?? 'Unknown'}',
          artist: '${entry['artist'] ?? ''}',
          album: '${entry['album'] ?? ''}',
          genre: '${entry['genre'] ?? ''}',
          startedAt: (entry['startedAt'] as num?)?.toInt() ?? 0,
          listenedMs: (entry['listenedMs'] as num?)?.toInt() ?? 0,
          completed: entry['completed'] == true,
        ),
      );
    }
    if (events.isNotEmpty) {
      await services.history.replaceAll(events);
    }
    await services.stats.load();

    return RestoreSummary(
      playlists: playlists.length,
      favorites: favorites.length,
      plays: events.length,
      matched: matched,
      missing: missing,
    );
  }

  Future<void> _applySettings(Map data, AppSettings settings) async {
    if (data['dailyGoal'] is num) {
      await settings.setDailyGoal((data['dailyGoal'] as num).toInt());
    }
    if (data['pauseOnUnplug'] is bool) {
      await settings.setPauseOnUnplug(data['pauseOnUnplug'] as bool);
    }
    if (data['resumeOnPlug'] is bool) {
      await settings.setResumeOnPlug(data['resumeOnPlug'] as bool);
    }
    if (data['fade'] is bool) await settings.setFade(data['fade'] as bool);
    if (data['sleepFade'] is bool) {
      await settings.setSleepFade(data['sleepFade'] as bool);
    }
    if (data['skipSilence'] is bool) {
      await settings.setSkipSilence(data['skipSilence'] as bool);
    }
    if (data['hideShort'] is bool) {
      await settings.setHideShortClips(data['hideShort'] as bool);
    }
    if (data['normalize'] is bool) {
      await settings.setNormalizeVolume(data['normalize'] as bool);
    }
    if (data['widgets'] is bool) {
      await settings.setWidgetsEnabled(data['widgets'] as bool);
    }
    if (data['crossfade'] is num) {
      await settings.setCrossfadeSeconds((data['crossfade'] as num).toInt());
    }
  }

  Future<Map<String, dynamic>?> _read(File file) async {
    try {
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map) return null;
      if (raw['app'] != 'timbre') return null;
      return raw.cast<String, dynamic>();
    } catch (error) {
      debugPrint('Timbre backup read failed: $error');
      return null;
    }
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}

/// Finds a current track id from a path, file name, or title and artist.
class _Resolver {
  _Resolver(List<Track> tracks) {
    for (final track in tracks) {
      _byPath[track.path] = track.id;
      final name = p.basename(track.path);
      _byName.putIfAbsent(name, () => <String>[]).add(track.id);
      final titleKey = _titleKey(track.title, track.displayArtist);
      _byTitle.putIfAbsent(titleKey, () => <String>[]).add(track.id);
    }
  }

  final _byPath = <String, String>{};
  final _byName = <String, List<String>>{};
  final _byTitle = <String, List<String>>{};

  String? resolve({String? path, String? title, String? artist}) {
    if (path != null && path.isNotEmpty) {
      final direct = _byPath[path];
      if (direct != null) return direct;
      final byName = _byName[p.basename(path)];
      if (byName != null && byName.length == 1) return byName.first;
    }
    if (title != null && title.trim().isNotEmpty) {
      final byTitle = _byTitle[_titleKey(title, artist ?? '')];
      if (byTitle != null && byTitle.length == 1) return byTitle.first;
    }
    return null;
  }

  static String _titleKey(String title, String artist) =>
      '${title.trim().toLowerCase()}|${artist.trim().toLowerCase()}';
}
