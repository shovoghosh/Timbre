/// A song in the listener's library.
///
/// [uri] is what the audio engine opens. On Android that is a MediaStore content
/// URI; on iOS it is a file URI inside the app's documents folder.
class Track {
  const Track({
    required this.id,
    required this.uri,
    required this.path,
    required this.title,
    required this.artist,
    required this.album,
    this.albumArtist = '',
    this.genre,
    this.trackNo = 0,
    this.discNo = 0,
    this.year = 0,
    required this.durationMs,
    this.sizeBytes = 0,
    this.addedAt = 0,
    this.folder = '',
    this.artKey,
    this.coverPath,
    this.bitrate = 0,
    this.mimeType,
    this.modifiedAt = 0,
  });

  /// Stable identity. Never derived from the title so renames keep history.
  final String id;

  /// Playable URI handed to the audio engine.
  final String uri;

  /// Human readable file path, used for restores and folder filtering.
  final String path;

  final String title;
  final String artist;
  final String album;
  final String albumArtist;
  final String? genre;
  final int trackNo;
  final int discNo;
  final int year;
  final int durationMs;
  final int sizeBytes;

  /// Epoch milliseconds.
  final int addedAt;

  /// Folder relative to the storage root, without a trailing slash.
  final String folder;

  /// Album identity used to look up shared artwork.
  final String? artKey;

  /// Cached cover image on disk, if one has been extracted.
  final String? coverPath;

  final int bitrate;
  final String? mimeType;
  final int modifiedAt;

  String get displayArtist => artist.trim().isEmpty ? 'Unknown artist' : artist;
  String get displayAlbum => album.trim().isEmpty ? 'Unknown album' : album;
  String get displayGenre => (genre ?? '').trim().isEmpty ? 'Unknown' : genre!;
  String get folderName {
    if (folder.isEmpty) return 'Music';
    final parts = folder.split(RegExp(r'[/\\]'));
    return parts.lastWhere((p) => p.isNotEmpty, orElse: () => 'Music');
  }

  bool get isLong => durationMs >= 10 * 60 * 1000;

  /// Letter a library index puts this track under.
  String get indexLetter {
    final t = title.trim();
    if (t.isEmpty) return '#';
    final c = t[0].toUpperCase();
    return RegExp(r'[A-Z]').hasMatch(c) ? c : '#';
  }

  Track copyWith({
    String? uri,
    String? path,
    String? title,
    String? artist,
    String? album,
    String? albumArtist,
    String? genre,
    int? trackNo,
    int? discNo,
    int? year,
    int? durationMs,
    int? sizeBytes,
    int? addedAt,
    String? folder,
    String? artKey,
    String? coverPath,
    int? bitrate,
    String? mimeType,
    int? modifiedAt,
  }) {
    return Track(
      id: id,
      uri: uri ?? this.uri,
      path: path ?? this.path,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumArtist: albumArtist ?? this.albumArtist,
      genre: genre ?? this.genre,
      trackNo: trackNo ?? this.trackNo,
      discNo: discNo ?? this.discNo,
      year: year ?? this.year,
      durationMs: durationMs ?? this.durationMs,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      addedAt: addedAt ?? this.addedAt,
      folder: folder ?? this.folder,
      artKey: artKey ?? this.artKey,
      coverPath: coverPath ?? this.coverPath,
      bitrate: bitrate ?? this.bitrate,
      mimeType: mimeType ?? this.mimeType,
      modifiedAt: modifiedAt ?? this.modifiedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'uri': uri,
    'path': path,
    'title': title,
    'artist': artist,
    'album': album,
    'albumArtist': albumArtist,
    'genre': genre,
    'trackNo': trackNo,
    'discNo': discNo,
    'year': year,
    'durationMs': durationMs,
    'sizeBytes': sizeBytes,
    'addedAt': addedAt,
    'folder': folder,
    'artKey': artKey,
    'coverPath': coverPath,
    'bitrate': bitrate,
    'mimeType': mimeType,
    'modifiedAt': modifiedAt,
  };

  factory Track.fromJson(Map<String, dynamic> json) {
    int asInt(Object? v) => v is int ? v : int.tryParse('$v') ?? 0;
    String asStr(Object? v) => v == null ? '' : '$v';
    return Track(
      id: asStr(json['id']),
      uri: asStr(json['uri']),
      path: asStr(json['path']),
      title: asStr(json['title']),
      artist: asStr(json['artist']),
      album: asStr(json['album']),
      albumArtist: asStr(json['albumArtist']),
      genre: json['genre'] == null ? null : asStr(json['genre']),
      trackNo: asInt(json['trackNo']),
      discNo: asInt(json['discNo']),
      year: asInt(json['year']),
      durationMs: asInt(json['durationMs']),
      sizeBytes: asInt(json['sizeBytes']),
      addedAt: asInt(json['addedAt']),
      folder: asStr(json['folder']),
      artKey: json['artKey'] == null ? null : asStr(json['artKey']),
      coverPath: json['coverPath'] == null ? null : asStr(json['coverPath']),
      bitrate: asInt(json['bitrate']),
      mimeType: json['mimeType'] == null ? null : asStr(json['mimeType']),
      modifiedAt: asInt(json['modifiedAt']),
    );
  }

  @override
  bool operator ==(Object other) => other is Track && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Track($title, $id)';
}

/// An album folded out of the track list.
class AlbumGroup {
  const AlbumGroup({
    required this.key,
    required this.title,
    required this.artist,
    required this.tracks,
  });

  final String key;
  final String title;
  final String artist;
  final List<Track> tracks;

  int get durationMs => tracks.fold(0, (sum, t) => sum + t.durationMs);
  Track get sample => tracks.first;
  String? get artKey => sample.artKey;
  String? get coverPath =>
      tracks.map((t) => t.coverPath).firstWhere((p) => p != null, orElse: () => null);
  int? get year {
    for (final t in tracks) {
      if (t.year > 0) return t.year;
    }
    return null;
  }
}

/// An artist folded out of the track list.
class ArtistGroup {
  const ArtistGroup({
    required this.name,
    required this.tracks,
    required this.albumCount,
  });

  final String name;
  final List<Track> tracks;
  final int albumCount;

  int get durationMs => tracks.fold(0, (sum, t) => sum + t.durationMs);
}
