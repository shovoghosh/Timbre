import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../data/models/track.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import 'cover.dart';
import 'playing_bars.dart';
import 'pressable.dart';

/// One song row. Used in lists, search results, playlists and the queue.
class TrackTile extends StatelessWidget {
  const TrackTile({
    super.key,
    required this.track,
    required this.onTap,
    this.onMore,
    this.playing = false,
    this.selected = false,
    this.showCover = true,
    this.number,
    this.subtitleOverride,
    this.trailing,
    this.dense = false,
  });

  final Track track;
  final VoidCallback onTap;
  final VoidCallback? onMore;
  final bool playing;
  final bool selected;
  final bool showCover;
  final int? number;
  final String? subtitleOverride;
  final Widget? trailing;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final subtitle = subtitleOverride ??
        (track.displayAlbum == 'Unknown album'
            ? track.displayArtist
            : '${track.displayArtist} · ${track.displayAlbum}');

    return Pressable(
      onTap: onTap,
      onLongPress: onMore,
      scale: 0.995,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.transparent,
        padding: EdgeInsets.symmetric(
          horizontal: Space.page,
          vertical: dense ? 7 : 9,
        ),
        child: Row(
          children: [
            if (number != null && !showCover)
              SizedBox(
                width: 28,
                child: Text(
                  '$number',
                  style: context.numeric(
                    size: 12.5,
                    color: playing ? c.accent : c.textFaint,
                  ),
                ),
              ),
            if (showCover) ...[
              Cover(
                path: track.coverPath,
                seed: track.id,
                title: track.title,
                artist: track.displayArtist,
                size: dense ? 40 : 46,
                radius: 8,
              ),
              const SizedBox(width: 13),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.sans(
                      size: dense ? 13.5 : 14.5,
                      weight: playing ? 600 : 500,
                      color: playing ? c.accent : c.text,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.sans(
                      size: 12,
                      color: c.textDim,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (trailing != null)
              trailing!
            else if (playing)
              const PlayingBars(size: 16, playing: true)
            else
              DurationLabel(formatDuration(track.durationMs)),
            if (onMore != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onMore,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Icon(
                    Icons.more_vert_rounded,
                    size: 18,
                    color: c.textFaint,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
