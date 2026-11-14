import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// Tags and technical facts read straight from an audio file.
///
/// Written from scratch so the app does not depend on a native tag library and
/// so iOS imports can read the same fields Android gets from MediaStore.
class AudioTags {
  const AudioTags({
    this.title,
    this.artist,
    this.album,
    this.albumArtist,
    this.genre,
    this.year = 0,
    this.trackNo = 0,
    this.discNo = 0,
    this.durationMs = 0,
    this.lyrics,
    this.picture,
    this.pictureMime,
  });

  final String? title;
  final String? artist;
  final String? album;
  final String? albumArtist;
  final String? genre;
  final int year;
  final int trackNo;
  final int discNo;
  final int durationMs;
  final String? lyrics;
  final Uint8List? picture;
  final String? pictureMime;

  bool get hasAnything =>
      (title ?? '').isNotEmpty ||
      (artist ?? '').isNotEmpty ||
      (album ?? '').isNotEmpty ||
      picture != null;
}

abstract final class TagReader {
  static Future<AudioTags> read(String path) async {
    final file = File(path);
    if (!file.existsSync()) return const AudioTags();
    RandomAccessFile? raf;
    try {
      raf = await file.open();
      final length = await raf.length();
      final head = _readAt(raf, 0, math.min(16, length));
      if (_startsWith(head, 'ID3')) {
        return await _readId3(raf, length);
      }
      if (_startsWith(head, 'fLaC')) {
        return await _readFlac(raf, length);
      }
      if (head.length >= 12 && _ascii(head, 4, 4) == 'ftyp') {
        return await _readMp4(raf, length);
      }
      if (_startsWith(head, 'OggS')) {
        return await _readOgg(raf, length);
      }
      if (head.length >= 12 &&
          _ascii(head, 0, 4) == 'RIFF' &&
          _ascii(head, 8, 4) == 'WAVE') {
        return await _readWav(raf, length);
      }
      return await _readMp3WithoutTag(raf, length);
    } catch (_) {
      return const AudioTags();
    } finally {
      await raf?.close();
    }
  }

  static Future<Uint8List?> picture(String path) async {
    final tags = await read(path);
    return tags.picture;
  }

  // ---------------------------------------------------------------- ID3 (MP3)

  static Future<AudioTags> _readId3(RandomAccessFile raf, int fileLength) async {
    final header = _readAt(raf, 0, 10);
    final version = header[3];
    final flags = header[5];
    final size = _syncsafe(header, 6);
    final tagBytes = _readAt(raf, 10, size);

    var offset = 0;
    if ((flags & 0x40) != 0 && tagBytes.length > 4) {
      // Extended header. Skip it using its own size field.
      final extSize = version == 4
          ? _syncsafe(tagBytes, 0)
          : _u32be(tagBytes, 0) + 4;
      offset = extSize.clamp(0, tagBytes.length);
    }

    String? title;
    String? artist;
    String? album;
    String? albumArtist;
    String? genre;
    String? lyrics;
    var year = 0;
    var track = 0;
    var disc = 0;
    var duration = 0;
    Uint8List? picture;
    String? pictureMime;

    final isV22 = version == 2;
    while (offset + (isV22 ? 6 : 10) <= tagBytes.length) {
      final id = _ascii(tagBytes, offset, isV22 ? 3 : 4);
      if (!RegExp(r'^[A-Z0-9]{3,4}$').hasMatch(id)) break;
      final frameSize = isV22
          ? ((tagBytes[offset + 3] << 16) |
                (tagBytes[offset + 4] << 8) |
                tagBytes[offset + 5])
          : (version == 4
                ? _syncsafe(tagBytes, offset + 4)
                : _u32be(tagBytes, offset + 4));
      final headerSize = isV22 ? 6 : 10;
      if (frameSize <= 0 || offset + headerSize + frameSize > tagBytes.length) {
        break;
      }
      final body = Uint8List.sublistView(
        tagBytes,
        offset + headerSize,
        offset + headerSize + frameSize,
      );

      switch (id) {
        case 'TIT2':
        case 'TT2':
          title = _decodeTextFrame(body);
        case 'TPE1':
        case 'TP1':
          artist = _decodeTextFrame(body);
        case 'TALB':
        case 'TAL':
          album = _decodeTextFrame(body);
        case 'TPE2':
        case 'TP2':
          albumArtist = _decodeTextFrame(body);
        case 'TCON':
        case 'TCO':
          genre = _decodeTextFrame(body)?.replaceAll(RegExp(r'^\(\d+\)'), '');
        case 'TRCK':
        case 'TRK':
          track = _firstNumber(_decodeTextFrame(body));
        case 'TPOS':
        case 'TPA':
          disc = _firstNumber(_decodeTextFrame(body));
        case 'TYER':
        case 'TYE':
        case 'TDRC':
          year = _firstNumber(_decodeTextFrame(body));
        case 'TLEN':
        case 'TLE':
          duration = _firstNumber(_decodeTextFrame(body));
        case 'USLT':
        case 'ULT':
          lyrics = _decodeLyricsFrame(body);
        case 'APIC':
        case 'PIC':
          final parsed = _parseApic(body, isV22);
          if (parsed != null) {
            picture = parsed.$1;
            pictureMime = parsed.$2;
          }
      }

      offset += headerSize + frameSize;
      if (version == 3) {
        // ID3v2.3 padding is zero bytes.
        while (offset < tagBytes.length && tagBytes[offset] == 0) {
          offset++;
        }
      }
    }

    if (duration <= 0) {
      duration = _mp3Duration(raf, fileLength, 10 + size);
    }

    return AudioTags(
      title: _clean(title),
      artist: _clean(artist),
      album: _clean(album),
      albumArtist: _clean(albumArtist),
      genre: _clean(genre),
      year: year,
      trackNo: track,
      discNo: disc,
      durationMs: duration,
      lyrics: _clean(lyrics, multiline: true),
      picture: picture,
      pictureMime: pictureMime,
    );
  }

