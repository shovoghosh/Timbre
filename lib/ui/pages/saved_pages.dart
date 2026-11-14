import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/services.dart';
import '../../data/models/track.dart';
import '../../theme/type.dart';
import '../widgets/page_header.dart';
import 'collection_page.dart';

/// A plain list of saved songs with a friendly empty state.
class SavedTracksPage extends StatelessWidget {
  const SavedTracksPage({
    super.key,
    required this.title,
    required this.kicker,
    required this.tracks,
    required this.seed,
    this.subtitle,
    this.emptyTitle = 'Nothing saved yet',
    this.emptyMessage = 'Songs you save show up here.',
    this.emptyIcon = Icons.favorite_border_rounded,
  });

  final String title;
  final String kicker;
  final String? subtitle;
  final List<Track> tracks;
  final String seed;
  final String emptyTitle;
  final String emptyMessage;
  final IconData emptyIcon;

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) {
      return PageScaffold(
        wash: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                    ],
                  ),
                  PageHeader(kicker: kicker, title: title),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: EmptyState(
                icon: emptyIcon,
                title: emptyTitle,
                message: emptyMessage,
              ),
            ),
          ],
        ),
      );
    }
    final cover = tracks
        .map((track) => track.coverPath)
        .firstWhere((path) => path != null, orElse: () => null);
    return CollectionPage(
      title: title,
      subtitle: subtitle ?? plural(tracks.length, 'song'),
      tracks: tracks,
      label: title,
      seed: seed,
      coverPath: cover,
    );
  }
}

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const FavoritesPage());

  @override
  Widget build(BuildContext context) {
    final services = Services.i;
    return AnimatedBuilder(
      animation: Listenable.merge([services.favorites, services.library]),
      builder: (context, _) {
        final tracks = services.library.tracks
            .where((track) => services.favorites.contains(track.id))
            .toList();
        return SavedTracksPage(
          title: 'Favorites',
          kicker: 'Kept close',
          tracks: tracks,
          seed: 'favorites',
          emptyTitle: 'No favorites yet',
          emptyMessage:
              'Tap the heart on a song or in the player and it lands here.',
          emptyIcon: Icons.favorite_border_rounded,
        );
      },
    );
  }
}

class RecentlyPlayedPage extends StatelessWidget {
  const RecentlyPlayedPage({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const RecentlyPlayedPage());

  @override
  Widget build(BuildContext context) {
    final services = Services.i;
    return AnimatedBuilder(
      animation: services.stats,
      builder: (context, _) {
        final seen = <String>{};
        final tracks = <Track>[];
        for (final event in services.stats.recentPlays) {
          if (!seen.add(event.trackId)) continue;
          final track = services.library.trackById(event.trackId);
          if (track != null) tracks.add(track);
        }
        return SavedTracksPage(
          title: 'Recently played',
          kicker: 'Pick up again',
          tracks: tracks,
          seed: 'recent',
          emptyTitle: 'Nothing played yet',
          emptyMessage: 'Play something and it appears here.',
          emptyIcon: Icons.history_rounded,
        );
      },
    );
  }
}

class OnRepeatPage extends StatelessWidget {
  const OnRepeatPage({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const OnRepeatPage());

  @override
  Widget build(BuildContext context) {
    final services = Services.i;
    return AnimatedBuilder(
      animation: services.stats,
      builder: (context, _) {
        final entries = services.stats.stats.tracks;
        final tracks = <Track>[];
        for (final entry in entries) {
          if (entry.trackId == null) continue;
          final track = services.library.trackById(entry.trackId!);
          if (track != null) tracks.add(track);
        }
        return SavedTracksPage(
          title: 'On repeat',
          kicker: 'This week',
          tracks: tracks,
          seed: 'repeat',
          subtitle: 'Your most played songs this week',
          emptyTitle: 'No plays this week',
          emptyMessage: 'A few songs in and this list fills itself.',
          emptyIcon: Icons.repeat_rounded,
        );
      },
    );
  }
}

/// A generated mix, opened from Home or You.
class MixPage extends StatelessWidget {
  const MixPage({super.key, required this.mixId});

  final String mixId;

  static Route<void> route(String id) =>
      MaterialPageRoute<void>(builder: (_) => MixPage(mixId: id));

  @override
  Widget build(BuildContext context) {
    final services = Services.i;
    return AnimatedBuilder(
      animation: services.stats,
      builder: (context, _) {
        final index = services.stats.mixes.indexWhere(
          (mix) => mix.id == mixId,
        );
        if (index < 0) {
          return PageScaffold(
            wash: false,
            child: Center(
              child: Text(
                'This mix is not ready yet.',
                style: context.sans(size: 14, color: context.c.textDim),
              ),
            ),
          );
        }
        final mix = services.stats.mixes[index];
        return CollectionPage(
          title: mix.title,
          subtitle: mix.subtitle,
          tracks: mix.tracks,
          label: mix.title,
          seed: mix.id,
          coverPath: mix.tracks
              .map((track) => track.coverPath)
              .firstWhere((path) => path != null, orElse: () => null),
        );
      },
    );
  }
}
