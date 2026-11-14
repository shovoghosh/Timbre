import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/services.dart';
import '../../data/models/playlist.dart';
import '../../data/models/track.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../widgets/cover.dart';
import '../widgets/sheets.dart';

/// Asks for a playlist name. Returns null when cancelled.
Future<String?> showPlaylistNameSheet(
  BuildContext context, {
  String initial = '',
  String title = 'New playlist',
}) {
  final controller = TextEditingController(text: initial);
  return showTimbreSheet<String>(
    context,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SheetHeader(
            title: title,
            subtitle: 'Give it a name you will recognise later.',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              style: context.sans(size: 16),
              decoration: InputDecoration(
                hintText: 'Late night drive',
                hintStyle: context.sans(size: 16, color: context.c.textFaint),
                filled: true,
                fillColor: context.c.surfaceHigh,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Radii.md),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (value) =>
                  Navigator.of(context).pop(value.trim().isEmpty ? null : value.trim()),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'You can rename it any time.',
                    style: context.sans(size: 12, color: context.c.textFaint),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel', style: context.sans(size: 14)),
                ),
                const SizedBox(width: 4),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: context.c.accent,
                    foregroundColor: context.c.onAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Radii.pill),
                    ),
                  ),
                  onPressed: () {
                    final value = controller.text.trim();
                    Navigator.of(context).pop(value.isEmpty ? null : value);
                  },
                  child: Text('Create', style: context.sans(size: 14, weight: 600)),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Sheet for adding one track to a playlist, or making a new one.
Future<void> showAddToPlaylist(BuildContext context, Track track) async {
  final store = Services.i.playlists;
  final messenger = ScaffoldMessenger.of(context);

  await showTimbreSheet<void>(
    context,
    child: AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetHeader(
              title: 'Add to playlist',
              subtitle: track.title,
              trailing: SheetChip(plural(store.length, 'playlist')),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 10),
                children: [
                  SheetTile(
                    icon: Icons.add_rounded,
                    label: 'New playlist',
                    subtitle: 'Start one with this song',
                    onTap: () async {
                      final name = await showPlaylistNameSheet(context);
                      if (name == null) return;
                      await store.create(name, trackIds: [track.id]);
                      if (context.mounted) Navigator.of(context).pop();
                      messenger
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(content: Text('Made "$name"')),
                        );
                    },
                  ),
                  if (store.items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                      child: Text(
                        'No playlists yet. A playlist is just a list you decide on.',
                        style: context.sans(
                          size: 13,
                          color: context.c.textDim,
                          height: 1.5,
                        ),
                      ),
                    ),
                  for (final playlist in store.items)
                    SheetTile(
                      icon: Icons.queue_music_rounded,
                      label: playlist.name,
                      subtitle: plural(playlist.length, 'song'),
                      selected: playlist.trackIds.contains(track.id),
                      trailing: playlist.trackIds.contains(track.id)
                          ? Icon(
                              Icons.check_circle_rounded,
                              size: 20,
                              color: context.c.accent,
                            )
                          : null,
                      onTap: () async {
                        if (playlist.trackIds.contains(track.id)) {
                          await store.removeTrack(playlist.id, track.id);
                          messenger
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              SnackBar(
                                content: Text('Removed from ${playlist.name}'),
                              ),
                            );
                        } else {
                          await store.addTracks(playlist.id, [track.id]);
                          messenger
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              SnackBar(
                                content: Text('Added to ${playlist.name}'),
                              ),
                            );
                        }
                        if (context.mounted) Navigator.of(context).pop();
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

/// Small cover for a playlist: custom art, first song's cover, or brand art.
class PlaylistCover extends StatelessWidget {
  const PlaylistCover({
    super.key,
    required this.playlist,
    required this.tracks,
    this.size = 56,
    this.radius = 10,
  });

  final Playlist playlist;
  final List<Track> tracks;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final custom = playlist.coverPath;
    if (custom != null && custom.isNotEmpty) {
      return Cover(path: custom, size: size, radius: radius);
    }
    final withCover = tracks.where(
      (track) => (track.coverPath ?? '').isNotEmpty,
    );
    if (withCover.isNotEmpty) {
      final track = withCover.first;
      return Cover(
        path: track.coverPath,
        seed: track.id,
        title: track.title,
        artist: track.displayArtist,
        size: size,
        radius: radius,
      );
    }
    return Cover(
      seed: playlist.id,
      title: playlist.name,
      size: size,
      radius: radius,
    );
  }
}
