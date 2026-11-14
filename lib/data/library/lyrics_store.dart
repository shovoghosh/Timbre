import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../core/prefs.dart';
import '../models/track.dart';
import 'tag_reader.dart';

/// Lyrics typed or pasted by the listener. Kept apart from the audio file so
/// nothing ever writes to the music itself.
class LyricsStore extends ChangeNotifier {
  static const _key = 'lyrics.v1';

  Map<String, String> _texts = <String, String>{};
  bool _ready = false;

  bool get ready => _ready;

  Future<void> init() async {
    final raw = Prefs.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          decoded.forEach((key, value) {
            if (value is String && value.trim().isNotEmpty) {
              _texts['$key'] = value;
            }
          });
        }
      } catch (_) {
        _texts = <String, String>{};
      }
    }
    _ready = true;
    notifyListeners();
  }

  String? of(String trackId) {
    final value = _texts[trackId];
    return (value == null || value.trim().isEmpty) ? null : value;
  }

  bool has(String trackId) => of(trackId) != null;

  Future<void> set(String trackId, String text) async {
    _texts = {..._texts};
    if (text.trim().isEmpty) {
      _texts.remove(trackId);
    } else {
      _texts[trackId] = text;
    }
    await _persist();
    notifyListeners();
  }

  Future<void> clear(String trackId) async {
    _texts = {..._texts}..remove(trackId);
    await _persist();
    notifyListeners();
  }

  Map<String, String> exportAll() => Map<String, String>.of(_texts);

  Future<void> restore(Map<String, String> values) async {
    _texts = Map<String, String>.of(values);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    await Prefs.setString(_key, jsonEncode(_texts));
  }
}

class LyricLine {
  const LyricLine(this.time, this.text);

  final Duration time;
  final String text;
}

/// Lyrics plus whether they carry timestamps.
class Lyrics {
  const Lyrics({required this.lines, required this.synced});

  final List<LyricLine> lines;
  final bool synced;

  bool get isEmpty => lines.isEmpty;

  /// Index of the line that is playing at [position], or -1.
  int indexAt(Duration position) {
    if (!synced || lines.isEmpty) return -1;
    var current = -1;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].time <= position) {
        current = i;
      } else {
        break;
      }
    }
    return current;
  }
}

/// Reads lyrics from the store, the file's tags, or a sidecar `.lrc` file.
Future<Lyrics> loadLyrics(Track track, LyricsStore store) async {
  final custom = store.of(track.id);
  if (custom != null) return parseLyrics(custom);

  final path = track.path;
  if (path.isNotEmpty && !path.startsWith('content://')) {
    try {
      final sidecar = File(
        p.join(p.dirname(path), '${p.basenameWithoutExtension(path)}.lrc'),
      );
      if (sidecar.existsSync()) {
        return parseLyrics(await sidecar.readAsString());
      }
      final tags = await TagReader.read(path);
      final embedded = tags.lyrics;
      if (embedded != null && embedded.trim().isNotEmpty) {
        return parseLyrics(embedded);
      }
    } catch (_) {
      // Fall through to empty lyrics.
    }
  }
  return const Lyrics(lines: [], synced: false);
}

final _stamp = RegExp(r'\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]');

Lyrics parseLyrics(String raw) {
  final lines = <LyricLine>[];
  var anyStamp = false;
  for (final rawLine in raw.split('\n')) {
    final text = rawLine.replaceAll(_stamp, '').trim();
    final matches = _stamp.allMatches(rawLine).toList();
    if (matches.isEmpty) {
      if (text.isNotEmpty) lines.add(LyricLine(Duration.zero, text));
      continue;
    }
    anyStamp = true;
    for (final match in matches) {
      final minutes = int.tryParse(match.group(1) ?? '') ?? 0;
      final seconds = int.tryParse(match.group(2) ?? '') ?? 0;
      final fractionText = match.group(3) ?? '';
      final fraction = fractionText.isEmpty
          ? 0
          : int.parse(fractionText.padRight(3, '0').substring(0, 3));
      lines.add(
        LyricLine(
          Duration(minutes: minutes, seconds: seconds, milliseconds: fraction),
          text.isEmpty ? '♪' : text,
        ),
      );
    }
  }
  if (anyStamp) {
    lines.sort((a, b) => a.time.compareTo(b.time));
  }
  return Lyrics(lines: lines, synced: anyStamp);
}
