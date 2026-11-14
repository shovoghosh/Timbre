import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/services.dart';
import '../../data/history/stats.dart';
import '../../data/models/track.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../pages/recap_page.dart';
import '../pages/stats_page.dart';
import '../widgets/brand.dart';
import '../widgets/buttons.dart';
import '../widgets/cover.dart';
import '../widgets/page_header.dart';
import '../widgets/playing_bars.dart';
import '../widgets/pressable.dart';
import '../widgets/reveal.dart';
import '../widgets/track_tile.dart';
import '../player/player_page.dart';

/// Home: what to play next and a quick look at the week.
class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.onOpenLibrary,
    required this.onOpenYou,
  });

  final VoidCallback onOpenLibrary;
  final VoidCallback onOpenYou;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'Still up?';
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _dateLine {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
    ];
    final now = DateTime.now();
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final services = Services.i;
    final library = services.library;
    final stats = services.stats;
    return AnimatedBuilder(
      animation: Listenable.merge([library, stats, services.playback]),
      builder: (context, _) {
        final hasMusic = library.hasMusic;
        return PageScaffold(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Reveal(
                  child: PageHeader(
                    kicker: _dateLine,
                    title: _greeting,
                    trailing: CircleButton(
                      icon: Icons.settings_outlined,
                      tooltip: 'Settings',
                      onPressed: onOpenYou,
                    ),
                  ),
                ),
              ),
              if (!hasMusic)
                SliverToBoxAdapter(child: _EmptyHome(onScan: onOpenLibrary))
              else ...[
                SliverToBoxAdapter(
                  child: Reveal(
                    delay: const Duration(milliseconds: 70),
                    child: _ContinueCard(onOpenLibrary: onOpenLibrary),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Reveal(
                    delay: const Duration(milliseconds: 140),
                    child: _WeekCard(
                      stats: stats.stats,
                      onOpen: () =>
                          Navigator.of(context).push(StatsPage.route()),
                    ),
                  ),
                ),
                if (stats.mixes.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Reveal(
                      delay: const Duration(milliseconds: 210),
                      child: _MixesRow(mixes: stats.mixes),
                    ),
                  ),
                SliverToBoxAdapter(child: _RecentlyAdded(onOpenLibrary: onOpenLibrary)),
                if (stats.stats.tracks.isNotEmpty)
                  SliverToBoxAdapter(child: _OnRepeat(top: stats.stats.tracks)),
                if (!stats.recap.isEmpty)
                  SliverToBoxAdapter(
                    child: _RecapCard(
                      recap: stats.recap,
                      onOpen: () => Navigator.of(context).push(RecapPage.route()),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: Space.shellClear)),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyHome extends StatelessWidget {
  const _EmptyHome({required this.onScan});

  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _HeroCard(onScan: onScan),
        const SectionTitle(title: 'What you get'),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: Space.page),
          child: Column(
            children: [
              _Point(
                icon: Icons.folder_open_rounded,
                title: 'You pick the folders',
                body: 'Keep the folders that hold music and skip the rest.',
              ),
              SizedBox(height: 2),
              _Point(
                icon: Icons.image_outlined,
                title: 'Covers from your files',
                body: 'Timbre reads the artwork already inside each song.',
              ),
              SizedBox(height: 2),
              _Point(
                icon: Icons.auto_graph_rounded,
                title: 'Minutes worth seeing',
                body: 'Streaks, top artists, and a weekly recap you can share.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.onOpenLibrary});

  final VoidCallback onOpenLibrary;

  @override
  Widget build(BuildContext context) {
    final services = Services.i;
    final playback = services.playback;
    final library = services.library;
    final c = context.c;

    final last = services.stats.recentPlays
        .map((event) => library.trackById(event.trackId))
        .whereType<Track>()
        .firstOrNull;
    final current = playback.current;
    final track = current ?? last;
    final isCurrent = current != null;
    final queue = last == null
        ? library.tracks
        : [
            last,
            ...library.tracks.where((item) => item.id != last.id),
          ];
    final index = track == null ? 0 : queue.indexWhere((item) => item.id == track.id);

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.page, 10, Space.page, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.xl),
          border: Border.all(color: c.line),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              c.accent.withValues(alpha: c.isDark ? 0.22 : 0.14),
              c.surface,
              c.surface,
            ],
            stops: const [0, 0.55, 1],
          ),
        ),
        child: Row(
          children: [
            Pressable(
              onTap: () {
                if (isCurrent) {
                  Navigator.of(context).push(PlayerPage.route());
                } else if (track != null) {
                  playback.playQueue(
                    queue,
                    startIndex: index < 0 ? 0 : index,
                    label: 'Recently played',
                  );
                  Navigator.of(context).push(PlayerPage.route());
                }
              },
              child: Cover(
                path: track?.coverPath,
                seed: track?.id ?? 'timbre',
                title: track?.title ?? 'Timbre',
                artist: track?.displayArtist ?? '',
                size: 76,
                radius: 16,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isCurrent) ...[
                        const PlayingBars(size: 12),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        isCurrent
                            ? 'NOW PLAYING'
                            : (track == null ? 'READY WHEN YOU ARE' : 'PICK UP AGAIN'),
                        style: context.overline(
                          color: isCurrent ? c.accent : c.textFaint,
                          spacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    track?.title ?? 'Shuffle your whole library',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.serif(size: 21, height: 1.12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    track?.displayArtist ?? plural(library.songCount, 'song'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.sans(size: 12.5, color: c.textDim),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () {
                if (isCurrent) {
                  playback.toggle();
                } else if (track != null) {
                  playback.playQueue(
                    queue,
                    startIndex: index < 0 ? 0 : index,
                    label: 'Recently played',
                  );
                } else {
                  onOpenLibrary();
                }
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: c.accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: c.accent.withValues(alpha: 0.3),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                      spreadRadius: -6,
                    ),
                  ],
                ),
                child: Icon(
                  isCurrent && playback.playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 28,
                  color: c.onAccent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.stats, required this.onOpen});

  final StatsSnapshot stats;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final peak = stats.days.fold<int>(
      0,
      (value, day) => math.max(value, day.milliseconds),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.page, 14, Space.page, 0),
      child: Pressable(
        onTap: onOpen,
        scale: 0.99,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(Radii.xl),
            border: Border.all(color: c.line),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'THIS WEEK',
                          style: context.overline(
                            color: c.textFaint,
                            spacing: 1.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '${stats.weekMinutes}',
                              style: context.serif(size: 42, height: 0.95),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'min',
                              style: context.sans(
                                size: 13,
                                weight: 500,
                                color: c.textDim,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${plural(stats.weekPlays, "play")} · ${plural(stats.days.where((day) => day.milliseconds > 0).length, "day")}',
                          style: context.sans(size: 11.5, color: c.textDim),
                        ),
                        if (stats.streakDays > 0) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: c.accentSoft,
                              borderRadius: BorderRadius.circular(Radii.pill),
                              border: Border.all(color: c.accentLine),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.local_fire_department_rounded,
                                  size: 13,
                                  color: c.accent,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${stats.streakDays} day streak',
                                  style: context.sans(
                                    size: 10.5,
                                    weight: 600,
                                    color: c.accent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 132,
                    height: 92,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final day in stats.days)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2.5),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.bottomCenter,
                                      child: FractionallySizedBox(
                                        heightFactor: peak <= 0
                                            ? 0.04
                                            : (day.milliseconds / peak).clamp(
                                                0.04,
                                                1.0,
                                              ),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: _isToday(day)
                                                ? c.accent
                                                : c.accent.withValues(
                                                    alpha: 0.3,
                                                  ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    _weekday(day.day),
                                    style: context.sans(
                                      size: 9,
                                      weight: _isToday(day) ? 700 : 500,
                                      color: _isToday(day)
                                          ? c.accent
                                          : c.textFaint,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: c.line),
              const SizedBox(height: 12),
              Row(
                children: [
                  _GoalRing(progress: stats.goalProgress, met: stats.goalMet),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      stats.goalMet
                          ? 'Daily goal met · ${(stats.todayMs / 60000).round()} min today'
                          : '${(stats.todayMs / 60000).round()} of ${stats.goalMs ~/ 60000} min today',
                      style: context.sans(size: 11.5, color: c.textDim),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: c.textFaint,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static bool _isToday(DayTotal day) {
    final now = DateTime.now();
    return day.day.year == now.year &&
        day.day.month == now.month &&
        day.day.day == now.day;
  }

  static String _weekday(DateTime day) {
    const names = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return names[day.weekday - 1];
  }
}

class _GoalRing extends StatelessWidget {
  const _GoalRing({required this.progress, required this.met});

  final double progress;
  final bool met;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      width: 26,
      height: 26,
      child: CustomPaint(
        painter: _RingPainter(progress, c.accent, c.lineStrong),
        child: met
            ? Icon(Icons.check_rounded, size: 14, color: c.accent)
            : null,
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress, this.color, this.track);

  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = size.width * 0.11;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    final arcRect = rect.deflate(stroke / 2);
    canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2, false, base);
    if (progress > 0) {
      canvas.drawArc(
        arcRect,
        -math.pi / 2,
        math.pi * 2 * progress.clamp(0.0, 1.0),
        false,
        fill,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.track != track;
}

class _MixesRow extends StatelessWidget {
  const _MixesRow({required this.mixes});

  final List<Mix> mixes;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: 'Made for you'),
        SizedBox(
          height: 208,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Space.page),
            itemCount: mixes.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final mix = mixes[index];
              final cover = mix.tracks
                  .map((track) => track.coverPath)
                  .firstWhere((path) => path != null, orElse: () => null);
              return Pressable(
                onTap: () {
                  Services.i.playback.playQueue(
                    mix.tracks,
                    label: mix.title,
                  );
                  Navigator.of(context).push(PlayerPage.route());
                },
                child: SizedBox(
                  width: 148,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 148,
                        height: 148,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Cover(
                              path: cover,
                              seed: mix.id,
                              title: mix.title,
                              artist: mix.subtitle,
                              radius: 18,
                            ),
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              height: 84,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.vertical(
                                    bottom: Radius.circular(18),
                                  ),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.72),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 12,
                              right: 10,
                              bottom: 10,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    mix.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.serif(
                                      size: 17,
                                      height: 1.1,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        mix.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.sans(
                          size: 11,
                          color: c.textFaint,
                          height: 1.3,
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

class _RecentlyAdded extends StatelessWidget {
  const _RecentlyAdded({required this.onOpenLibrary});

  final VoidCallback onOpenLibrary;

  @override
  Widget build(BuildContext context) {
    final library = Services.i.library;
    final tracks = [...library.tracks]
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    final recent = tracks.take(10).toList();
    if (recent.isEmpty) return const SizedBox.shrink();
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          title: 'Recently added',
          action: 'All songs',
          onAction: onOpenLibrary,
        ),
        SizedBox(
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Space.page),
            itemCount: recent.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final track = recent[index];
              return Pressable(
                onTap: () {
                  Services.i.playback.playQueue(
                    recent,
                    startIndex: index,
                    label: 'Recently added',
                  );
                },
                child: SizedBox(
                  width: 124,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Cover(
                        path: track.coverPath,
                        seed: track.id,
                        title: track.title,
                        artist: track.displayArtist,
                        size: 124,
                        radius: 16,
                      ),
                      const SizedBox(height: 7),
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.sans(size: 12.5, weight: 600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        track.displayArtist,
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

class _OnRepeat extends StatelessWidget {
  const _OnRepeat({required this.top});

  final List<TopEntry> top;

  @override
  Widget build(BuildContext context) {
    final library = Services.i.library;
    final tracks = top
        .map((entry) => entry.trackId == null ? null : library.trackById(entry.trackId!))
        .whereType<Track>()
        .toList();
    if (tracks.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: 'On repeat'),
        for (var i = 0; i < tracks.length && i < 4; i++)
          TrackTile(
            track: tracks[i],
            dense: true,
            onTap: () {
              Services.i.playback.playQueue(
                tracks,
                startIndex: i,
                label: 'On repeat',
              );
            },
          ),
      ],
    );
  }
}

class _RecapCard extends StatelessWidget {
  const _RecapCard({required this.recap, required this.onOpen});

  final WeeklyRecap recap;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.page, 24, Space.page, 0),
      child: Pressable(
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.xl),
            border: Border.all(color: c.accentLine),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                c.accent.withValues(alpha: 0.95),
                Color.lerp(c.accent, Colors.black, 0.32)!,
              ],
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YOUR WEEK',
                      style: context.overline(
                        color: c.onAccent.withValues(alpha: 0.72),
                        spacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your week in music',
                      style: context.serif(
                        size: 23,
                        height: 1.1,
                        color: c.onAccent,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${recap.minutes} min · ${recap.plays} plays'
                      '${recap.topArtist == null ? '' : ' · ${recap.topArtist!.name}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.sans(
                        size: 12,
                        color: c.onAccent.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: c.onAccent.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 20,
                  color: c.onAccent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.onScan});

  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.page, 10, Space.page, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.xl),
          border: Border.all(color: c.line),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              c.accent.withValues(alpha: c.isDark ? 0.24 : 0.16),
              c.surface,
              c.surface,
            ],
            stops: const [0, 0.62, 1],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const BrandMark(size: 26),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: c.canvas.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(Radii.pill),
                    border: Border.all(color: c.line),
                  ),
                  child: Text(
                    'OFFLINE',
                    style: context.overline(color: c.textDim, spacing: 1.2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),
            Text(
              'Your music,\nin its own order.',
              style: context.serif(size: 32, height: 1.02, spacing: -0.6),
            ),
            const SizedBox(height: 10),
            Text(
              'Timbre is a player for the songs already on your phone. '
              'No account, no ads, no uploads.',
              style: context.sans(size: 14, color: c.textDim, height: 1.5),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Flexible(
                  child: PrimaryButton(
                    label: 'Scan my music',
                    icon: Icons.radar_rounded,
                    onPressed: onScan,
                  ),
                ),
                const SizedBox(width: 10),
                CircleButton(
                  icon: Icons.help_outline_rounded,
                  tooltip: 'How scanning works',
                  onPressed: () => _showHowItWorks(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showHowItWorks(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        final c = context.c;
        return Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(Radii.xl),
            border: Border.all(color: c.line),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: c.lineStrong,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Text('How scanning works', style: context.serif(size: 24)),
              const SizedBox(height: 10),
              Text(
                'Timbre asks your phone for audio access, then lists the folders '
                'that hold music. You choose which ones to include. Nothing '
                'leaves your device and no audio is copied.',
                style: context.sans(size: 14, color: c.textDim, height: 1.55),
              ),
              const SizedBox(height: 18),
              PrimaryButton(
                label: 'Got it',
                expand: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: c.surfaceHigh,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: c.line),
            ),
            child: Icon(icon, size: 19, color: c.textDim),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.sans(size: 14.5, weight: 600)),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: context.sans(size: 13, color: c.textDim, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
