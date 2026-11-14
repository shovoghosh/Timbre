import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timbre/data/models/playlist.dart';
import 'package:timbre/data/models/track.dart';
import 'package:timbre/theme/theme.dart';
import 'package:timbre/theme/type.dart';
import 'package:timbre/ui/widgets/brand.dart';
import 'package:timbre/ui/widgets/cover.dart';

void main() {
  group('theme', () {
    test('carries the accent through to the theme extension', () {
      final theme = buildTimbreTheme(
        brightness: Brightness.dark,
        accent: const Color(0xFFE0562D),
        onAccent: Colors.white,
      );
      final colors = theme.extension<TimbreColors>();
      expect(colors, isNotNull);
      expect(colors!.accent, const Color(0xFFE0562D));
      expect(colors.isDark, isTrue);
      final light = buildTimbreTheme(
        brightness: Brightness.light,
        accent: const Color(0xFF2B8C8C),
        onAccent: Colors.white,
      );
      expect(light.extension<TimbreColors>()!.isDark, isFalse);
    });

    test('serif and sans styles stay distinct', () {
      final serif = T.serif(size: 30);
      final sans = T.sans(size: 15);
      expect(serif.fontFamily, 'InstrumentSerif');
      expect(sans.fontFamily, 'InstrumentSans');
      expect(sans.fontVariations?.first.axis, 'wght');
    });
  });

  group('models', () {
    test('track survives a json round trip', () {
      const track = Track(
        id: 'id-1',
        uri: 'content://media/audio/1',
        path: '/storage/emulated/0/Music/one.mp3',
        title: 'One',
        artist: 'Artist',
        album: 'Album',
        durationMs: 123456,
        folder: 'Music',
        trackNo: 3,
        year: 2021,
        genre: 'Rock',
      );
      final copy = Track.fromJson(track.toJson());
      expect(copy.id, track.id);
      expect(copy.title, 'One');
      expect(copy.durationMs, 123456);
      expect(copy.folderName, 'Music');
      expect(copy.indexLetter, 'O');
      expect(copy.displayArtist, 'Artist');
    });

    test('empty artist and album get friendly fallbacks', () {
      const track = Track(
        id: 'x',
        uri: 'file:///a.mp3',
        path: '/a.mp3',
        title: '',
        artist: '',
        album: '',
        durationMs: 0,
      );
      expect(track.displayArtist, 'Unknown artist');
      expect(track.displayAlbum, 'Unknown album');
      expect(track.indexLetter, '#');
    });

    test('playlist json keeps order', () {
      const playlist = Playlist(
        id: 'p1',
        name: 'Drive',
        trackIds: ['a', 'b', 'c'],
        createdAt: 1,
        updatedAt: 2,
      );
      final copy = Playlist.fromJson(playlist.toJson());
      expect(copy.name, 'Drive');
      expect(copy.trackIds, ['a', 'b', 'c']);
    });
  });

  group('cover art', () {
    test('style is deterministic per seed', () {
      expect(coverStyleFor('abc'), coverStyleFor('abc'));
      final colors = coverColorsFor('abc');
      expect(colors.$1, coverColorsFor('abc').$1);
    });
  });

  testWidgets('brand mark renders inside a themed app', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTimbreTheme(
          brightness: Brightness.light,
          accent: const Color(0xFFE0562D),
          onAccent: Colors.white,
        ),
        home: const Scaffold(body: Center(child: BrandMark(size: 44))),
      ),
    );
    expect(find.byType(BrandMark), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
  });
}
