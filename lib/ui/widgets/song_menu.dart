import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../core/format.dart';
import '../../core/haptics.dart';
import '../../core/services.dart';
import '../../data/models/track.dart';
import '../../theme/type.dart';
import 'cover.dart';
import 'cover_sheet.dart';
import 'playlist_sheets.dart';
import 'sheets.dart';

/// Long-press menu for one song.
Future<void> showSongMenu(BuildContext context, Track track) async {
  final services = Services.i;
  final playback = services.playback;
  final favorites = services.favorites;
  final ratings = services.ratings;
  final messenger = ScaffoldMessenger.of(context);
  final pageContext = context;

  await showTimbreSheet<void>(
    context,
    child: AnimatedBuilder(
      animation: Listenable.merge([favorites, ratings]),
      builder: (context, _) {
        final isFavorite = favorites.contains(track.id);
        final rating = ratings.of(track.id);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetHeader(
              title: track.title,
              subtitle: '${track.displayArtist} · ${track.displayAlbum}',
              trailing: Cover(
                path: track.coverPath,
                seed: track.id,
                title: track.title,
                artist: track.displayArtist,
                size: 52,
                radius: 10,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
              child: Row(
                children: [
                  Text(
                    'RATING',
                    style: context.overline(color: context.c.textFaint),
                  ),
                  const SizedBox(width: 12),
                  for (var star = 1; star <= 5; star++)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        Haptics.tap();
                        ratings.set(track.id, star == rating ? 0 : star);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: Icon(
                          star <= rating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 24,
                          color: star <= rating
                              ? context.c.accent
                              : context.c.textFaint,
                        ),
                      ),
                    ),
                  const Spacer(),
                  if (rating > 0)
                    Text(
                      '$rating/5',
                      style: context.numeric(
                        size: 11,
                        color: context.c.textDim,
                      ),
                    ),
                ],
              ),
            ),
            Divider(height: 1, color: context.c.line, indent: 20, endIndent: 20),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  SheetTile(
                    icon: Icons.favorite_rounded,
                    label: isFavorite ? 'Remove from favorites' : 'Add to favorites',
                    selected: isFavorite,
                    onTap: () async {
                      final added = await favorites.toggle(track.id);
                      if (context.mounted) Navigator.of(context).pop();
                      messenger
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(
                            content: Text(
                              added
                                  ? 'Added to favorites'
                                  : 'Removed from favorites',
                            ),
                          ),
                        );
                    },
                  ),
                  SheetTile(
                    icon: Icons.playlist_play_rounded,
                    label: 'Play next',
                    onTap: () async {
                      await playback.playNext(track);
                      if (context.mounted) Navigator.of(context).pop();
                      messenger
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(content: Text('Playing next')),
                        );
                    },
                  ),
                  SheetTile(
                    icon: Icons.queue_music_rounded,
                    label: 'Add to queue',
                    onTap: () async {
                      await playback.addToQueue(track);
                      if (context.mounted) Navigator.of(context).pop();
                      messenger
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(content: Text('Added to queue')),
                        );
                    },
                  ),
                  SheetTile(
                    icon: Icons.add_circle_outline_rounded,
                    label: 'Add to playlist',
                    onTap: () {
                      Navigator.of(context).pop();
                      showAddToPlaylist(pageContext, track);
                    },
                  ),
                  SheetTile(
                    icon: Icons.image_outlined,
                    label: 'Change cover',
                    subtitle: 'Search online or use your own picture',
                    onTap: () {
                      Navigator.of(context).pop();
                      showCoverSheet(pageContext, track);
                    },
                  ),
                  SheetTile(
                    icon: Icons.share_outlined,
                    label: 'Share',
                    onTap: () async {
                      Navigator.of(context).pop();
                      await SharePlus.instance.share(
                        ShareParams(
                          text:
                              '${track.title} — ${track.displayArtist}\n'
                              'Shared from Timbre',
                          subject: track.title,
                        ),
                      );
                    },
                  ),
                  SheetTile(
                    icon: Icons.info_outline_rounded,
                    label: 'File details',
                    onTap: () {
                      Navigator.of(context).pop();
                      _showFileDetails(pageContext, track);
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}

void _showFileDetails(BuildContext context, Track track) {
  final extension = p.extension(track.path).replaceAll('.', '').toUpperCase();
  final format = extension.isNotEmpty
      ? extension
      : (track.mimeType ?? 'Audio').split('/').last.toUpperCase();
  final rows = <(String, String)>[
    ('Title', track.title),
    ('Artist', track.displayArtist),
    ('Album', track.displayAlbum),
    if (track.year > 0) ('Year', '${track.year}'),
    if (track.trackNo > 0) ('Track', '${track.trackNo}'),
    ('Length', formatDuration(track.durationMs, alwaysHours: true)),
    ('Size', formatBytes(track.sizeBytes)),
    if (track.bitrate > 0) ('Bitrate', '${track.bitrate ~/ 1000} kbps'),
    ('Format', format),
    if (track.folder.isNotEmpty) ('Folder', track.folder),
    ('Path', track.path),
  ];

  showDialog<void>(
    context: context,
    builder: (context) {
      final c = context.c;
      return AlertDialog(
        title: const Text('File details'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final row in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.$1.toUpperCase(),
                          style: context.overline(color: c.textFaint, spacing: 1.1),
                        ),
                        const SizedBox(height: 2),
                        SelectableText(
                          row.$2,
                          style: context.sans(size: 13.5, color: c.text, height: 1.4),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}
