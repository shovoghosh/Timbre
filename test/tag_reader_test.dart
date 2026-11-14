import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:timbre/data/library/tag_reader.dart';

/// Builds a small, valid WAV file with a LIST/INFO block.
Uint8List buildWav({
  String name = 'Built Song',
  String artist = 'Built Artist',
  String album = 'Built Album',
  String year = '2024',
  String track = '3',
  int dataBytes = 88200,
}) {
  final chunks = <String, String>{
    'INAM': name,
    'IART': artist,
    'IPRD': album,
    'ICRD': year,
    'ITRK': track,
  };
  final info = BytesBuilder();
  info.add(ascii('INFO'));
  chunks.forEach((id, value) {
    final bytes = ascii(value);
    info.add(ascii(id));
    info.add(_u32(bytes.length));
    info.add(bytes);
    if (bytes.length.isOdd) info.addByte(0);
  });
  final infoBytes = info.takeBytes();

  final body = BytesBuilder();
  body.add(ascii('WAVE'));
  body.add(ascii('fmt '));
  body.add(_u32(16));
  body.add(_u16(1)); // PCM
  body.add(_u16(1)); // mono
  body.add(_u32(44100));
  body.add(_u32(88200)); // byte rate
  body.add(_u16(2));
  body.add(_u16(16));
  body.add(ascii('LIST'));
  body.add(_u32(infoBytes.length));
  body.add(infoBytes);
  body.add(ascii('data'));
  body.add(_u32(dataBytes));
  body.add(Uint8List(dataBytes));

  final file = BytesBuilder();
  file.add(ascii('RIFF'));
  file.add(_u32(body.length));
  file.add(body.takeBytes());
  return file.takeBytes();
}

List<int> ascii(String value) => value.codeUnits;

Uint8List _u32(int value) =>
    Uint8List(4)..buffer.asByteData().setUint32(0, value, Endian.little);

Uint8List _u16(int value) =>
    Uint8List(2)..buffer.asByteData().setUint16(0, value, Endian.little);

void main() {
  test('reads WAV INFO tags and duration', () async {
    final directory = await Directory.systemTemp.createTemp('timbre-tags');
    final file = File('${directory.path}/built.wav');
    await file.writeAsBytes(buildWav());

    final tags = await TagReader.read(file.path);
    expect(tags.title, 'Built Song');
    expect(tags.artist, 'Built Artist');
    expect(tags.album, 'Built Album');
    expect(tags.year, 2024);
    expect(tags.trackNo, 3);
    expect(tags.durationMs, closeTo(1000, 5));

    await directory.delete(recursive: true);
  });

  test('missing file returns empty tags instead of throwing', () async {
    final tags = await TagReader.read('/definitely/not/here.mp3');
    expect(tags.hasAnything, isFalse);
  });
}