  static (Uint8List, String)? _parseApic(Uint8List body, bool v22) {
    if (body.isEmpty) return null;
    final encoding = body[0];
    var index = 1;
    String mime;
    if (v22) {
      if (body.length < 5) return null;
      final format = _ascii(body, 1, 3).toLowerCase();
      mime = format == 'png' ? 'image/png' : 'image/jpeg';
      index = 4;
    } else {
      final end = body.indexOf(0, index);
      if (end < 0) return null;
      mime = latin1.decode(body.sublist(index, end));
      index = end + 1;
    }
    if (index >= body.length) return null;
    index++; // picture type
    // Description is null terminated in the frame's encoding.
    index = _skipEncodedText(body, index, encoding);
    if (index >= body.length) return null;
    final data = Uint8List.sublistView(body, index);
    if (data.isEmpty) return null;
    return (data, mime.isEmpty ? 'image/jpeg' : mime);
  }

  static String? _decodeLyricsFrame(Uint8List body) {
    if (body.length < 5) return null;
    final encoding = body[0];
    // 3 bytes language, then a described text field.
    var index = 4;
    index = _skipEncodedText(body, index, encoding);
    if (index >= body.length) return null;
    return _decodeEncoded(body.sublist(index), encoding);
  }

  // ---------------------------------------------------------------------- FLAC

