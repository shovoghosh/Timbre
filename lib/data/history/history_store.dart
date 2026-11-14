import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/play_event.dart';

/// Every play, stored on the device. Drives history, stats, and mixes.
class HistoryStore extends ChangeNotifier {
  Database? _db;

  Database get _database {
    final db = _db;
    if (db == null) throw StateError('HistoryStore.init() has not run');
    return db;
  }

  bool get ready => _db != null;

  Future<void> init() async {
    if (_db != null) return;
    final path = p.join(await getDatabasesPath(), 'timbre_history.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE plays(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            trackId TEXT NOT NULL,
            title TEXT NOT NULL,
            artist TEXT NOT NULL,
            album TEXT NOT NULL,
            genre TEXT NOT NULL,
            startedAt INTEGER NOT NULL,
            listenedMs INTEGER NOT NULL,
            completed INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('CREATE INDEX idx_plays_started ON plays(startedAt)');
        await db.execute('CREATE INDEX idx_plays_track ON plays(trackId)');
      },
    );
  }

  Future<int> insert(PlayEvent event) async {
    final id = await _database.insert('plays', {
      'trackId': event.trackId,
      'title': event.title,
      'artist': event.artist,
      'album': event.album,
      'genre': event.genre,
      'startedAt': event.startedAt,
      'listenedMs': event.listenedMs,
      'completed': event.completed ? 1 : 0,
    });
    notifyListeners();
    return id;
  }

  Future<void> update(int id, {required int listenedMs, bool? completed}) async {
    await _database.update(
      'plays',
      {
        'listenedMs': listenedMs,
        if (completed != null) 'completed': completed ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    notifyListeners();
  }

  Future<List<PlayEvent>> all({int limit = 20000}) async {
    final rows = await _database.query(
      'plays',
      orderBy: 'startedAt DESC',
      limit: limit,
    );
    return rows.map(_fromRow).toList();
  }

  Future<List<PlayEvent>> since(int epochMs, {int limit = 20000}) async {
    final rows = await _database.query(
      'plays',
      where: 'startedAt >= ?',
      whereArgs: [epochMs],
      orderBy: 'startedAt DESC',
      limit: limit,
    );
    return rows.map(_fromRow).toList();
  }

  Future<List<PlayEvent>> recent({int limit = 50}) async {
    final rows = await _database.query(
      'plays',
      orderBy: 'startedAt DESC',
      limit: limit,
    );
    return rows.map(_fromRow).toList();
  }

  Future<int> count() async {
    final result = await _database.rawQuery('SELECT COUNT(*) AS c FROM plays');
    return (result.first['c'] as num?)?.toInt() ?? 0;
  }

  /// How many times each track was played enough to count (30 seconds or half
  /// the song, whichever comes first).
  Future<Map<String, int>> playCounts({int sinceMs = 0}) async {
    final rows = await _database.rawQuery(
      '''
      SELECT trackId, COUNT(*) AS c FROM plays
      WHERE startedAt >= ? AND (listenedMs >= 30000 OR completed = 1)
      GROUP BY trackId
      ''',
      [sinceMs],
    );
    return {
      for (final row in rows) '${row['trackId']}': (row['c'] as num).toInt(),
    };
  }

  Future<int> lastPlayed(String trackId) async {
    final rows = await _database.query(
      'plays',
      columns: ['startedAt'],
      where: 'trackId = ?',
      whereArgs: [trackId],
      orderBy: 'startedAt DESC',
      limit: 1,
    );
    if (rows.isEmpty) return 0;
    return (rows.first['startedAt'] as num?)?.toInt() ?? 0;
  }

  Future<void> clear() async {
    await _database.delete('plays');
  }

  /// Used by backup restore.
  Future<void> replaceAll(List<PlayEvent> events) async {
    final batch = _database.batch();
    batch.delete('plays');
    for (final event in events) {
      batch.insert('plays', {
        'trackId': event.trackId,
        'title': event.title,
        'artist': event.artist,
        'album': event.album,
        'genre': event.genre,
        'startedAt': event.startedAt,
        'listenedMs': event.listenedMs,
        'completed': event.completed ? 1 : 0,
      });
    }
    await batch.commit(noResult: true);
  }

  PlayEvent _fromRow(Map<String, Object?> row) {
    return PlayEvent(
      id: (row['id'] as num?)?.toInt(),
      trackId: '${row['trackId']}',
      title: '${row['title']}',
      artist: '${row['artist']}',
      album: '${row['album']}',
      genre: '${row['genre']}',
      startedAt: (row['startedAt'] as num?)?.toInt() ?? 0,
      listenedMs: (row['listenedMs'] as num?)?.toInt() ?? 0,
      completed: (row['completed'] as num?)?.toInt() == 1,
    );
  }
}
