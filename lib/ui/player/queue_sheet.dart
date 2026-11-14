import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/haptics.dart';
import '../../core/services.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../widgets/cover.dart';
import '../widgets/sheets.dart';
import '../widgets/track_tile.dart';

/// The queue: what plays next, what already played, and drag to reorder.
Future<void> showQueueSheet(BuildContext context) async {
  final playback = Services.i.playback;

  await showTimbreSheet<void>(
    context,
    child: AnimatedBuilder(
      animation: playback,
      builder: (context, _) {
        final current = playback.current;
        final upNext = playback.upNext;
        final before = playback.playedBefore;
        return SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: Column(
            children: [
              SheetHeader(
                title: 'Up next',
                subtitle: playback.label.isEmpty
                    ? 'Playing from your library'
                    : 'Playing from ${playback.label}',
                trailing: SheetChip(plural(upNext.length, 'song left')),
              ),
              if (current != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, 6),
                  child: Row(
                    children: [
                      Cover(
                        path: current.coverPath,
                        seed: current.id,
                        title: current.title,
                        artist: current.displayArtist,
                        size: 46,
                        radius: 8,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              current.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.sans(
                                size: 14,
                                weight: 600,
                                color: context.c.accent,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Playing now',
                              style: context.sans(
                                size: 11.5,
                                color: context.c.textFaint,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Clear queue',
                        onPressed: () {
                          Haptics.press();
                          playback.clearQueue();
                          Navigator.of(context).pop();
                        },
                        icon: Icon(
                          Icons.delete_sweep_outlined,
                          size: 20,
                          color: context.c.textDim,
                        ),
                      ),
                    ],
                  ),
                ),
              Divider(height: 1, color: context.c.line),
              Expanded(
                child: upNext.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Nothing after this song.\nAdd something from your library.',
                            textAlign: TextAlign.center,
                            style: context.sans(
                              size: 13,
                              color: context.c.textDim,
                              height: 1.6,
                            ),
                          ),
                        ),
                      )
                    : ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        padding: const EdgeInsets.only(bottom: 12),
                        itemCount: upNext.length,
                        onReorderItem: (oldIndex, newIndex) {
                          if (playback.isShuffled) return;
                          playback.reorderQueue(
                            playback.index + 1 + oldIndex,
                            playback.index + 1 + newIndex,
                          );
                        },
                        itemBuilder: (context, i) {
                          final track = upNext[i];
                          return ReorderableDelayedDragStartListener(
                            key: ValueKey('queue-${track.id}-$i'),
                            index: i,
                            child: TrackTile(
                              track: track,
                              dense: true,
                              showCover: true,
                              subtitleOverride: track.displayArtist,
                              onTap: () {
                                playback.seekToIndex(playback.index + 1 + i);
                                Navigator.of(context).pop();
                              },
                              onMore: () {
                                Haptics.tap();
                                playback.removeFromQueue(playback.index + 1 + i);
                              },
                              trailing: Icon(
                                Icons.drag_handle_rounded,
                                size: 18,
                                color: context.c.textFaint,
                              ),
                            ),
                          );
                        },
                      ),
              ),
              if (before.isNotEmpty) ...[
                Divider(height: 1, color: context.c.line),
                SizedBox(
                  height: 132,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                        child: Text(
                          'PLAYED BEFORE',
                          style: context.overline(color: context.c.textFaint),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 8),
                          itemCount: before.length,
                          itemBuilder: (context, i) {
                            final track = before[before.length - 1 - i];
                            return TrackTile(
                              track: track,
                              dense: true,
                              showCover: false,
                              subtitleOverride: track.displayArtist,
                              onTap: () {
                                playback.seekToIndex(playback.index - 1 - i);
                                Navigator.of(context).pop();
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (playback.isShuffled)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                  child: Row(
                    children: [
                      Icon(
                        Icons.shuffle_rounded,
                        size: 14,
                        color: context.c.textFaint,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Shuffle is on, so the order is fixed here.',
                          style: context.sans(
                            size: 11.5,
                            color: context.c.textFaint,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}