  static Future<AudioTags> _readFlac(
    RandomAccessFile raf,
    int fileLength,
  ) async {
    var offset = 4;
    String? title;
    String? artist;
    String? album;
    String? albumArtist;
    String? genre;
    String? lyrics;
    var year = 0;
    var track = 0;
    var disc = 0;
    var duration = 0;
    Uint8List? picture;
    String? pictureMime;

    while (offset + 4 <= fileLength) {
      final header = _readAt(raf, offset, 4);
      if (header.length < 4) break;
      final isLast = (header[0] & 0x80) != 0;
      final type = header[0] & 0x7f;
      final length = (header[1] << 16) | (header[2] << 8) | header[3];
      offset += 4;
      if (length < 0 || offset + length > fileLength) break;

      if (type == 0 && length >= 34) {
        final info = _readAt(raf, offset, 34);
        // Sample rate: 20 bits at byte 10, channels 3 bits, bps 5, total 36.
        final sampleRate =
            ((info[10] & 0xff) << 12) |
            ((info[11] & 0xff) << 4) |
            ((info[12] & 0xf0) >> 4);
        var totalSamples = 0;
        for (var i = 13; i <= 17; i++) {
          totalSamples = (totalSamples << 8) | info[i];
        }
        if (sampleRate > 0 && totalSamples > 0) {
          duration = (totalSamples * 1000 / sampleRate).round();
        }
      } else if (type == 4) {
        final data = _readAt(raf, offset, length);
        final comments = _parseVorbisComments(data);
        title ??= comments['TITLE'];
        artist ??= comments['ARTIST'];
        album ??= comments['ALBUM'];
        albumArtist ??= comments['ALBUMARTIST'] ?? comments['ALBUM ARTIST'];
        genre ??= comments['GENRE'];
        lyrics ??= comments['LYRICS'] ?? comments['UNSYNCEDLYRICS'];
        if (year == 0) year = _firstNumber(comments['DATE'] ?? comments['YEAR']);
        if (track == 0) track = _firstNumber(comments['TRACKNUMBER']);
        if (disc == 0) disc = _firstNumber(comments['DISCNUMBER']);
        final encoded = comments['METADATA_BLOCK_PICTURE'];
        if (encoded != null && picture == null) {
          final parsed = _parseFlacPicture(
            base64.decode(encoded.trim()),
          );
          if (parsed != null) {
            picture = parsed.$1;
            pictureMime = parsed.$2;
          }
        }
      } else if (type == 6) {
        final data = _readAt(raf, offset, length);
        final parsed = _parseFlacPicture(data);
        if (parsed != null) {
          picture = parsed.$1;
          pictureMime = parsed.$2;
        }
      }

      offset += length;
      if (isLast) break;
    }

    return AudioTags(
      title: _clean(title),
      artist: _clean(artist),
      album: _clean(album),
      albumArtist: _clean(albumArtist),
      genre: _clean(genre),
      year: year,
      trackNo: track,
      discNo: disc,
      durationMs: duration,
      lyrics: _clean(lyrics, multiline: true),
      picture: picture,
      pictureMime: pictureMime,
    );
  }

  static (Uint8List, String)? _parseFlacPicture(Uint8List data) {
    if (data.length < 8) return null;
    var index = 4;
    final mimeLength = _u32be(data, index);
    index += 4;
    if (index + mimeLength > data.length) return null;
    final mime = latin1.decode(data.sublist(index, index + mimeLength));
    index += mimeLength;
    if (index + 4 > data.length) return null;
    final descriptionLength = _u32be(data, index);
    index += 4 + descriptionLength;
    // width, height, depth, colors
    index += 16;
    if (index + 4 > data.length) return null;
    final pictureLength = _u32be(data, index);
    index += 4;
    if (index + pictureLength > data.length || pictureLength <= 0) return null;
    return (Uint8List.sublistView(data, index, index + pictureLength), mime);
  }

  // ----------------------------------------------------------------------- MP4

