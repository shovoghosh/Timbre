import 'package:flutter_test/flutter_test.dart';
import 'package:timbre/data/library/lyrics_store.dart';

void main() {
  group('parseLyrics', () {
    test('reads timestamps and sorts lines', () {
      final lyrics = parseLyrics(
        '[00:12.00]Streetlights hum\n[00:22.50]Every window\n[00:33.00]I keep the city',
      );
      expect(lyrics.synced, isTrue);
      expect(lyrics.lines.length, 3);
      expect(lyrics.lines.first.time, const Duration(seconds: 12));
      expect(lyrics.lines[1].time, const Duration(seconds: 22, milliseconds: 500));
      expect(lyrics.indexAt(const Duration(seconds: 13)), 0);
      expect(lyrics.indexAt(const Duration(seconds: 25)), 1);
      expect(lyrics.indexAt(const Duration(seconds: 40)), 2);
    });

    test('plain text stays unsynced', () {
      final lyrics = parseLyrics('One line\nAnother line\n');
      expect(lyrics.synced, isFalse);
      expect(lyrics.lines.length, 2);
      expect(lyrics.indexAt(const Duration(seconds: 5)), -1);
    });

    test('multiple stamps on one line create separate lines', () {
      final lyrics = parseLyrics('[00:01.00][00:10.00]Again');
      expect(lyrics.lines.length, 2);
      expect(lyrics.lines[1].time, const Duration(seconds: 10));
    });

    test('blank stamps become a note glyph', () {
      final lyrics = parseLyrics('[00:05.00]');
      expect(lyrics.lines.single.text, '♪');
    });
  });
}
