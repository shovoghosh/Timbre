import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/format.dart';
import '../../core/prefs.dart';
import '../models/track.dart';
import 'artwork.dart';
import 'library_channel.dart';
import 'tag_reader.dart';

enum LibraryStatus { empty, loading, ready, scanning, denied, failed }

enum PermissionOutcome { granted, denied, blocked, unsupported }

enum SortMode {
  recent('Recently added'),
  title('Title'),
  artist('Artist'),
  album('Album'),
  duration('Longest'),
  year('Year');

  const SortMode(this.label);
  final String label;
}

class SearchResults {
  const SearchResults({
    this.songs = const [],
    this.albums = const [],
    this.artists = const [],
  });

  final List<Track> songs;
  final List<AlbumGroup> albums;
  final List<ArtistGroup> artists;

  bool get isEmpty => songs.isEmpty && albums.isEmpty && artists.isEmpty;
}

/// Owns the local library: scanning, folder choices, sorting, search, and the
/// cache that makes the next launch instant.
class LibraryController extends ChangeNotifier {
  LibraryController({required this.artwork});

  final ArtworkStore artwork;
  final LibraryChannel _channel = const LibraryChannel();

  static const _kHidden = 'library.hiddenFolders';
  static const _kHideShort = 'library.hideShort';
  static const _kSort = 'library.sort';
  static const shortClipMs = 30000;
  static const _tagGapLimit = 200;

  List<Track> _all = const [];
  List<Track> _visible = const [];
  List<FolderInfo> _folders = const [];
  Set<String> _hidden = <String>{};
  bool _hideShort = false;
  SortMode _sort = SortMode.recent;
  LibraryStatus _status = LibraryStatus.loading;
  String? _error;
  int _lastScanAt = 0;
  bool _warming = false;
  bool _fillingTags = false;
  bool _permissionBlocked = false;

  List<AlbumGroup>? _albums;
  List<ArtistGroup>? _artists;

  List<Track> get tracks => _visible;
  List<Track> get allTracks => _all;
  List<FolderInfo> get folders => _folders;
  LibraryStatus get status => _status;
  String? get error => _error;
  int get lastScanAt => _lastScanAt;
  bool get hideShortClips => _hideShort;
  SortMode get sort => _sort;
  bool get permissionBlocked => _permissionBlocked;
  bool get isScanning => _status == LibraryStatus.scanning;
  bool get isEmpty => _visible.isEmpty;
  bool get hasMusic => _visible.isNotEmpty;
  int get songCount => _visible.length;
  int get albumCount => _buildAlbums().length;
  int get artistCount => _buildArtists().length;
  int get folderCount => _folders.length;
  int get totalDurationMs =>
      _visible.fold(0, (sum, track) => sum + track.durationMs);
  int get totalBytes => _visible.fold(0, (sum, track) => sum + track.sizeBytes);

  List<AlbumGroup> get albums {
    _albums ??= _buildAlbums();
    return _albums!;
  }

  List<ArtistGroup> get artists {
    _artists ??= _buildArtists();
    return _artists!;
  }

  bool isFolderHidden(String path) => _hidden.contains(path);

  int folderSongCount(String path) =>
      _all.where((track) => track.folder == path).length;

  List<Track> tracksInFolder(String path) =>
      _visible.where((track) => track.folder == path).toList();

  Future<void> init() async {
    _hidden = _readHidden();
    _hideShort = Prefs.getBool(_kHideShort);
    final savedSort = Prefs.getString(_kSort);
    _sort = SortMode.values.firstWhere(
      (mode) => mode.name == savedSort,
      orElse: () => SortMode.recent,
    );
    await artwork.init();
    await _loadCache();
    if (_all.isEmpty) {
      _status = LibraryStatus.empty;
    } else {
      _apply();
      _status = _visible.isEmpty ? LibraryStatus.empty : LibraryStatus.ready;
      unawaited(_warmCovers());
      unawaited(_fillTagGaps());
    }
    notifyListeners();
  }

