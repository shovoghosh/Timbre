import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/track.dart';
import 'library_channel.dart';
import 'tag_reader.dart';

/// Owns every cover image: extracted from files, custom picks, and the color
/// sampled from them for the dynamic accent.
class ArtworkStore {
  ArtworkStore({LibraryChannel? channel})
    : _channel = channel ?? const LibraryChannel();

  final LibraryChannel _channel;

  late Directory _dir;
  final Map<String, String> _cache = <String, String>{};
  final Map<String, String> _overrides = <String, String>{};
  final Map<String, Future<String?>> _inflight = <String, Future<String?>>{};
  final Map<String, Color?> _accents = <String, Color?>{};
  bool _ready = false;

  bool get ready => _ready;

  String keyFor(Track track) {
    final artKey = track.artKey;
    if (artKey != null && artKey.isNotEmpty) return 'album:$artKey';
    return 'file:${track.path}';
  }

  Future<void> init() async {
    if (_ready) return;
    final support = await getApplicationSupportDirectory();
    _dir = Directory(p.join(support.path, 'covers'));
    if (!_dir.existsSync()) _dir.createSync(recursive: true);
    final index = File(p.join(_dir.path, 'index.json'));
    if (index.existsSync()) {
      try {
        final raw = jsonDecode(index.readAsStringSync());
        if (raw is Map) {
          raw.forEach((key, value) {
            final file = File(p.join(_dir.path, '$value'));
            if (file.existsSync()) {
              _cache['$key'] = file.path;
              _overrides['$key'] = file.path;
            }
          });
        }
      } catch (_) {
        // A corrupt index just means covers are rebuilt.
      }
    }
    _ready = true;
  }

  /// A cover already on disk for this track, if any.
  String? known(Track track) {
    final key = keyFor(track);
    final override = _overrides[key];
    if (override != null) return override;
    final cached = _cache[key];
    if (cached != null) return cached;
    final coverPath = track.coverPath;
    if (coverPath != null && coverPath.isNotEmpty) return coverPath;
    return null;
  }

  /// Finds or extracts the cover, then returns its path.
  Future<String?> resolve(Track track) async {
    final knownPath = known(track);
    if (knownPath != null) return knownPath;
    final key = keyFor(track);
    final pending = _inflight[key];
    if (pending != null) return pending;

    final future = _extract(track, key);
    _inflight[key] = future;
    try {
      return await future;
    } finally {
      _inflight.remove(key);
    }
  }

  Future<String?> _extract(Track track, String key) async {
    Uint8List? bytes = await _channel.trackArt(track.uri, size: 720);
    if (bytes == null && track.path.isNotEmpty && !track.path.startsWith('content://')) {
      bytes = await TagReader.picture(track.path);
    }
    if (bytes == null || bytes.isEmpty) return null;

    try {
      final file = File(p.join(_dir.path, '${_hash(key)}.jpg'));
      await file.writeAsBytes(bytes, flush: true);
      _cache[key] = file.path;
      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// Extracts covers for the given tracks one at a time and reports progress in
  /// small batches. Skips work already done.
  Future<void> warm(
    List<Track> tracks, {
    required void Function(Map<String, String> covers) onCovers,
    int batchSize = 6,
  }) async {
    final seen = <String>{};
    final pending = <Track>[];
    for (final track in tracks) {
      final key = keyFor(track);
      if (seen.contains(key)) continue;
      seen.add(key);
      if (known(track) == null) pending.add(track);
    }
    if (pending.isEmpty) return;

    final buffer = <String, String>{};
    for (final track in pending) {
      final path = await resolve(track);
      if (path != null) buffer[keyFor(track)] = path;
      if (buffer.length >= batchSize) {
        onCovers(Map.of(buffer));
        buffer.clear();
      }
    }
    if (buffer.isNotEmpty) onCovers(Map.of(buffer));
  }

  /// Stores a listener-chosen image for this track's album (or file when the
  /// track has no album identity).
  Future<String?> setOverride(Track track, String sourcePath) async {
    await init();
    final source = File(sourcePath);
    if (!source.existsSync()) return null;
    final key = keyFor(track);
    final target = File(p.join(_dir.path, 'custom_${_hash(key)}${p.extension(sourcePath).toLowerCase()}'));
    await source.copy(target.path);
    _overrides[key] = target.path;
    _cache[key] = target.path;
    await _saveIndex();
    return target.path;
  }

  Future<void> clearOverride(Track track) async {
    final key = keyFor(track);
    final existing = _overrides.remove(key);
    _cache.remove(key);
    if (existing != null) {
      try {
        await File(existing).delete();
      } catch (_) {
        // Already gone.
      }
    }
    await _saveIndex();
  }

  Future<void> _saveIndex() async {
    final data = <String, String>{};
    _overrides.forEach((key, path) {
      data[key] = p.basename(path);
    });
    try {
      await File(p.join(_dir.path, 'index.json')).writeAsString(jsonEncode(data));
    } catch (_) {
      // Covers can be rebuilt; failing to persist is not fatal.
    }
  }

  /// Dominant, readable accent color for a cover.
  Future<Color?> accentFor(String? path) async {
    if (path == null || path.isEmpty) return null;
    if (_accents.containsKey(path)) return _accents[path];
    Color? result;
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 48,
        targetHeight: 48,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      codec.dispose();
      if (data != null) {
        result = _dominant(data.buffer.asUint8List());
      }
    } catch (_) {
      result = null;
    }
    _accents[path] = result;
    return result;
  }

  Color? _dominant(Uint8List rgba) {
    final buckets = <int, List<int>>{};
    for (var i = 0; i + 3 < rgba.length; i += 4) {
      final r = rgba[i];
      final g = rgba[i + 1];
      final b = rgba[i + 2];
      final a = rgba[i + 3];
      if (a < 200) continue;
      final maxV = math.max(r, math.max(g, b));
      final minV = math.min(r, math.min(g, b));
      final saturation = maxV == 0 ? 0.0 : (maxV - minV) / maxV;
      final luminance = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255;
      if (saturation < 0.16 || luminance < 0.10 || luminance > 0.92) continue;
      final key = ((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4);
      final bucket = buckets.putIfAbsent(key, () => [0, 0, 0, 0]);
      bucket[0] += r;
      bucket[1] += g;
      bucket[2] += b;
      bucket[3] += 1;
    }
    if (buckets.isEmpty) return null;
    List<int>? best;
    for (final bucket in buckets.values) {
      if (best == null || bucket[3] > best[3]) best = bucket;
    }
    if (best == null || best[3] == 0) return null;
    final color = Color.fromARGB(
      255,
      best[0] ~/ best[3],
      best[1] ~/ best[3],
      best[2] ~/ best[3],
    );
    // Keep accents readable on dark and light canvases.
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withSaturation(hsl.saturation.clamp(0.34, 0.72))
        .withLightness(hsl.lightness.clamp(0.42, 0.64))
        .toColor();
  }

  static String _hash(String value) {
    var h = 0x811C9DC5;
    for (final unit in value.codeUnits) {
      h ^= unit;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }
}