  static Future<AudioTags> _readMp4(RandomAccessFile raf, int fileLength) async {
    final moov = _findAtom(raf, 0, fileLength, 'moov');
    if (moov == null) return const AudioTags();

    var duration = 0;
    final mvhd = _findAtom(raf, moov.$1, moov.$2, 'mvhd');
    if (mvhd != null) {
      final data = _readAt(raf, mvhd.$1, math.min(mvhd.$2, 32));
      if (data.length >= 20) {
        if (data[0] == 1 && data.length >= 32) {
          final timescale = _u32be(data, 20);
          final units = _u64be(data, 24);
          if (timescale > 0) {
            duration = (units * 1000 / timescale).round();
          }
        } else {
          final timescale = _u32be(data, 12);
          final units = _u32be(data, 16);
          if (timescale > 0) {
            duration = (units * 1000 / timescale).round();
          }
        }
      }
    }

    final meta = _findAtom(raf, moov.$1, moov.$2, 'meta');
    final ilst = meta == null
        ? _findNestedAtom(raf, moov.$1, moov.$2, ['udta', 'meta', 'ilst'])
        : _findAtom(raf, meta.$1 + 4, meta.$2 - 4, 'ilst');
    if (ilst == null) return AudioTags(durationMs: duration);

    String? title;
    String? artist;
    String? album;
    String? albumArtist;
    String? genre;
    String? lyrics;
    var year = 0;
    var track = 0;
    var disc = 0;
    Uint8List? picture;
    String? pictureMime;

    var cursor = ilst.$1;
    final end = ilst.$1 + ilst.$2;
    while (cursor + 8 <= end) {
      final header = _readAt(raf, cursor, 8);
      if (header.length < 8) break;
      var size = _u32be(header, 0);
      final type = _ascii(header, 4, 4);
      var headerSize = 8;
      if (size == 1) {
        final large = _readAt(raf, cursor + 8, 8);
        if (large.length < 8) break;
        size = _u64be(large, 0);
        headerSize = 16;
      }
      if (size < headerSize || cursor + size > end) break;

      final data = _findAtom(raf, cursor + headerSize, size - headerSize, 'data');
      if (data != null) {
        final payload = _readAt(raf, data.$1, data.$2);
        if (payload.length > 8) {
          final flag = _u32be(payload, 0) & 0xffffff;
          final value = payload.sublist(8);
          switch (type) {
            case '\u00a9nam':
              title = _mp4Text(value);
            case '\u00a9ART':
              artist = _mp4Text(value);
            case '\u00a9alb':
              album = _mp4Text(value);
            case 'aART':
              albumArtist = _mp4Text(value);
            case '\u00a9gen':
              genre = _mp4Text(value);
            case '\u00a9lyr':
              lyrics = _mp4Text(value);
            case '\u00a9day':
              year = _firstNumber(_mp4Text(value));
            case 'trkn':
              if (value.length >= 4) track = _u16be(value, 2);
            case 'disk':
              if (value.length >= 4) disc = _u16be(value, 2);
            case 'covr':
              picture = Uint8List.fromList(value);
              pictureMime = flag == 14 ? 'image/png' : 'image/jpeg';
          }
        }
      }
      cursor += size;
    }

    return AudioTags(
      title: _clean(title),
      artist: _clean(artist),
      album: _clean(album),
      albumArtist: _clean(albumArtist),
      genre: _clean(genre),
      year: year,
      trackNo: track,
      discNo: disc,
      durationMs: duration,
      lyrics: _clean(lyrics, multiline: true),
      picture: picture,
      pictureMime: pictureMime,
    );
  }

  static String _mp4Text(Uint8List value) {
    if (value.length < 8) return utf8.decode(value, allowMalformed: true);
    // Some writers prefix a 4 byte length plus 4 byte encoding.
    final length = _u32be(value, 0);
    if (length > 0 && length + 8 <= value.length + 4) {
      final start = 8;
      if (start + length <= value.length) {
        return utf8.decode(value.sublist(start, start + length), allowMalformed: true);
      }
    }
    return utf8.decode(value, allowMalformed: true);
  }

  static (int, int)? _findAtom(
    RandomAccessFile raf,
    int start,
    int length,
    String target,
  ) {
    var cursor = start;
    final end = start + length;
    while (cursor + 8 <= end) {
      final header = _readAt(raf, cursor, 8);
      if (header.length < 8) return null;
      var size = _u32be(header, 0);
      var type = _ascii(header, 4, 4);
      var headerSize = 8;
      if (size == 1) {
        final large = _readAt(raf, cursor + 8, 8);
        if (large.length < 8) return null;
        size = _u64be(large, 0);
        headerSize = 16;
      } else if (size == 0) {
        size = end - cursor;
      }
      if (size < headerSize) return null;
      if (type == target) {
        return (cursor + headerSize, size - headerSize);
      }
      cursor += size;
    }
    return null;
  }

  static (int, int)? _findNestedAtom(
    RandomAccessFile raf,
    int start,
    int length,
    List<String> path,
  ) {
    var range = (start, length);
    for (var i = 0; i < path.length; i++) {
      final found = _findAtom(raf, range.$1, range.$2, path[i]);
      if (found == null) return null;
      // The meta atom carries four bytes of version flags.
      range = path[i] == 'meta'
          ? (found.$1 + 4, found.$2 - 4)
          : (found.$1, found.$2);
    }
    return range;
  }

  // ----------------------------------------------------------------------- OGG

