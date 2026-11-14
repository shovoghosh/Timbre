import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/services.dart';
import '../../data/models/playlist.dart';
import '../../data/models/track.dart';
import '../../theme/type.dart';
import '../widgets/playlist_sheets.dart';
import '../widgets/sheets.dart';
import '../widgets/snack.dart';
import 'collection_page.dart';

/// A playlist with its own menu: rename, remove songs, delete.
class PlaylistPage extends StatelessWidget {
  const PlaylistPage({super.key, required this.playlistId});

  final String playlistId;

  static Route<void> route(String id) {
    return MaterialPageRoute<void>(
      builder: (_) => PlaylistPage(playlistId: id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final services = Services.i;
    return AnimatedBuilder(
      animation: Listenable.merge([
        services.playlists,
        services.library,
        services.playback,
      ]),
      builder: (context, _) {
        final playlist = services.playlists.byId(playlistId);
        if (playlist == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Text(
                'This playlist is gone.',
                style: context.sans(size: 14, color: context.c.textDim),
              ),
            ),
          );
        }
        final tracks = playlist.trackIds
            .map(services.library.trackById)
            .whereType<Track>()
            .toList();
        final cover = playlist.coverPath ??
            tracks
                .map((track) => track.coverPath)
                .firstWhere((path) => path != null, orElse: () => null);

        return CollectionPage(
          title: playlist.name,
          subtitle: 'Playlist',
          tracks: tracks,
          label: playlist.name,
          seed: playlist.id,
          coverPath: cover,
          description: playlist.description.isEmpty ? null : playlist.description,
          onMore: () => _showMenu(context, playlist),
          onTrackMore: (sheetContext, track) =>
              _showTrackMenu(sheetContext, playlist, track),
        );
      },
    );
  }

  void _showMenu(BuildContext context, Playlist playlist) {
    final store = Services.i.playlists;
    showTimbreSheet<void>(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetHeader(
            title: playlist.name,
            subtitle: plural(playlist.length, 'song'),
          ),
          SheetTile(
            icon: Icons.edit_outlined,
            label: 'Rename',
            onTap: () async {
              final name = await showPlaylistNameSheet(
                context,
                initial: playlist.name,
                title: 'Rename playlist',
              );
              if (name != null) await store.rename(playlist.id, name);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          SheetTile(
            icon: Icons.playlist_add_rounded,
            label: 'Add songs',
            subtitle: 'Pick songs from your library',
            onTap: () {
              Navigator.of(context).pop();
              _showAddSongs(context, playlist);
            },
          ),
          SheetTile(
            icon: Icons.delete_outline_rounded,
            label: 'Delete playlist',
            destructive: true,
            subtitle: 'The songs stay in your library',
            onTap: () async {
              Navigator.of(context).pop();
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete this playlist?'),
                  content: Text(
                    '"${playlist.name}" will be removed. Your songs are not deleted.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Keep'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(
                        'Delete',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await store.delete(playlist.id);
                if (context.mounted) Navigator.of(context).maybePop();
              }
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  void _showTrackMenu(
    BuildContext context,
    Playlist playlist,
    Track track,
  ) {
    final services = Services.i;
    showTimbreSheet<void>(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetHeader(
            title: track.title,
            subtitle: track.displayArtist,
          ),
          SheetTile(
            icon: Icons.remove_circle_outline_rounded,
            label: 'Remove from this playlist',
            destructive: true,
            onTap: () async {
              await services.playlists.removeTrack(playlist.id, track.id);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          SheetTile(
            icon: Icons.playlist_play_rounded,
            label: 'Play next',
            onTap: () async {
              await services.playback.playNext(track);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          SheetTile(
            icon: Icons.queue_music_rounded,
            label: 'Add to queue',
            onTap: () async {
              await services.playback.addToQueue(track);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  void _showAddSongs(BuildContext context, Playlist playlist) {
    final services = Services.i;
    final candidate = services.library.tracks
        .where((track) => !playlist.trackIds.contains(track.id))
        .toList();
    final selected = <String>{};
    showTimbreSheet<void>(
      context,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: StatefulBuilder(
          builder: (context, setSheetState) {
            return Column(
              children: [
                SheetHeader(
                  title: 'Add songs',
                  subtitle: playlist.name,
                  trailing: SheetChip('${selected.length} picked'),
                ),
                Expanded(
                  child: candidate.isEmpty
                      ? Center(
                          child: Text(
                            'Every song is already in this playlist.',
                            style: context.sans(
                              size: 13,
                              color: context.c.textDim,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: candidate.length,
                          itemBuilder: (context, index) {
                            final track = candidate[index];
                            final isSelected = selected.contains(track.id);
                            return CheckboxListTile.adaptive(
                              value: isSelected,
                              onChanged: (value) {
                                setSheetState(() {
                                  if (value == true) {
                                    selected.add(track.id);
                                  } else {
                                    selected.remove(track.id);
                                  }
                                });
                              },
                              title: Text(
                                track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.sans(size: 14),
                              ),
                              subtitle: Text(
                                track.displayArtist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.sans(
                                  size: 11.5,
                                  color: context.c.textFaint,
                                ),
                              ),
                              activeColor: context.c.accent,
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: context.c.accent,
                        foregroundColor: context.c.onAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      onPressed: selected.isEmpty
                          ? null
                          : () async {
                              await services.playlists.addTracks(
                                playlist.id,
                                selected,
                              );
                              if (context.mounted) {
                                Navigator.of(context).pop();
                                showSnack(
                                  context,
                                  'Added ${plural(selected.length, 'song')}',
                                );
                              }
                            },
                      child: Text(
                        selected.isEmpty
                            ? 'Pick a song'
                            : 'Add ${plural(selected.length, 'song')}',
                        style: context.sans(size: 14, weight: 600),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