  Future<PermissionOutcome> ensurePermission() async {
    if (kIsWeb || !Platform.isAndroid) return PermissionOutcome.unsupported;
    var audio = await Permission.audio.status;
    if (!audio.isGranted) {
      audio = await Permission.audio.request();
    }
    if (audio.isGranted) {
      _permissionBlocked = false;
      return PermissionOutcome.granted;
    }
    // Android 12 and older use storage instead of a media audio permission.
    var storage = await Permission.storage.status;
    if (!storage.isGranted) {
      storage = await Permission.storage.request();
    }
    if (storage.isGranted) {
      _permissionBlocked = false;
      return PermissionOutcome.granted;
    }
    _permissionBlocked =
        audio.isPermanentlyDenied || storage.isPermanentlyDenied;
    return _permissionBlocked
        ? PermissionOutcome.blocked
        : PermissionOutcome.denied;
  }

  /// Opens the system screen where a blocked permission can be allowed.
  Future<void> openSystemSettings() async {
    await openAppSettings();
  }

  Future<bool> scan() async {
    if (!LibraryChannel.isSupported) {
      _error = 'Scanning the device is Android only. On iPhone, import files instead.';
      _status = LibraryStatus.failed;
      notifyListeners();
      return false;
    }
    _status = LibraryStatus.scanning;
    _error = null;
    notifyListeners();

    final permission = await ensurePermission();
    if (permission != PermissionOutcome.granted) {
      _status = LibraryStatus.denied;
      notifyListeners();
      return false;
    }

    try {
      final raw = await _channel.query();
      _all = raw.tracks;
      _folders = _mergeFolders(raw.folders, raw.tracks);
      _lastScanAt = DateTime.now().millisecondsSinceEpoch;
      _apply();
      _status = _visible.isEmpty ? LibraryStatus.empty : LibraryStatus.ready;
      await _saveCache();
      notifyListeners();
      unawaited(_warmCovers());
      unawaited(_fillTagGaps());
      return true;
    } catch (error) {
      _error = 'Could not read the library: $error';
      _status = LibraryStatus.failed;
      notifyListeners();
      return false;
    }
  }

  /// Fills tags that MediaStore could not read.
  ///
  /// For some formats, WAV in particular, the system reports the file name as
  /// the title and no artist at all. The app has its own tag reader for those
  /// files, and this pass runs after the library is already on screen so a
  /// slow card never delays the first frame.
  Future<void> _fillTagGaps() async {
    if (_fillingTags) return;
    final missing = _all
        .where((track) => track.artist.trim().isEmpty && track.path.isNotEmpty)
        .take(_tagGapLimit)
        .toList();
    if (missing.isEmpty) return;

    _fillingTags = true;
    final patches = <String, Track>{};
    try {
      for (final track in missing) {
        final tags = await TagReader.read(track.path);
        if (!tags.hasAnything) continue;

        final title = (tags.title ?? '').trim();
        final artist = (tags.artist ?? '').trim();
        final album = (tags.album ?? '').trim();
        final albumArtist = (tags.albumArtist ?? '').trim();
        final genre = (tags.genre ?? '').trim();
        final stem = p.basenameWithoutExtension(track.path).trim();
        final titleIsFileName =
            title.isNotEmpty &&
            (track.title.trim().toLowerCase() == stem.toLowerCase() ||
                track.title.trim().toLowerCase() ==
                    p.basename(track.path).toLowerCase());

        if (artist.isEmpty &&
            album.isEmpty &&
            albumArtist.isEmpty &&
            !titleIsFileName) {
          continue;
        }

        patches[track.id] = track.copyWith(
          title: titleIsFileName ? title : null,
          artist: artist.isEmpty ? null : artist,
          album: album.isEmpty ? null : album,
          albumArtist: albumArtist.isEmpty ? null : albumArtist,
          genre: genre.isEmpty ? null : genre,
          year: tags.year > 0 ? tags.year : null,
          trackNo: tags.trackNo > 0 ? tags.trackNo : null,
          discNo: tags.discNo > 0 ? tags.discNo : null,
        );
      }
    } catch (_) {
      // A file that cannot be read keeps the values the system reported.
    } finally {
      _fillingTags = false;
    }

    if (patches.isEmpty) return;
    _all = _all.map((track) => patches[track.id] ?? track).toList();
    _apply();
    notifyListeners();
    await _saveCache();
  }