  static Future<AudioTags> _readOgg(RandomAccessFile raf, int fileLength) async {
    final firstPage = _readOggPage(raf, 0, fileLength);
    if (firstPage == null) return const AudioTags();
    final packets = firstPage.$3;
    var sampleRate = 0;
    String? title;
    String? artist;
    String? album;
    String? albumArtist;
    String? genre;
    String? lyrics;
    var year = 0;
    var track = 0;
    Uint8List? picture;
    String? pictureMime;

    if (packets.isNotEmpty && packets.first.length >= 16) {
      final id = packets.first;
      if (id[0] == 0x01) {
        sampleRate =
            id[12] | (id[13] << 8) | (id[14] << 16) | (id[15] << 24);
      }
    }

    for (final packet in packets.skip(1)) {
      if (packet.isEmpty || packet[0] != 0x03) continue;
      final comments = _parseVorbisComments(
        Uint8List.sublistView(packet, 7),
      );
      title = comments['TITLE'];
      artist = comments['ARTIST'];
      album = comments['ALBUM'];
      albumArtist = comments['ALBUMARTIST'] ?? comments['ALBUM ARTIST'];
      genre = comments['GENRE'];
      lyrics = comments['LYRICS'] ?? comments['UNSYNCEDLYRICS'];
      year = _firstNumber(comments['DATE'] ?? comments['YEAR']);
      track = _firstNumber(comments['TRACKNUMBER']);
      final encoded = comments['METADATA_BLOCK_PICTURE'];
      if (encoded != null) {
        try {
          final parsed = _parseFlacPicture(base64.decode(encoded.trim()));
          if (parsed != null) {
            picture = parsed.$1;
            pictureMime = parsed.$2;
          }
        } catch (_) {
          // Ignore bad picture data.
        }
      }
      break;
    }

    var duration = 0;
    if (sampleRate > 0) {
      final lastGranule = _lastOggGranule(raf, fileLength);
      if (lastGranule > 0) {
        duration = (lastGranule * 1000 / sampleRate).round();
      }
    }

    return AudioTags(
      title: _clean(title),
      artist: _clean(artist),
      album: _clean(album),
      albumArtist: _clean(albumArtist),
      genre: _clean(genre),
      year: year,
      trackNo: track,
      durationMs: duration,
      lyrics: _clean(lyrics, multiline: true),
      picture: picture,
      pictureMime: pictureMime,
    );
  }

  static (int, int, List<Uint8List>)? _readOggPage(
    RandomAccessFile raf,
    int offset,
    int fileLength,
  ) {
    final header = _readAt(raf, offset, 27);
    if (header.length < 27 || _ascii(header, 0, 4) != 'OggS') return null;
    final granule = _u64be(header, 6);
    final segments = header[26];
    final table = _readAt(raf, offset + 27, segments);
    if (table.length < segments) return null;
    var dataLength = 0;
    for (final value in table) {
      dataLength += value;
    }
    final data = _readAt(raf, offset + 27 + segments, dataLength);
    final packets = <Uint8List>[];
    var cursor = 0;
    var current = BytesBuilder();
    for (var i = 0; i < segments; i++) {
      final size = table[i];
      if (cursor + size > data.length) break;
      current.add(Uint8List.sublistView(data, cursor, cursor + size));
      cursor += size;
      if (size < 255) {
        packets.add(current.takeBytes());
        current = BytesBuilder();
      }
    }
    if (current.length > 0) packets.add(current.takeBytes());
    return (granule, offset + 27 + segments + dataLength, packets);
  }

  static int _lastOggGranule(RandomAccessFile raf, int fileLength) {
    final window = math.min(fileLength, 65536);
    final start = fileLength - window;
    final bytes = _readAt(raf, start, window);
    for (var i = bytes.length - 27; i >= 0; i--) {
      if (bytes[i] == 0x4f &&
          bytes[i + 1] == 0x67 &&
          bytes[i + 2] == 0x67 &&
          bytes[i + 3] == 0x53) {
        final granule = _u64be(bytes, i + 6);
        if (granule > 0) return granule;
      }
    }
    return 0;
  }

  // ----------------------------------------------------------------------- WAV

