import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// One online cover candidate.
class CoverHit {
  const CoverHit({
    required this.url,
    required this.title,
    required this.artist,
    required this.source,
  });

  final String url;
  final String title;
  final String artist;
  final String source;
}

/// Looks for album art on the public iTunes and Deezer search APIs.
///
/// Only the words in the search box are sent, and only when the listener opens
/// the cover picker.
class CoverSearch {
  const CoverSearch();

  static const _timeout = Duration(seconds: 8);

  Future<List<CoverHit>> search(String query) async {
    final term = query.trim();
    if (term.isEmpty) return const [];
    final results = await Future.wait([
      _itunes(term).catchError((_) => <CoverHit>[]),
      _deezer(term).catchError((_) => <CoverHit>[]),
    ]);
    final seen = <String>{};
    final merged = <CoverHit>[];
    for (final hit in results.expand((list) => list)) {
      final key = '${hit.title.toLowerCase()}|${hit.artist.toLowerCase()}';
      if (!seen.add(key)) continue;
      merged.add(hit);
    }
    return merged;
  }

  Future<List<CoverHit>> _itunes(String term) async {
    final uri = Uri.https('itunes.apple.com', '/search', {
      'term': term,
      'entity': 'album',
      'limit': '12',
      'media': 'music',
    });
    final response = await http.get(uri).timeout(_timeout);
    if (response.statusCode != 200) return const [];
    final decoded = jsonDecode(response.body);
    final results = decoded is Map ? decoded['results'] : null;
    if (results is! List) return const [];
    final hits = <CoverHit>[];
    for (final item in results) {
      if (item is! Map) continue;
      final art = '${item['artworkUrl100'] ?? ''}';
      if (art.isEmpty) continue;
      hits.add(
        CoverHit(
          url: art.replaceAll('100x100', '600x600'),
          title: '${item['collectionName'] ?? 'Album'}',
          artist: '${item['artistName'] ?? ''}',
          source: 'iTunes',
        ),
      );
    }
    return hits;
  }

  Future<List<CoverHit>> _deezer(String term) async {
    final uri = Uri.https('api.deezer.com', '/search/album', {
      'q': term,
      'limit': '12',
    });
    final response = await http.get(uri).timeout(_timeout);
    if (response.statusCode != 200) return const [];
    final decoded = jsonDecode(response.body);
    final data = decoded is Map ? decoded['data'] : null;
    if (data is! List) return const [];
    final hits = <CoverHit>[];
    for (final item in data) {
      if (item is! Map) continue;
      final art = '${item['cover_xl'] ?? item['cover_big'] ?? ''}';
      if (art.isEmpty) continue;
      final artist = item['artist'];
      hits.add(
        CoverHit(
          url: art,
          title: '${item['title'] ?? 'Album'}',
          artist: artist is Map ? '${artist['name'] ?? ''}' : '',
          source: 'Deezer',
        ),
      );
    }
    return hits;
  }

  /// Downloads a candidate into a temporary file, ready to be copied into the
  /// app's own covers folder.
  Future<File?> download(CoverHit hit) async {
    try {
      final response = await http.get(Uri.parse(hit.url)).timeout(_timeout);
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) return null;
      final directory = await getTemporaryDirectory();
      var hash = 0x811C9DC5;
      for (final unit in hit.url.codeUnits) {
        hash ^= unit;
        hash = (hash * 0x01000193) & 0xFFFFFFFF;
      }
      final file = File(
        p.join(directory.path, 'cover_${hash.toRadixString(16)}.jpg'),
      );
      await file.writeAsBytes(response.bodyBytes, flush: true);
      return file;
    } catch (_) {
      return null;
    }
  }
}
