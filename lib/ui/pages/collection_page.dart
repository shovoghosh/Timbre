import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/services.dart';
import '../../data/models/track.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../widgets/buttons.dart';
import '../widgets/cover.dart';
import '../widgets/song_menu.dart';
import '../widgets/track_tile.dart';

/// One page for anything that holds tracks: an album, an artist, a playlist or
/// a folder. Consistent header, play controls and track list.
class CollectionPage extends StatelessWidget {
  const CollectionPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.tracks,
    required this.label,
    this.seed = '',
    this.coverPath,
    this.description,
    this.roundedCover = false,
    this.trailing,
    this.onMore,
    this.onTrackMore,
  });

  final String title;
  final String subtitle;
  final List<Track> tracks;
  final String label;
  final String seed;
  final String? coverPath;
  final String? description;
  final bool roundedCover;
  final Widget? trailing;
  final VoidCallback? onMore;
  final void Function(BuildContext context, Track track)? onTrackMore;

  @override
  Widget build(BuildContext context) {
    final services = Services.i;
    final playback = services.playback;
    final c = context.c;

    return Scaffold(
      backgroundColor: c.canvas,
      body: AnimatedBuilder(
        animation: playback,
        builder: (context, _) {
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 300,
                backgroundColor: c.canvas,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                leadingWidth: 64,
                leading: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Center(
                    child: CircleButton(
                      icon: Icons.arrow_back_rounded,
                      size: 38,
                      iconSize: 20,
                      onPressed: () => Navigator.of(context).maybePop(),
                      tooltip: 'Back',
                    ),
                  ),
                ),
                actions: [
                  ?trailing,
                  if (onMore != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Center(
                        child: CircleButton(
                          icon: Icons.more_horiz_rounded,
                          size: 38,
                          iconSize: 20,
                          onPressed: onMore,
                          tooltip: 'More',
                        ),
                      ),
                    ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: _Header(
                    title: title,
                    subtitle: subtitle,
                    coverPath: coverPath,
                    seed: seed.isEmpty ? title : seed,
                    rounded: roundedCover,
                    trackCount: tracks.length,
                    durationMs: tracks.fold(0, (sum, t) => sum + t.durationMs),
                    description: description,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.page,
                    8,
                    Space.page,
                    6,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: PrimaryButton(
                          label: 'Play',
                          icon: Icons.play_arrow_rounded,
                          expand: true,
                          onPressed: tracks.isEmpty
                              ? null
                              : () => playback.playQueue(
                                  tracks,
                                  startIndex: 0,
                                  label: label,
                                ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      CircleButton(
                        icon: Icons.shuffle_rounded,
                        size: 52,
                        iconSize: 21,
                        tooltip: 'Shuffle',
                        onPressed: tracks.isEmpty
                            ? null
                            : () async {
                                await playback.setShuffle(true);
                                await playback.playQueue(
                                  tracks,
                                  startIndex: 0,
                                  label: label,
                                );
                              },
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final track = tracks[index];
                  final isCurrent = playback.current?.id == track.id;
                  return TrackTile(
                    track: track,
                    playing: isCurrent,
                    showCover: true,
                    onTap: () => playback.playQueue(
                      tracks,
                      startIndex: index,
                      label: label,
                    ),
                    onMore: () {
                      if (onTrackMore != null) {
                        onTrackMore!(context, track);
                      } else {
                        showSongMenu(context, track);
                      }
                    },
                  );
                }, childCount: tracks.length),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.page,
                    18,
                    Space.page,
                    Space.bottomClear,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 13,
                        color: c.textFaint,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Plays from your phone',
                        style: context.sans(size: 11.5, color: c.textFaint),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.coverPath,
    required this.seed,
    required this.rounded,
    required this.trackCount,
    required this.durationMs,
    this.description,
  });

  final String title;
  final String subtitle;
  final String? coverPath;
  final String seed;
  final bool rounded;
  final int trackCount;
  final int durationMs;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final pair = coverColorsFor(seed);
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                pair.$2.withValues(alpha: 0.45),
                c.canvas.withValues(alpha: 0.9),
                c.canvas,
              ],
              stops: const [0, 0.72, 1],
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.page, 56, Space.page, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(rounded ? 60 : 20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 28,
                        offset: const Offset(0, 14),
                        spreadRadius: -8,
                      ),
                    ],
                  ),
                  child: Cover(
                    path: coverPath,
                    seed: seed,
                    title: title,
                    artist: subtitle,
                    size: 132,
                    radius: rounded ? 66 : 20,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'COLLECTION',
                        style: context.overline(
                          color: c.textFaint,
                          spacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.serif(size: 27, height: 1.06),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.sans(size: 13, color: c.textDim),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${plural(trackCount, 'song')} · ${formatTotal(durationMs)}',
                        style: context.numeric(size: 11, color: c.textFaint),
                      ),
                      if (description != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.sans(
                            size: 12,
                            color: c.textDim,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
