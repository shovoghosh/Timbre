import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/prefs.dart';

/// Favorite track ids.
class FavoritesStore extends ChangeNotifier {
  static const _key = 'favorites.v1';

  Set<String> _ids = <String>{};
  bool _ready = false;

  Set<String> get ids => _ids;
  int get length => _ids.length;
  bool get ready => _ready;

  Future<void> init() async {
    final raw = Prefs.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) _ids = decoded.map((e) => '$e').toSet();
      } catch (_) {
        _ids = <String>{};
      }
    }
    _ready = true;
    notifyListeners();
  }

  bool contains(String trackId) => _ids.contains(trackId);

  Future<bool> toggle(String trackId) async {
    final added = !_ids.contains(trackId);
    if (added) {
      _ids = {..._ids, trackId};
    } else {
      _ids = {..._ids}..remove(trackId);
    }
    await _persist();
    notifyListeners();
    return added;
  }

  Future<void> restore(Iterable<String> ids) async {
    _ids = ids.toSet();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    await Prefs.setString(_key, jsonEncode(_ids.toList()));
  }
}

/// One to five stars per track. Zero means unrated.
class RatingsStore extends ChangeNotifier {
  static const _key = 'ratings.v1';

  Map<String, int> _ratings = <String, int>{};
  bool _ready = false;

  Map<String, int> get all => _ratings;
  bool get ready => _ready;

  Future<void> init() async {
    final raw = Prefs.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          decoded.forEach((key, value) {
            if (value is num) _ratings['$key'] = value.toInt().clamp(0, 5);
          });
        }
      } catch (_) {
        _ratings = <String, int>{};
      }
    }
    _ready = true;
    notifyListeners();
  }

  int of(String trackId) => _ratings[trackId] ?? 0;

  Future<void> set(String trackId, int stars) async {
    final value = stars.clamp(0, 5);
    _ratings = {..._ratings};
    if (value == 0) {
      _ratings.remove(trackId);
    } else {
      _ratings[trackId] = value;
    }
    await Prefs.setString(_key, jsonEncode(_ratings));
    notifyListeners();
  }

  Future<void> restore(Map<String, int> ratings) async {
    _ratings = Map<String, int>.of(ratings);
    await Prefs.setString(_key, jsonEncode(_ratings));
    notifyListeners();
  }
}
