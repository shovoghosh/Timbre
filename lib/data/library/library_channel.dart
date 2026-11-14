import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/track.dart';

/// One line of the raw library response.
class FolderInfo {
  const FolderInfo(this.path, this.count);

  final String path;
  final int count;

  String get name {
    if (path.isEmpty) return 'Music';
    final parts = path.split('/');
    return parts.lastWhere((p) => p.isNotEmpty, orElse: () => 'Music');
  }
}

class RawLibrary {
  const RawLibrary({
    required this.tracks,
    required this.folders,
    this.sdk = 0,
  });

  final List<Track> tracks;
  final List<FolderInfo> folders;
  final int sdk;
}

/// Bridge to the Android MediaStore reader in `LibraryChannel.kt`.
class LibraryChannel {
  const LibraryChannel();

  static const _channel = MethodChannel('timbre/library');

  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  Future<RawLibrary> query() async {
    if (!isSupported) {
      return const RawLibrary(tracks: [], folders: []);
    }
    final raw = await _channel.invokeMapMethod<String, Object?>('query');
    if (raw == null) return const RawLibrary(tracks: [], folders: []);

    final tracks = <Track>[];
    final list = raw['tracks'];
    if (list is List) {
      for (final item in list) {
        if (item is Map) {
          tracks.add(_trackFromMap(item.cast<String, Object?>()));
        }
      }
    }
    final folders = <FolderInfo>[];
    final rawFolders = raw['folders'];
    if (rawFolders is List) {
      for (final item in rawFolders) {
        if (item is Map) {
          final path = '${item['path'] ?? ''}';
          final count = (item['count'] as num?)?.toInt() ?? 0;
          if (path.isNotEmpty) folders.add(FolderInfo(path, count));
        }
      }
    }
    return RawLibrary(
      tracks: tracks,
      folders: folders,
      sdk: (raw['sdk'] as num?)?.toInt() ?? 0,
    );
  }

  /// Embedded cover art for one track, or null when the file has none.
  Future<Uint8List?> trackArt(String uri, {int size = 640}) async {
    if (!isSupported) return null;
    try {
      return await _channel.invokeMethod<Uint8List>('trackArt', {
        'uri': uri,
        'size': size,
      });
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Track _trackFromMap(Map<String, Object?> map) {
    String text(Object? value) => value == null ? '' : '$value';
    int number(Object? value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return 0;
    }

    final id = text(map['id']);
    final uri = text(map['uri']);
    final artKey = map['artKey'] == null ? null : text(map['artKey']);
    return Track(
      id: id,
      uri: uri,
      path: text(map['path']),
      title: text(map['title']),
      artist: text(map['artist']),
      album: text(map['album']),
      albumArtist: text(map['albumArtist']),
      genre: map['genre'] == null ? null : text(map['genre']),
      trackNo: number(map['trackNo']),
      discNo: number(map['discNo']),
      year: number(map['year']),
      durationMs: number(map['durationMs']),
      sizeBytes: number(map['sizeBytes']),
      addedAt: number(map['addedAt']),
      modifiedAt: number(map['modifiedAt']),
      folder: text(map['folder']),
      artKey: artKey,
      bitrate: number(map['bitrate']),
      mimeType: map['mimeType'] == null ? null : text(map['mimeType']),
    );
  }
}
