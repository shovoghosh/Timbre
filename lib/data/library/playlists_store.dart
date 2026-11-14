import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/prefs.dart';
import '../models/playlist.dart';

/// Listener-made playlists, newest first.
class PlaylistStore extends ChangeNotifier {
  static const _key = 'playlists.v1';

  List<Playlist> _items = const [];
  bool _ready = false;

  List<Playlist> get items => _items;
  bool get ready => _ready;
  int get length => _items.length;

  Future<void> init() async {
    if (_ready) return;
    final raw = Prefs.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _items = decoded
              .whereType<Map>()
              .map((json) => Playlist.fromJson(json.cast<String, dynamic>()))
              .toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        }
      } catch (_) {
        _items = const [];
      }
    }
    _ready = true;
    notifyListeners();
  }

  Playlist? byId(String id) {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  List<Playlist> containing(String trackId) =>
      _items.where((item) => item.trackIds.contains(trackId)).toList();

  Future<Playlist> create(String name, {List<String> trackIds = const []}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final playlist = Playlist(
      id: 'p$now${_items.length}',
      name: name.trim().isEmpty ? 'New playlist' : name.trim(),
      trackIds: trackIds,
      createdAt: now,
      updatedAt: now,
    );
    _items = [playlist, ..._items];
    await _persist();
    notifyListeners();
    return playlist;
  }

  Future<void> rename(String id, String name) async {
    _items = _items
        .map(
          (item) => item.id == id
              ? item.copyWith(
                  name: name.trim().isEmpty ? item.name : name.trim(),
                  updatedAt: DateTime.now().millisecondsSinceEpoch,
                )
              : item,
        )
        .toList();
    await _persist();
    notifyListeners();
  }

  Future<void> delete(String id) async {
    _items = _items.where((item) => item.id != id).toList();
    await _persist();
    notifyListeners();
  }

  Future<void> addTracks(String id, Iterable<String> trackIds) async {
    final playlist = byId(id);
    if (playlist == null) return;
    final next = [...playlist.trackIds];
    for (final trackId in trackIds) {
      if (!next.contains(trackId)) next.add(trackId);
    }
    _replace(playlist.copyWith(
      trackIds: next,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    ));
    await _persist();
    notifyListeners();
  }

  Future<void> removeTrack(String id, String trackId) async {
    final playlist = byId(id);
    if (playlist == null) return;
    _replace(playlist.copyWith(
      trackIds: playlist.trackIds.where((item) => item != trackId).toList(),
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    ));
    await _persist();
    notifyListeners();
  }

  Future<void> reorder(String id, int oldIndex, int newIndex) async {
    final playlist = byId(id);
    if (playlist == null) return;
    final next = [...playlist.trackIds];
    if (oldIndex < 0 || oldIndex >= next.length) return;
    var target = newIndex;
    if (target > oldIndex) target -= 1;
    if (target == oldIndex) return;
    final item = next.removeAt(oldIndex);
    next.insert(target, item);
    _replace(playlist.copyWith(
      trackIds: next,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    ));
    await _persist();
    notifyListeners();
  }

  Future<void> setCover(String id, String? path) async {
    final playlist = byId(id);
    if (playlist == null) return;
    _replace(
      path == null
          ? playlist.copyWith(clearCover: true)
          : playlist.copyWith(coverPath: path),
    );
    await _persist();
    notifyListeners();
  }

  Future<void> restore(List<Playlist> playlists) async {
    _items = playlists;
    await _persist();
    notifyListeners();
  }

  void _replace(Playlist value) {
    _items = _items.map((item) => item.id == value.id ? value : item).toList();
  }

  Future<void> _persist() async {
    try {
      await Prefs.setString(
        _key,
        jsonEncode(_items.map((item) => item.toJson()).toList()),
      );
    } catch (_) {
      // In-memory state stays usable.
    }
  }
}