  /// Adds tracks found by an importer without dropping the existing library.
  Future<void> addTracks(List<Track> incoming) async {
    if (incoming.isEmpty) return;
    final byId = {for (final track in _all) track.id: track};
    for (final track in incoming) {
      byId[track.id] = track;
    }
    _all = byId.values.toList();
    _folders = _mergeFolders(
      [for (final folder in _folders) folder.path].map((path) {
        final count = _all.where((track) => track.folder == path).length;
        return FolderInfo(path, count);
      }).toList(),
      _all,
    );
    _lastScanAt = DateTime.now().millisecondsSinceEpoch;
    _apply();
    _status = _visible.isEmpty ? LibraryStatus.empty : LibraryStatus.ready;
    await _saveCache();
    notifyListeners();
    unawaited(_warmCovers());
  }

  Future<void> removeTracks(Iterable<String> ids) async {
    final remove = ids.toSet();
    _all = _all.where((track) => !remove.contains(track.id)).toList();
    _apply();
    _status = _visible.isEmpty ? LibraryStatus.empty : LibraryStatus.ready;
    await _saveCache();
    notifyListeners();
  }

  Future<void> setFolderHidden(String path, bool hidden) async {
    if (hidden) {
      _hidden.add(path);
    } else {
      _hidden.remove(path);
    }
    await Prefs.setStringList(_kHidden, _hidden.toList());
    _apply();
    _status = _visible.isEmpty ? LibraryStatus.empty : LibraryStatus.ready;
    notifyListeners();
  }

  Future<void> setAllFoldersHidden(bool hidden) async {
    _hidden = hidden
        ? _folders.map((folder) => folder.path).toSet()
        : <String>{};
    await Prefs.setStringList(_kHidden, _hidden.toList());
    _apply();
    _status = _visible.isEmpty ? LibraryStatus.empty : LibraryStatus.ready;
    notifyListeners();
  }

  Future<void> setHideShortClips(bool value) async {
    if (value == _hideShort) return;
    _hideShort = value;
    await Prefs.setBool(_kHideShort, value);
    _apply();
    notifyListeners();
  }

  Future<void> setSort(SortMode mode) async {
    if (mode == _sort) return;
    _sort = mode;
    await Prefs.setString(_kSort, mode.name);
    _apply();
    notifyListeners();
  }

  Future<void> clearLibrary() async {
    _all = const [];
    _visible = const [];
    _folders = const [];
    _albums = null;
    _artists = null;
    _lastScanAt = 0;
    _status = LibraryStatus.empty;
    try {
      final file = await _cacheFile();
      if (file.existsSync()) file.deleteSync();
    } catch (_) {
      // The in-memory state is already cleared.
    }
    notifyListeners();
  }

  Track? trackById(String id) {
    for (final track in _all) {
      if (track.id == id) return track;
    }
    return null;
  }

  SearchResults search(String query, {int limit = 80}) {
    final normalized = normalizeForSearch(query);
    if (normalized.isEmpty) return const SearchResults();

    final scored = <(int, Track)>[];
    for (final track in _visible) {
      var score = 0;
      final title = normalizeForSearch(track.title);
      final artist = normalizeForSearch(track.displayArtist);
      final album = normalizeForSearch(track.displayAlbum);
      final folder = normalizeForSearch(track.folder);

      if (title == normalized) {
        score = 100;
      } else if (title.startsWith(normalized)) {
        score = 82;
      } else if (title.contains(normalized)) {
        score = 64;
      }
      if (artist == normalized) {
        score = score > 55 ? score : 58;
      } else if (artist.startsWith(normalized)) {
        score = score > 45 ? score : 46;
      } else if (artist.contains(normalized)) {
        score = score > 36 ? score : 36;
      }
      if (album.startsWith(normalized)) {
        score = score > 30 ? score : 30;
      } else if (album.contains(normalized)) {
        score = score > 24 ? score : 24;
      }
      if (folder.contains(normalized)) {
        score = score > 16 ? score : 16;
      }
      if (score > 0) scored.add((score, track));
    }
    scored.sort((a, b) {
      final byScore = b.$1.compareTo(a.$1);
      if (byScore != 0) return byScore;
      return compareNatural(a.$2.title, b.$2.title);
    });

    final songs = scored.take(limit).map((entry) => entry.$2).toList();
    final albums = this.albums
        .where(
          (album) =>
              normalizeForSearch(album.title).contains(normalized) ||
              normalizeForSearch(album.artist).contains(normalized),
        )
        .take(12)
        .toList();
    final artists = this.artists
        .where((artist) => normalizeForSearch(artist.name).contains(normalized))
        .take(12)
        .toList();

    return SearchResults(songs: songs, albums: albums, artists: artists);
  }