  static Future<AudioTags> _readWav(RandomAccessFile raf, int fileLength) async {
    var cursor = 12;
    var byteRate = 0;
    var dataSize = 0;
    String? title;
    String? artist;
    String? album;
    String? albumArtist;
    String? genre;
    var year = 0;
    var track = 0;

    while (cursor + 8 <= fileLength) {
      final header = _readAt(raf, cursor, 8);
      if (header.length < 8) break;
      final id = _ascii(header, 0, 4);
      final size = _u32le(header, 4);
      final bodyStart = cursor + 8;
      if (id == 'fmt ' && size >= 16) {
        final fmt = _readAt(raf, bodyStart, math.min(size, 16));
        if (fmt.length >= 12) byteRate = _u32le(fmt, 8);
      } else if (id == 'data') {
        dataSize = size;
      } else if (id == 'LIST' && size >= 4) {
        final list = _readAt(raf, bodyStart, math.min(size, 65536));
        if (list.length >= 4 && _ascii(list, 0, 4) == 'INFO') {
          var at = 4;
          while (at + 8 <= list.length) {
            final subId = _ascii(list, at, 4);
            final subSize = _u32le(list, at + 4);
            if (at + 8 + subSize > list.length) break;
            final value = latin1
                .decode(list.sublist(at + 8, at + 8 + subSize))
                .replaceAll('\u0000', '')
                .trim();
            switch (subId) {
              case 'INAM':
                title = value;
              case 'IART':
                artist = value;
              case 'IPRD':
                album = value;
              case 'IGNR':
                genre = value;
              case 'ICRD':
                year = _firstNumber(value);
              case 'ITRK':
                track = _firstNumber(value);
            }
            at += 8 + subSize + (subSize.isOdd ? 1 : 0);
          }
        }
      }
      cursor = bodyStart + size + (size.isOdd ? 1 : 0);
    }

    return AudioTags(
      title: _clean(title),
      artist: _clean(artist),
      album: _clean(album),
      albumArtist: _clean(albumArtist),
      genre: _clean(genre),
      year: year,
      trackNo: track,
      durationMs: byteRate > 0 ? (dataSize * 1000 / byteRate).round() : 0,
    );
  }

  // ------------------------------------------------------- MP3 without an ID3

  static Future<AudioTags> _readMp3WithoutTag(
    RandomAccessFile raf,
    int fileLength,
  ) async {
    return AudioTags(durationMs: _mp3Duration(raf, fileLength, 0));
  }

  static int _mp3Duration(RandomAccessFile raf, int fileLength, int audioStart) {
    if (audioStart >= fileLength) return 0;
    final headerBytes = _readAt(raf, audioStart, 4);
    if (headerBytes.length < 4) return 0;
    final header = _u32be(headerBytes, 0);
    if ((header & 0xffe00000) != 0xffe00000) return 0;

    const bitrates = [
      [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0],
      [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, 0],
      [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, 0],
    ];
    const sampleRates = [44100, 48000, 32000, 0];
    final versionBits = (header >> 19) & 0x3;
    final layerBits = (header >> 17) & 0x3;
    final bitrateIndex = (header >> 12) & 0xf;
    final sampleIndex = (header >> 10) & 0x3;
    final padding = (header >> 9) & 0x1;

    final isMpeg1 = versionBits == 3;
    final sampleRate =
        sampleRates[sampleIndex] ~/ (isMpeg1 ? 1 : (versionBits == 2 ? 2 : 4));
    if (sampleRate <= 0 || bitrateIndex == 0 || bitrateIndex == 15) return 0;

    final tableIndex = layerBits == 3 ? 0 : (layerBits == 2 ? 1 : 2);
    final bitrate = bitrates[tableIndex][bitrateIndex] * 1000;
    if (bitrate <= 0) return 0;

    // Xing or Info header gives an exact frame count.
    final sideInfo = isMpeg1 ? (layerBits == 3 ? 32 : 17) : (layerBits == 3 ? 17 : 9);
    final xing = _readAt(raf, audioStart + 4 + sideInfo, 12);
    if (xing.length >= 12) {
      final tag = _ascii(xing, 0, 4);
      if (tag == 'Xing' || tag == 'Info') {
        final flags = _u32be(xing, 4);
        if ((flags & 0x1) != 0) {
          final frames = _u32be(xing, 8);
          final samplesPerFrame = isMpeg1 ? 1152 : 576;
          return (frames * samplesPerFrame * 1000 / sampleRate).round();
        }
      }
    }

    final frameLength = (isMpeg1 ? 144 : 72) * bitrate ~/ sampleRate + padding;
    final audioBytes = fileLength - audioStart;
    if (frameLength <= 0) return 0;
    final duration = audioBytes * 8 * 1000 / bitrate;
    return duration.round();
  }

  // ----------------------------------------------------------------- helpers

