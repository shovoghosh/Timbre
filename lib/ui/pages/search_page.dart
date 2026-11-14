import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/services.dart';
import '../../data/library/library_controller.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../pages/collection_page.dart';
import '../widgets/brand.dart';
import '../widgets/buttons.dart';
import '../widgets/cover.dart';
import '../widgets/page_header.dart';
import '../widgets/track_tile.dart';

/// Search across the local library. Results group as albums, artists and songs.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  SearchResults _results = const SearchResults();
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      setState(() {
        _query = value;
        _results = Services.i.library.search(value);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final services = Services.i;
    final c = context.c;
    final hasText = _query.trim().isNotEmpty;
    return AnimatedBuilder(
      animation: Listenable.merge([services.library, services.playback]),
      builder: (context, _) {
        return PageScaffold(
          child: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(
                child: PageHeader(kicker: 'Find anything', title: 'Search'),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Space.page, 6, Space.page, 0),
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(Radii.pill),
                      border: Border.all(
                        color: _focus.hasFocus ? c.accentLine : c.line,
                      ),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 16),
                        Icon(Icons.search_rounded, size: 20, color: c.textFaint),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            focusNode: _focus,
                            textInputAction: TextInputAction.search,
                            style: context.sans(size: 15),
                            cursorColor: c.accent,
                            onChanged: _onChanged,
                            decoration: InputDecoration(
                              isCollapsed: true,
                              border: InputBorder.none,
                              hintText: 'Songs, albums, artists',
                              hintStyle: context.sans(
                                size: 15,
                                color: c.textFaint,
                              ),
                            ),
                          ),
                        ),
                        if (hasText)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: CircleButton(
                              icon: Icons.close_rounded,
                              size: 30,
                              iconSize: 16,
                              onPressed: () {
                                _controller.clear();
                                setState(() {
                                  _query = '';
                                  _results = const SearchResults();
                                });
                              },
                            ),
                          )
                        else
                          const SizedBox(width: 12),
                      ],
                    ),
                  ),
                ),
              ),
              if (!hasText)
                const SliverToBoxAdapter(child: _SearchIntro())
              else if (_results.isEmpty)
                SliverToBoxAdapter(
                  child: EmptyState(
                    compact: true,
                    icon: Icons.manage_search_rounded,
                    title: 'No matches',
                    message: 'Try a shorter word, or the artist name.',
                    secondaryLabel: 'Clear',
                    onSecondary: () {
                      _controller.clear();
                      setState(() {
                        _query = '';
                        _results = const SearchResults();
                      });
                    },
                  ),
                )
              else ...[
                if (_results.albums.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _AlbumRow(results: _results),
                  ),
                if (_results.artists.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _ArtistRow(results: _results),
                  ),
                if (_results.songs.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: SectionTitle(
                      title: 'Songs',
                      action: '${_results.songs.length} found',
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final track = _results.songs[index];
                        final playing =
                            services.playback.current?.id == track.id;
                        return TrackTile(
                          track: track,
                          playing: playing,
                          onTap: () => services.playback.playQueue(
                            _results.songs,
                            startIndex: index,
                            label: 'Search',
                          ),
                        );
                      },
                      childCount: _results.songs.length,
                    ),
                  ),
                ],
              ],
              const SliverToBoxAdapter(
                child: SizedBox(height: Space.shellClear),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SearchIntro extends StatelessWidget {
  const _SearchIntro();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(top: 44),
      child: Column(
        children: [
          const BrandMark(size: 44),
          const SizedBox(height: 18),
          Text(
            'Search your own shelf',
            style: context.serif(size: 24),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Everything runs on this phone, so results appear as fast as you type.',
              textAlign: TextAlign.center,
              style: context.sans(
                size: 13.5,
                color: c.textDim,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlbumRow extends StatelessWidget {
  const _AlbumRow({required this.results});

  final SearchResults results;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: 'Albums', size: 19),
        SizedBox(
          height: 170,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Space.page),
            itemCount: results.albums.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final album = results.albums[index];
              return GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CollectionPage(
                      title: album.title,
                      subtitle: album.artist,
                      tracks: album.tracks,
                      label: album.title,
                      seed: album.key,
                      coverPath: album.coverPath,
                    ),
                  ),
                ),
                child: SizedBox(
                  width: 118,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Cover(
                        path: album.coverPath,
                        seed: album.key,
                        title: album.title,
                        artist: album.artist,
                        size: 118,
                        radius: 14,
                      ),
                      const SizedBox(height: 7),
                      Text(
                        album.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.sans(size: 12.5, weight: 600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        album.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.sans(size: 11, color: c.textDim),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ArtistRow extends StatelessWidget {
  const _ArtistRow({required this.results});

  final SearchResults results;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: 'Artists', size: 19),
        SizedBox(
          height: 82,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Space.page),
            itemCount: results.artists.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final artist = results.artists[index];
              final cover = artist.tracks
                  .map((track) => track.coverPath)
                  .firstWhere((path) => path != null, orElse: () => null);
              return GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CollectionPage(
                      title: artist.name,
                      subtitle: plural(artist.tracks.length, 'song'),
                      tracks: artist.tracks,
                      label: artist.name,
                      seed: artist.name,
                      coverPath: cover,
                      roundedCover: true,
                    ),
                  ),
                ),
                child: Container(
                  width: 210,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.c.surface,
                    borderRadius: BorderRadius.circular(Radii.lg),
                    border: Border.all(color: context.c.line),
                  ),
                  child: Row(
                    children: [
                      Cover(
                        path: cover,
                        seed: artist.name,
                        title: artist.name,
                        size: 46,
                        radius: 23,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              artist.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.sans(size: 13, weight: 600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              plural(artist.albumCount, 'album'),
                              style: context.sans(
                                size: 10.5,
                                color: context.c.textDim,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
