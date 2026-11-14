import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/services.dart';
import '../../data/models/playlist.dart';
import '../../data/models/track.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../pages/backup_page.dart';
import '../pages/equalizer_page.dart';
import '../pages/playlist_page.dart';
import '../pages/recap_page.dart';
import '../pages/saved_pages.dart';
import '../pages/settings_pages.dart';
import '../pages/stats_page.dart';
import '../widgets/brand.dart';
import '../widgets/page_header.dart';
import '../widgets/playlist_sheets.dart';
import '../widgets/pressable.dart';
import '../widgets/settings_rows.dart';

/// The listener's shelf: playlists, saved lists, and every setting.
class YouPage extends StatelessWidget {
  const YouPage({super.key});

  @override
  Widget build(BuildContext context) {
    final services = Services.i;
    return AnimatedBuilder(
      animation: Listenable.merge([
        services.playlists,
        services.favorites,
        services.stats,
        services.library,
      ]),
      builder: (context, _) {
        final playlists = services.playlists.items;
        final favorites = services.favorites.length;
        final mixes = services.stats.mixes;

        return PageScaffold(
          child: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(
                child: PageHeader(kicker: 'Your space', title: 'You'),
              ),
              const SliverToBoxAdapter(child: _ProfileCard()),
              SliverToBoxAdapter(
                child: SectionTitle(
                  title: 'Playlists',
                  action: 'New',
                  onAction: () => _createPlaylist(context),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  // Tall enough for the cover, the name, and the song count
                  // without clipping at larger font scales.
                  height: 196,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.page,
                    ),
                    children: [
                      for (final playlist in playlists)
                        _PlaylistCard(
                          playlist: playlist,
                          onTap: () => Navigator.of(context).push(
                            PlaylistPage.route(playlist.id),
                          ),
                        ),
                      _NewPlaylistCard(
                        onTap: () => _createPlaylist(context),
                      ),
                    ],
                  ),
                ),
              ),
              if (playlists.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.page,
                      10,
                      Space.page,
                      0,
                    ),
                    child: Text(
                      'A playlist is just a list you decide on. Make one for '
                      'a drive, a mood, or one perfect song.',
                      style: context.sans(
                        size: 12,
                        color: context.c.textFaint,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 26)),
              SliverToBoxAdapter(
                child: SettingsGroup(
                  title: 'Saved',
                  children: [
                    SettingsRow(
                      icon: Icons.favorite_rounded,
                      title: 'Favorites',
                      subtitle: plural(favorites, 'song'),
                      onTap: () =>
                          Navigator.of(context).push(FavoritesPage.route()),
                    ),
                    SettingsRow(
                      icon: Icons.history_rounded,
                      title: 'Recently played',
                      subtitle: 'Pick up where you left off',
                      onTap: () =>
                          Navigator.of(context).push(RecentlyPlayedPage.route()),
                    ),
                    SettingsRow(
                      icon: Icons.repeat_rounded,
                      title: 'On repeat',
                      subtitle: 'Your most played this week',
                      onTap: () =>
                          Navigator.of(context).push(OnRepeatPage.route()),
                    ),
                    for (final mix in mixes.where((mix) => mix.id != 'repeat').take(2))
                      SettingsRow(
                        icon: mix.kind == 'fresh'
                            ? Icons.new_releases_outlined
                            : Icons.auto_awesome_rounded,
                        title: mix.title,
                        subtitle: mix.subtitle,
                        onTap: () => Navigator.of(context).push(
                          MixPage.route(mix.id),
                        ),
                      ),
                    SettingsRow(
                      icon: Icons.insights_rounded,
                      title: 'Listening stats',
                      subtitle: 'Minutes, streaks and top artists',
                      onTap: () =>
                          Navigator.of(context).push(StatsPage.route()),
                    ),
                    SettingsRow(
                      icon: Icons.auto_stories_rounded,
                      title: 'Weekly recap',
                      subtitle: 'A story worth sharing',
                      onTap: () =>
                          Navigator.of(context).push(RecapPage.route()),
                    ),
                  ],
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 26)),
              SliverToBoxAdapter(
                child: SettingsGroup(
                  title: 'Settings',
                  children: [
                    SettingsRow(
                      icon: Icons.palette_outlined,
                      title: 'Appearance',
                      subtitle: 'Theme, accent and haptics',
                      onTap: () =>
                          Navigator.of(context).push(AppearancePage.route()),
                    ),
                    SettingsRow(
                      icon: Icons.play_circle_outline_rounded,
                      title: 'Playback',
                      subtitle: 'Fades, headphones and goal',
                      onTap: () =>
                          Navigator.of(context).push(PlaybackPage.route()),
                    ),
                    SettingsRow(
                      icon: Icons.library_music_outlined,
                      title: 'Library',
                      subtitle: 'Folders, scan and short clips',
                      onTap: () => Navigator.of(context)
                          .push(LibrarySettingsPage.route()),
                    ),
                    SettingsRow(
                      icon: Icons.equalizer_rounded,
                      title: 'Equalizer',
                      subtitle: 'Bands, presets and bass',
                      onTap: () =>
                          Navigator.of(context).push(EqualizerPage.route()),
                    ),
                    SettingsRow(
                      icon: Icons.inventory_2_outlined,
                      title: 'Backup',
                      subtitle: 'Move your setup to a new phone',
                      onTap: () =>
                          Navigator.of(context).push(BackupPage.route()),
                    ),
                    SettingsRow(
                      icon: Icons.info_outline_rounded,
                      title: 'About',
                      subtitle: 'Version, licenses and privacy',
                      onTap: () =>
                          Navigator.of(context).push(AboutPage.route()),
                    ),
                  ],
                ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: Space.shellClear),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _createPlaylist(BuildContext context) async {
    final name = await showPlaylistNameSheet(context);
    if (name == null) return;
    final playlist = await Services.i.playlists.create(name);
    if (!context.mounted) return;
    Navigator.of(context).push(PlaylistPage.route(playlist.id));
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final services = Services.i;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.page, 4, Space.page, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.xl),
          border: Border.all(color: c.line),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [c.accent.withValues(alpha: 0.16), c.surface],
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: c.canvas.withValues(alpha: 0.35),
                shape: BoxShape.circle,
                border: Border.all(color: c.line),
              ),
              child: const Center(child: BrandMark(size: 28)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Local listening', style: context.serif(size: 21)),
                  const SizedBox(height: 4),
                  Text(
                    '${plural(services.library.songCount, 'song')} · '
                    '${formatTotal(services.library.totalDurationMs)}',
                    style: context.sans(size: 12.5, color: c.textDim),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.pill),
                border: Border.all(color: c.line),
              ),
              child: Text(
                'PRIVATE',
                style: context.overline(color: c.textDim, spacing: 1.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard({required this.playlist, required this.onTap});

  final Playlist playlist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final services = Services.i;
    final tracks = playlist.trackIds
        .map(services.library.trackById)
        .whereType<Track>()
        .toList();
    return Pressable(
      onTap: onTap,
      child: SizedBox(
        width: 138,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PlaylistCover(
              playlist: playlist,
              tracks: tracks,
              size: 138,
              radius: 18,
            ),
            const SizedBox(height: 8),
            Text(
              playlist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.sans(size: 13, weight: 600),
            ),
            const SizedBox(height: 2),
            Text(
              plural(playlist.length, 'song'),
              style: context.sans(
                size: 11,
                color: context.c.textDim,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewPlaylistCard extends StatelessWidget {
  const _NewPlaylistCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 138,
        height: 138,
        margin: const EdgeInsets.only(left: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.lineStrong),
          color: c.surfaceHigh,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, size: 26, color: c.accent),
            const SizedBox(height: 8),
            Text(
              'New playlist',
              style: context.sans(
                size: 12,
                weight: 600,
                color: c.textDim,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