  static Map<String, String> _parseVorbisComments(Uint8List data) {
    final result = <String, String>{};
    try {
      var index = 0;
      if (data.length < 8) return result;
      final vendorLength = _u32le(data, index);
      index += 4 + vendorLength;
      if (index + 4 > data.length) return result;
      final count = _u32le(data, index);
      index += 4;
      for (var i = 0; i < count && index + 4 <= data.length; i++) {
        final length = _u32le(data, index);
        index += 4;
        if (index + length > data.length) break;
        final entry = utf8.decode(
          data.sublist(index, index + length),
          allowMalformed: true,
        );
        index += length;
        final split = entry.indexOf('=');
        if (split > 0) {
          result[entry.substring(0, split).toUpperCase()] = entry.substring(
            split + 1,
          );
        }
      }
    } catch (_) {
      // Partial tags are better than none.
    }
    return result;
  }

  static String? _decodeTextFrame(Uint8List body) {
    if (body.isEmpty) return null;
    final encoding = body[0];
    return _decodeEncoded(body.sublist(1), encoding);
  }

  static String _decodeEncoded(Uint8List bytes, int encoding) {
    var data = bytes;
    if (encoding == 3) {
      return _trimNul(utf8.decode(data, allowMalformed: true));
    }
    if (encoding == 1 || encoding == 2) {
      var start = 0;
      var littleEndian = encoding == 1;
      if (encoding == 1 && data.length >= 2) {
        if (data[0] == 0xff && data[1] == 0xfe) {
          start = 2;
          littleEndian = true;
        } else if (data[0] == 0xfe && data[1] == 0xff) {
          start = 2;
          littleEndian = false;
        }
      }
      final codes = <int>[];
      for (var i = start; i + 1 < data.length; i += 2) {
        final value = littleEndian
            ? data[i] | (data[i + 1] << 8)
            : (data[i] << 8) | data[i + 1];
        if (value == 0) break;
        codes.add(value);
      }
      return String.fromCharCodes(codes);
    }
    return _trimNul(latin1.decode(data, allowInvalid: true));
  }

  static int _skipEncodedText(Uint8List data, int start, int encoding) {
    if (encoding == 1 || encoding == 2) {
      var i = start;
      while (i + 1 < data.length) {
        final value = encoding == 1
            ? data[i] | (data[i + 1] << 8)
            : (data[i] << 8) | data[i + 1];
        i += 2;
        if (value == 0) return i;
      }
      return data.length;
    }
    final end = data.indexOf(0, start);
    return end < 0 ? data.length : end + 1;
  }

  static String _trimNul(String value) {
    final zero = value.indexOf('\u0000');
    return zero >= 0 ? value.substring(0, zero) : value;
  }

  static String? _clean(String? value, {bool multiline = false}) {
    if (value == null) return null;
    final trimmed = value
        .replaceAll('\u0000', '')
        .replaceAll('\r\n', '\n')
        .trim();
    if (trimmed.isEmpty) return null;
    if (!multiline) {
      return trimmed.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ');
    }
    return trimmed;
  }

  static int _firstNumber(String? value) {
    if (value == null) return 0;
    final match = RegExp(r'\d+').firstMatch(value);
    if (match == null) return 0;
    return int.tryParse(match.group(0)!) ?? 0;
  }

  static Uint8List _readAt(RandomAccessFile raf, int offset, int length) {
    if (length <= 0) return Uint8List(0);
    raf.setPositionSync(offset);
    return raf.readSync(length);
  }

  static bool _startsWith(Uint8List bytes, String magic) {
    if (bytes.length < magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (bytes[i] != magic.codeUnitAt(i)) return false;
    }
    return true;
  }

  static String _ascii(Uint8List bytes, int start, int length) {
    if (start + length > bytes.length) return '';
    return String.fromCharCodes(bytes.sublist(start, start + length));
  }

  static int _u16be(Uint8List b, int i) => (b[i] << 8) | b[i + 1];

  static int _u32be(Uint8List b, int i) =>
      (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];

  static int _u32le(Uint8List b, int i) =>
      b[i] | (b[i + 1] << 8) | (b[i + 2] << 16) | (b[i + 3] << 24);

  static int _u64be(Uint8List b, int i) =>
      (_u32be(b, i) << 32) | _u32be(b, i + 4);

  static int _syncsafe(Uint8List b, int i) =>
      ((b[i] & 0x7f) << 21) |
      ((b[i + 1] & 0x7f) << 14) |
      ((b[i + 2] & 0x7f) << 7) |
      (b[i + 3] & 0x7f);
}