  /// Loads the cover for one track (used by the player) and updates listeners.
  Future<String?> ensureCover(Track track) async {
    final path = await artwork.resolve(track);
    if (path == null) return null;
    _replaceCover(artwork.keyFor(track), path);
    return path;
  }

  Future<void> setCustomCover(Track track, String sourcePath) async {
    final path = await artwork.setOverride(track, sourcePath);
    if (path != null) _replaceCover(artwork.keyFor(track), path);
  }

  Future<void> clearCustomCover(Track track) async {
    await artwork.clearOverride(track);
    final key = artwork.keyFor(track);
    _all = _all.map((entry) {
      if (artwork.keyFor(entry) != key) return entry;
      return entry.copyWith(coverPath: '');
    }).toList();
    _apply();
    notifyListeners();
    unawaited(_warmCovers());
  }

  void _replaceCover(String key, String path) {
    var changed = false;
    _all = _all.map((track) {
      if (artwork.keyFor(track) != key) return track;
      if (track.coverPath == path) return track;
      changed = true;
      return track.copyWith(coverPath: path);
    }).toList();
    if (!changed) return;
    _apply();
    notifyListeners();
  }

  void _onCovers(Map<String, String> covers) {
    if (covers.isEmpty) return;
    var changed = false;
    _all = _all.map((track) {
      final path = covers[artwork.keyFor(track)];
      if (path == null || track.coverPath == path) return track;
      changed = true;
      return track.copyWith(coverPath: path);
    }).toList();
    if (!changed) return;
    _apply();
    notifyListeners();
    unawaited(_saveCache());
  }

  Future<void> _warmCovers() async {
    if (_warming || _visible.isEmpty) return;
    _warming = true;
    try {
      await artwork.warm(_visible, onCovers: _onCovers);
    } finally {
      _warming = false;
    }
  }

  void _apply() {
    final visible = <Track>[];
    for (final track in _all) {
      if (_hidden.contains(track.folder)) continue;
      if (_hideShort &&
          track.durationMs > 0 &&
          track.durationMs < shortClipMs) {
        continue;
      }
      visible.add(track);
    }
    _sortTracks(visible);
    _visible = visible;
    _albums = null;
    _artists = null;
  }

  void _sortTracks(List<Track> tracks) {
    switch (_sort) {
      case SortMode.recent:
        tracks.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      case SortMode.title:
        tracks.sort((a, b) => compareNatural(a.title, b.title));
      case SortMode.artist:
        tracks.sort((a, b) {
          final byArtist = compareNatural(a.displayArtist, b.displayArtist);
          if (byArtist != 0) return byArtist;
          final byAlbum = compareNatural(a.displayAlbum, b.displayAlbum);
          if (byAlbum != 0) return byAlbum;
          return a.trackNo.compareTo(b.trackNo);
        });
      case SortMode.album:
        tracks.sort((a, b) {
          final byAlbum = compareNatural(a.displayAlbum, b.displayAlbum);
          if (byAlbum != 0) return byAlbum;
          final byDisc = a.discNo.compareTo(b.discNo);
          if (byDisc != 0) return byDisc;
          return a.trackNo.compareTo(b.trackNo);
        });
      case SortMode.duration:
        tracks.sort((a, b) => b.durationMs.compareTo(a.durationMs));
      case SortMode.year:
        tracks.sort((a, b) {
          final byYear = b.year.compareTo(a.year);
          if (byYear != 0) return byYear;
          return compareNatural(a.title, b.title);
        });
    }
  }

