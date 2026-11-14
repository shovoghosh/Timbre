import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../core/format.dart';
import '../../core/haptics.dart';
import '../../core/services.dart';
import '../../data/library/library_controller.dart';
import '../../data/library/library_channel.dart';
import '../../data/library/import_service.dart';
import '../../data/models/track.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../widgets/buttons.dart';
import '../widgets/cover.dart';
import '../widgets/page_header.dart';
import '../widgets/segmented.dart';
import '../widgets/sheets.dart';
import '../widgets/snack.dart';
import '../widgets/song_menu.dart';
import '../widgets/track_tile.dart';
import 'collection_page.dart';

enum LibraryView { songs, albums, artists, folders }

/// The library: songs with an A-Z jump, albums, artists, and the folders that
/// are allowed in.
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  LibraryView _view = LibraryView.songs;
  final _items = ItemScrollController();
  final _positions = ItemPositionsListener.create();

  List<_Row> _rows = const [];
  List<Track>? _rowsSource;
  SortMode? _rowsSort;
  final Map<String, int> _letterIndex = {};
  String? _activeLetter;

  LibraryController get _library => Services.i.library;

  @override
  void initState() {
    super.initState();
    final library = _library;
    if (library.status == LibraryStatus.empty && !library.isScanning) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scan(first: true));
    }
  }

  void _ensureRows() {
    final tracks = _library.tracks;
    if (identical(tracks, _rowsSource) && _rowsSort == _library.sort) return;
    _rowsSource = tracks;
    _rowsSort = _library.sort;
    final rows = <_Row>[];
    _letterIndex.clear();
    if (_library.sort == SortMode.title) {
      String? last;
      for (final track in tracks) {
        final letter = track.indexLetter;
        if (letter != last) {
          _letterIndex[letter] = rows.length;
          rows.add(_Row.header(letter));
          last = letter;
        }
        rows.add(_Row.track(track));
      }
    } else {
      for (final track in tracks) {
        rows.add(_Row.track(track));
      }
    }
    _rows = rows;
  }

  Future<void> _scan({bool first = false}) async {
    final ok = await _library.scan();
    if (!mounted) return;
    if (ok) {
      final count = _library.songCount;
      showSnack(context, count == 0 ? 'No songs found' : 'Found ${plural(count, 'song')}');
      return;
    }
    final status = _library.status;
    if (status == LibraryStatus.denied) {
      showSnack(
        context,
        _library.permissionBlocked
            ? 'Music access is blocked. Open settings to allow it.'
            : 'Timbre needs access to your audio files.',
        actionLabel: _library.permissionBlocked ? 'Settings' : null,
        onAction: _library.permissionBlocked
            ? () => _library.openSystemSettings()
            : null,
      );
    } else if (_library.error != null) {
      showSnack(context, _library.error!);
    }
  }

  Future<void> _import() async {
    final outcome = await const ImportService().pickAndImport();
    if (!mounted) return;
    if (outcome.cancelled) return;
    if (outcome.hasTracks) {
      await _library.addTracks(outcome.tracks);
      if (!mounted) return;
      showSnack(
        context,
        'Imported ${plural(outcome.tracks.length, 'song')}'
        '${outcome.failed > 0 ? ', ${outcome.failed} skipped' : ''}',
      );
    } else {
      showSnack(context, 'Nothing was imported');
    }
  }

  void _jumpTo(String letter) {
    final index = _letterIndex[letter];
    if (index == null) return;
    Haptics.tap();
    setState(() => _activeLetter = letter);
    _items.scrollTo(
      index: index + _leadingItems,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    );
  }

  static const _leadingItems = 3;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _library,
      builder: (context, _) {
        _ensureRows();
        final library = _library;
        return PageScaffold(
          child: Stack(
            children: [
              if (_view == LibraryView.songs)
                _songsView(library)
              else
                _otherView(library),
              if (_view == LibraryView.songs &&
                  library.hasMusic &&
                  _letterIndex.isNotEmpty)
                Positioned(
                  right: 2,
                  top: 220,
                  bottom: 220,
                  child: _AlphabetBar(
                    letters: _letterIndex.keys.toList(),
                    active: _activeLetter,
                    onLetter: _jumpTo,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _header() {
    return PageHeader(
      kicker: switch (_view) {
        LibraryView.songs => 'Your collection',
        LibraryView.albums => 'Grouped by album',
        LibraryView.artists => 'Grouped by artist',
        LibraryView.folders => 'Where music lives',
      },
      title: 'Library',
      trailing: CircleButton(
        icon: Icons.more_horiz_rounded,
        tooltip: 'Library options',
        onPressed: _showLibraryMenu,
      ),
    );
  }

  Widget _segmented() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.page, 2, Space.page, 4),
      child: Segmented<LibraryView>(
        items: const [
          (LibraryView.songs, 'Songs'),
          (LibraryView.albums, 'Albums'),
          (LibraryView.artists, 'Artists'),
          (LibraryView.folders, 'Folders'),
        ],
        selected: _view,
        onSelect: (value) {
          setState(() => _view = value);
        },
      ),
    );
  }

  Widget _summary(LibraryController library) {
    final text = switch (_view) {
      LibraryView.songs =>
        '${plural(library.songCount, 'song')} · ${formatTotal(library.totalDurationMs)}',
      LibraryView.albums => plural(library.albumCount, 'album'),
      LibraryView.artists => plural(library.artistCount, 'artist'),
      LibraryView.folders => plural(library.folderCount, 'folder'),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.page, 8, Space.page, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: context.numeric(size: 11.5, color: context.c.textDim),
            ),
          ),
          if (library.isScanning)
            Row(
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: context.c.accent,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Scanning',
                  style: context.sans(
                    size: 11.5,
                    color: context.c.textDim,
                  ),
                ),
              ],
            )
          else if (_view == LibraryView.songs)
            TextAction(
              label: 'Sort',
              icon: Icons.swap_vert_rounded,
              onPressed: _showSortSheet,
            ),
        ],
      ),
    );
  }

  Widget _songsView(LibraryController library) {
    if (library.status == LibraryStatus.scanning && library.isEmpty) {
      return _ScanningBody(header: _header(), segmented: _segmented());
    }
    if (!library.hasMusic) {
      return _emptyBody(library);
    }
    return ScrollablePositionedList.builder(
      itemScrollController: _items,
      itemPositionsListener: _positions,
      padding: EdgeInsets.zero,
      itemCount: _leadingItems + _rows.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return _header();
        if (index == 1) return _segmented();
        if (index == 2) return _summary(library);
        if (index == _leadingItems + _rows.length) {
          return const SizedBox(height: Space.shellClear);
        }
        final row = _rows[index - _leadingItems];
        if (row.letter != null) {
          return _LetterHeader(letter: row.letter!);
        }
        final track = row.track!;
        return TrackTile(
          track: track,
          playing: Services.i.playback.current?.id == track.id,
          onTap: () => Services.i.playback.playQueue(
            library.tracks,
            startIndex: library.tracks.indexOf(track),
            label: 'Library',
          ),
          onMore: () => showSongMenu(context, track),
        );
      },
    );
  }

  Widget _otherView(LibraryController library) {
    if (library.status == LibraryStatus.scanning && library.isEmpty) {
      return _ScanningBody(header: _header(), segmented: _segmented());
    }
    if (!library.hasMusic) return _emptyBody(library);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _header()),
        SliverToBoxAdapter(child: _segmented()),
        SliverToBoxAdapter(child: _summary(library)),
        if (_view == LibraryView.albums) _albumsSliver(library),
        if (_view == LibraryView.artists) _artistsSliver(library),
        if (_view == LibraryView.folders) _foldersSliver(library),
        const SliverToBoxAdapter(child: SizedBox(height: Space.shellClear)),
      ],
    );
  }

  Widget _albumsSliver(LibraryController library) {
    final albums = library.albums;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(Space.page, 4, Space.page, 0),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 20,
          crossAxisSpacing: 14,
          childAspectRatio: 0.7,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final album = albums[index];
            return _AlbumCard(
              album: album,
              onTap: () {
                Navigator.of(context).push(
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
                );
              },
            );
          },
          childCount: albums.length,
        ),
      ),
    );
  }

  Widget _artistsSliver(LibraryController library) {
    final artists = library.artists;
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final artist = artists[index];
          return _ArtistRow(
            artist: artist,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CollectionPage(
                    title: artist.name,
                    subtitle: plural(artist.albumCount, 'album'),
                    tracks: artist.tracks,
                    label: artist.name,
                    seed: artist.name,
                    coverPath: artist.tracks
                        .map((t) => t.coverPath)
                        .firstWhere((p) => p != null, orElse: () => null),
                    roundedCover: true,
                  ),
                ),
              );
            },
          );
        },
        childCount: artists.length,
      ),
    );
  }

  Widget _foldersSliver(LibraryController library) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final folder = library.folders[index];
          final hidden = library.isFolderHidden(folder.path);
          return _FolderRow(
            path: folder.path,
            count: library.folderSongCount(folder.path),
            included: !hidden,
            onToggle: (value) => library.setFolderHidden(folder.path, !value),
            onOpen: () {
              final tracks = library.tracksInFolder(folder.path);
              if (tracks.isEmpty) return;
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CollectionPage(
                    title: folder.name,
                    subtitle: folder.path,
                    tracks: tracks,
                    label: folder.name,
                    seed: folder.path,
                    coverPath: tracks
                        .map((t) => t.coverPath)
                        .firstWhere((p) => p != null, orElse: () => null),
                  ),
                ),
              );
            },
          );
        },
        childCount: library.folders.length,
      ),
    );
  }

  Widget _emptyBody(LibraryController library) {
    final denied = library.status == LibraryStatus.denied;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _header()),
        SliverToBoxAdapter(child: _segmented()),
        SliverToBoxAdapter(
          child: EmptyState(
            icon: denied ? Icons.lock_outline_rounded : Icons.library_music_outlined,
            title: denied
                ? 'Music access is off'
                : (library.status == LibraryStatus.failed
                      ? 'Could not read your music'
                      : 'No songs yet'),
            message: denied
                ? 'Timbre only reads the audio files you allow. Nothing is uploaded.'
                : (library.error ??
                      'Scan your phone to bring in the music you already own. '
                          'You choose which folders count.'),
            primaryLabel: denied && library.permissionBlocked
                ? 'Open settings'
                : 'Scan my music',
            onPrimary: () async {
              if (denied && library.permissionBlocked) {
                await library.openSystemSettings();
              } else {
                await _scan();
              }
            },
            secondaryLabel: 'Import files',
            onSecondary: _import,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: Space.shellClear)),
      ],
    );
  }

  void _showSortSheet() {
    showTimbreSheet<void>(
      context,
      child: AnimatedBuilder(
        animation: _library,
        builder: (context, _) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SheetHeader(
                title: 'Sort songs',
                subtitle: 'Applies to the whole library.',
              ),
              for (final mode in SortMode.values)
                SheetTile(
                  icon: switch (mode) {
                    SortMode.recent => Icons.schedule_rounded,
                    SortMode.title => Icons.sort_by_alpha_rounded,
                    SortMode.artist => Icons.person_outline_rounded,
                    SortMode.album => Icons.album_outlined,
                    SortMode.duration => Icons.timelapse_rounded,
                    SortMode.year => Icons.calendar_today_outlined,
                  },
                  label: mode.label,
                  selected: _library.sort == mode,
                  trailing: _library.sort == mode
                      ? Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: context.c.accent,
                        )
                      : null,
                  onTap: () {
                    _library.setSort(mode);
                    Navigator.of(context).pop();
                  },
                ),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  }

  void _showLibraryMenu() {
    showTimbreSheet<void>(
      context,
      child: AnimatedBuilder(
        animation: _library,
        builder: (context, _) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SheetHeader(title: 'Library'),
              if (LibraryChannel.isSupported)
                SheetTile(
                  icon: Icons.radar_rounded,
                  label: 'Scan again',
                  subtitle: _library.lastScanAt == 0
                      ? 'Look for new music'
                      : 'Last scan ${formatDay(_library.lastScanAt)}',
                  onTap: () {
                    Navigator.of(context).pop();
                    _scan();
                  },
                ),
              SheetTile(
                icon: Icons.file_download_outlined,
                label: 'Import files',
                subtitle: 'Copy songs into Timbre',
                onTap: () {
                  Navigator.of(context).pop();
                  _import();
                },
              ),
              SheetTile(
                icon: Icons.folder_open_rounded,
                label: 'Choose folders',
                subtitle: 'Include or skip folders',
                onTap: () {
                  Navigator.of(context).pop();
                  setState(() => _view = LibraryView.folders);
                },
              ),
              SheetTile(
                icon: Icons.timer_outlined,
                label: 'Hide short clips',
                subtitle: 'Keep voice notes and ringtones out',
                trailing: Switch(
                  value: _library.hideShortClips,
                  onChanged: (value) => _library.setHideShortClips(value),
                ),
                onTap: () =>
                    _library.setHideShortClips(!_library.hideShortClips),
              ),
              SheetTile(
                icon: Icons.delete_outline_rounded,
                label: 'Clear library',
                destructive: true,
                subtitle: 'Keeps the files on your phone',
                onTap: () async {
                  Navigator.of(context).pop();
                  final confirmed = await _confirmClear();
                  if (confirmed == true) await _library.clearLibrary();
                },
              ),
              const SizedBox(height: 14),
            ],
          );
        },
      ),
    );
  }

  Future<bool?> _confirmClear() {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Clear the library?'),
          content: const Text(
            'Timbre forgets the songs it found. Your audio files stay where '
            'they are. You can scan again at any time.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Clear',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Row {
  const _Row.header(this.letter) : track = null;
  const _Row.track(this.track) : letter = null;

  final String? letter;
  final Track? track;
}

class _LetterHeader extends StatelessWidget {
  const _LetterHeader({required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.fromLTRB(Space.page, 16, Space.page, 4),
      color: context.c.canvas,
      child: Row(
        children: [
          Text(
            letter,
            style: context.serif(size: 20, color: context.c.accent),
          ),
          const SizedBox(width: 10),
          Expanded(child: Divider(color: context.c.line)),
        ],
      ),
    );
  }
}

class _ScanningBody extends StatelessWidget {
  const _ScanningBody({required this.header, required this.segmented});

  final Widget header;
  final Widget segmented;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        header,
        segmented,
        const SizedBox(height: 80),
        Center(
          child: Column(
            children: [
              SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: context.c.accent,
                ),
              ),
              const SizedBox(height: 18),
              Text('Reading your library', style: context.serif(size: 22)),
              const SizedBox(height: 6),
              Text(
                'This only happens on your phone.',
                style: context.sans(size: 13, color: context.c.textDim),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AlphabetBar extends StatefulWidget {
  const _AlphabetBar({
    required this.letters,
    required this.onLetter,
    this.active,
  });

  final List<String> letters;
  final ValueChanged<String> onLetter;
  final String? active;

  @override
  State<_AlphabetBar> createState() => _AlphabetBarState();
}

class _AlphabetBarState extends State<_AlphabetBar> {
  String? _touching;

  void _handle(Offset local, double height) {
    if (widget.letters.isEmpty) return;
    final index = ((local.dy / height) * widget.letters.length)
        .floor()
        .clamp(0, widget.letters.length - 1);
    final letter = widget.letters[index];
    if (letter == _touching) return;
    _touching = letter;
    setState(() {});
    widget.onLetter(letter);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: (details) =>
              _handle(details.localPosition, height),
          onVerticalDragUpdate: (details) =>
              _handle(details.localPosition, height),
          onVerticalDragEnd: (_) => setState(() => _touching = null),
          onTapDown: (details) => _handle(details.localPosition, height),
          onTapUp: (_) => setState(() => _touching = null),
          child: Container(
            width: 24,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final letter in widget.letters)
                  Text(
                    letter,
                    style: context.sans(
                      size: 9,
                      weight:
                          _touching == letter || widget.active == letter
                          ? 700
                          : 500,
                      color: _touching == letter || widget.active == letter
                          ? c.accent
                          : c.textFaint,
                      height: 1,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AlbumCard extends StatelessWidget {
  const _AlbumCard({required this.album, required this.onTap});

  final AlbumGroup album;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Cover(
              path: album.coverPath,
              seed: album.key,
              title: album.title,
              artist: album.artist,
              radius: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            album.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.sans(size: 13.5, weight: 600),
          ),
          const SizedBox(height: 2),
          Text(
            album.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.sans(size: 11.5, color: c.textDim),
          ),
        ],
      ),
    );
  }
}

class _ArtistRow extends StatelessWidget {
  const _ArtistRow({required this.artist, required this.onTap});

  final ArtistGroup artist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tracks = artist.tracks;
    final cover = tracks
        .map((t) => t.coverPath)
        .firstWhere((p) => p != null, orElse: () => null);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.page, vertical: 8),
        child: Row(
          children: [
            Cover(
              path: cover,
              seed: artist.name,
              title: artist.name,
              size: 52,
              radius: 26,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    artist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.sans(size: 14.5, weight: 600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${plural(artist.albumCount, 'album')} · ${plural(tracks.length, 'song')}',
                    style: context.sans(size: 11.5, color: c.textDim),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: c.textFaint),
          ],
        ),
      ),
    );
  }
}

class _FolderRow extends StatelessWidget {
  const _FolderRow({
    required this.path,
    required this.count,
    required this.included,
    required this.onToggle,
    required this.onOpen,
  });

  final String path;
  final int count;
  final bool included;
  final ValueChanged<bool> onToggle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final name = path.split('/').last;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.page, vertical: 7),
      child: Row(
        children: [
          GestureDetector(
            onTap: onOpen,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: c.surfaceHigh,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.line),
              ),
              child: Icon(
                Icons.folder_rounded,
                size: 21,
                color: included ? c.accent : c.textFaint,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: onOpen,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.sans(size: 14, weight: 500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    path == name ? 'Storage root' : path,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.sans(size: 11, color: c.textFaint),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            plural(count, 'song'),
            style: context.numeric(size: 10.5, color: c.textFaint),
          ),
          const SizedBox(width: 6),
          Switch.adaptive(value: included, onChanged: onToggle),
        ],
      ),
    );
  }
}
