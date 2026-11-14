import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/track.dart';
import 'tag_reader.dart';

class ImportOutcome {
  const ImportOutcome({
    this.tracks = const [],
    this.cancelled = false,
    this.failed = 0,
    this.error,
  });

  final List<Track> tracks;
  final bool cancelled;
  final int failed;
  final String? error;

  bool get hasTracks => tracks.isNotEmpty;
}

/// Copies audio the listener picks into the app's own Music folder and reads
/// its tags. This is the path for iPhone, where there is no shared media store.
class ImportService {
  const ImportService();

  static const extensions = [
    'mp3',
    'm4a',
    'm4b',
    'aac',
    'flac',
    'wav',
    'ogg',
    'oga',
    'opus',
    'aiff',
    'aif',
    'alac',
    'wma',
  ];

  Future<ImportOutcome> pickAndImport() async {
    List<PlatformFile> files;
    try {
      files = await FilePicker.pickFiles(
        dialogTitle: 'Pick music to import',
        type: FileType.custom,
        allowedExtensions: extensions,
      );
    } catch (error) {
      return ImportOutcome(error: '$error');
    }
    if (files.isEmpty) {
      return const ImportOutcome(cancelled: true);
    }

    final directory = Directory(
      p.join((await getApplicationDocumentsDirectory()).path, 'Music'),
    );
    if (!directory.existsSync()) directory.createSync(recursive: true);

    final tracks = <Track>[];
    var failed = 0;
    for (final file in files) {
      final path = file.path;
      if (path == null) {
        failed++;
        continue;
      }
      try {
        final target = _uniqueTarget(directory, file.name);
        await File(path).copy(target.path);
        final tags = await TagReader.read(target.path);
        final title = tags.title?.trim();
        final album = tags.album?.trim();
        final artist = tags.artist?.trim();
        tracks.add(
          Track(
            id: 'import:${target.path}',
            uri: target.uri.toString(),
            path: target.path,
            title: (title == null || title.isEmpty)
                ? p.basenameWithoutExtension(file.name)
                : title,
            artist: artist ?? '',
            album: (album == null || album.isEmpty) ? 'Imported' : album,
            albumArtist: tags.albumArtist ?? '',
            genre: tags.genre,
            trackNo: tags.trackNo,
            discNo: tags.discNo,
            year: tags.year,
            durationMs: tags.durationMs,
            sizeBytes: target.lengthSync(),
            addedAt: DateTime.now().millisecondsSinceEpoch,
            modifiedAt: target.lastModifiedSync().millisecondsSinceEpoch,
            folder: 'Imported',
            artKey: _albumKey(album, artist),
            bitrate: 0,
            mimeType: p.extension(target.path).replaceAll('.', ''),
          ),
        );
      } catch (error) {
        debugPrint('Timbre import failed for $path: $error');
        failed++;
      }
    }

    return ImportOutcome(tracks: tracks, failed: failed);
  }

  File _uniqueTarget(Directory directory, String name) {
    final safe = name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    var target = File(p.join(directory.path, safe));
    if (!target.existsSync()) return target;
    final base = p.basenameWithoutExtension(safe);
    final extension = p.extension(safe);
    var counter = 2;
    while (target.existsSync()) {
      target = File(p.join(directory.path, '$base ($counter)$extension'));
      counter++;
    }
    return target;
  }

  String? _albumKey(String? album, String? artist) {
    final value = '${album ?? ''}|${artist ?? ''}'.toLowerCase().trim();
    if (value == '|') return null;
    var hash = 0x811C9DC5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return 'i${hash.toRadixString(16)}';
  }
}