  List<AlbumGroup> _buildAlbums() {
    final groups = <String, List<Track>>{};
    for (final track in _visible) {
      final artist = track.albumArtist.trim().isNotEmpty
          ? track.albumArtist.trim()
          : track.displayArtist;
      final key =
          '${track.displayAlbum.toLowerCase()}\u0000${artist.toLowerCase()}';
      groups.putIfAbsent(key, () => []).add(track);
    }
    final albums = <AlbumGroup>[];
    groups.forEach((key, tracks) {
      tracks.sort((a, b) {
        final byDisc = a.discNo.compareTo(b.discNo);
        if (byDisc != 0) return byDisc;
        return a.trackNo.compareTo(b.trackNo);
      });
      final sample = tracks.first;
      albums.add(
        AlbumGroup(
          key: key,
          title: sample.displayAlbum,
          artist: sample.albumArtist.trim().isNotEmpty
              ? sample.albumArtist.trim()
              : sample.displayArtist,
          tracks: tracks,
        ),
      );
    });
    albums.sort((a, b) => compareNatural(a.title, b.title));
    return albums;
  }

  List<ArtistGroup> _buildArtists() {
    final groups = <String, List<Track>>{};
    for (final track in _visible) {
      groups.putIfAbsent(track.displayArtist, () => []).add(track);
    }
    final artists = groups.entries.map((entry) {
      final albums = entry.value.map((t) => t.displayAlbum).toSet().length;
      return ArtistGroup(
        name: entry.key,
        tracks: entry.value,
        albumCount: albums,
      );
    }).toList();
    artists.sort((a, b) => compareNatural(a.name, b.name));
    return artists;
  }

  List<FolderInfo> _mergeFolders(
    List<FolderInfo> incoming,
    List<Track> tracks,
  ) {
    final counts = <String, int>{};
    for (final folder in incoming) {
      counts[folder.path] = folder.count;
    }
    if (counts.isEmpty) {
      for (final track in tracks) {
        if (track.folder.isEmpty) continue;
        counts[track.folder] = (counts[track.folder] ?? 0) + 1;
      }
    }
    final entries =
        counts.entries
            .map((entry) => FolderInfo(entry.key, entry.value))
            .toList()
          ..sort((a, b) => compareNatural(a.path, b.path));
    return entries;
  }

  Set<String> _readHidden() {
    try {
      final raw = Prefs.getString(_kHidden);
      if (raw == null || raw.isEmpty) return <String>{};
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded.map((e) => '$e').toSet();
    } catch (_) {
      // Fall back to nothing hidden.
    }
    return <String>{};
  }

  Future<File> _cacheFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'timbre_library.json'));
  }

  Future<void> _saveCache() async {
    try {
      final file = await _cacheFile();
      final payload = jsonEncode({
        'version': 1,
        'scannedAt': _lastScanAt,
        'tracks': _all.map((track) => track.toJson()).toList(),
        'folders': _folders
            .map((folder) => {'path': folder.path, 'count': folder.count})
            .toList(),
      });
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(payload, flush: true);
      await temp.rename(file.path);
    } catch (_) {
      // A failed cache write only costs a rescan later.
    }
  }

  Future<void> _loadCache() async {
    try {
      final file = await _cacheFile();
      if (!file.existsSync()) return;
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map) return;
      _lastScanAt = (raw['scannedAt'] as num?)?.toInt() ?? 0;
      final tracks = raw['tracks'];
      if (tracks is List) {
        _all = tracks
            .whereType<Map>()
            .map((json) => Track.fromJson(json.cast<String, dynamic>()))
            .where((track) => track.id.isNotEmpty)
            .toList();
      }
      final folders = raw['folders'];
      if (folders is List) {
        _folders = folders
            .whereType<Map>()
            .map(
              (json) => FolderInfo(
                '${json['path']}',
                (json['count'] as num?)?.toInt() ?? 0,
              ),
            )
            .toList();
      }
    } catch (_) {
      // A corrupt cache means an empty library until the next scan.
    }
  }
}
