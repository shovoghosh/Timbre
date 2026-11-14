import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/services.dart';
import '../../data/history/stats.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../widgets/brand.dart';
import '../widgets/buttons.dart';
import '../widgets/page_header.dart';

/// The numbers behind Home: week, goals, streaks, top lists and hours.
class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const StatsPage());
  }

  @override
  Widget build(BuildContext context) {
    final services = Services.i;
    return AnimatedBuilder(
      animation: services.stats,
      builder: (context, _) {
        final stats = services.stats.stats;
        final c = context.c;
        return PageScaffold(
          wash: false,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(
                    children: [
                      CircleButton(
                        icon: Icons.arrow_back_rounded,
                        size: 38,
                        iconSize: 20,
                        onPressed: () => Navigator.of(context).maybePop(),
                        tooltip: 'Back',
                      ),
                      const SizedBox(width: 8),
                      const BrandMark(size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'LISTENING',
                        style: context.overline(color: c.textFaint),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: PageHeader(
                  kicker: 'Last seven days',
                  title: 'Your listening',
                  padding: EdgeInsets.fromLTRB(Space.page, 14, Space.page, 6),
                ),
              ),
              SliverToBoxAdapter(child: _WeekHero(stats: stats)),
              SliverToBoxAdapter(child: _WeekChart(stats: stats)),
              SliverToBoxAdapter(child: _Goals(stats: stats)),
              if (stats.artists.isNotEmpty)
                SliverToBoxAdapter(
                  child: _TopSection(
                    title: 'Top artists',
                    entries: stats.artists,
                    emptyLabel: 'No plays yet',
                  ),
                ),
              if (stats.albums.isNotEmpty)
                SliverToBoxAdapter(
                  child: _TopSection(
                    title: 'Top albums',
                    entries: stats.albums,
                  ),
                ),
              if (stats.tracks.isNotEmpty)
                SliverToBoxAdapter(
                  child: _TopSection(title: 'Top songs', entries: stats.tracks),
                ),
              SliverToBoxAdapter(child: _Hours(stats: stats)),
              if (stats.genres.isNotEmpty)
                SliverToBoxAdapter(child: _Genres(stats: stats)),
              SliverToBoxAdapter(child: _Details(stats: stats)),
              const SliverToBoxAdapter(
                child: SizedBox(height: Space.bottomClear),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WeekHero extends StatelessWidget {
  const _WeekHero({required this.stats});

  final StatsSnapshot stats;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final change = stats.changePercent;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.page, 8, Space.page, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.xl),
          border: Border.all(color: c.line),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [c.accent.withValues(alpha: 0.2), c.surface],
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MINUTES', style: context.overline(color: c.textFaint)),
                  const SizedBox(height: 6),
                  Text(
                    '${stats.weekMinutes}',
                    style: context.serif(size: 54, height: 0.9),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${plural(stats.weekPlays, 'play')} · '
                    '${stats.days.where((day) => day.milliseconds > 0).length} active days',
                    style: context.sans(size: 12, color: c.textDim),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: change >= 0 ? c.accentSoft : c.surfaceHigh,
                    borderRadius: BorderRadius.circular(Radii.pill),
                    border: Border.all(color: c.line),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        change >= 0
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        size: 14,
                        color: change >= 0 ? c.accent : c.textDim,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${change >= 0 ? '+' : ''}$change%',
                        style: context.sans(
                          size: 11.5,
                          weight: 600,
                          color: change >= 0 ? c.accent : c.textDim,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'vs last week',
                  style: context.sans(size: 10, color: c.textFaint),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.stats});

  final StatsSnapshot stats;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final peak = stats.days.fold<int>(
      1,
      (value, day) => math.max(value, day.milliseconds),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.page, 14, Space.page, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.xl),
          border: Border.all(color: c.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('DAILY MINUTES', style: context.overline(color: c.textFaint)),
            const SizedBox(height: 14),
            SizedBox(
              height: 112,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final day in stats.days)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              day.milliseconds == 0
                                  ? ''
                                  : '${(day.milliseconds / 60000).round()}',
                              style: context.numeric(
                                size: 9,
                                color: c.textFaint,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: FractionallySizedBox(
                                  heightFactor: (day.milliseconds / peak).clamp(
                                    0.03,
                                    1.0,
                                  ),
                                  child: Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: _isToday(day)
                                          ? c.accent
                                          : c.accent.withValues(alpha: 0.28),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _weekday(day.day),
                              style: context.sans(
                                size: 10,
                                weight: _isToday(day) ? 700 : 500,
                                color: _isToday(day) ? c.accent : c.textFaint,
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

class _Goals extends StatelessWidget {
  const _Goals({required this.stats});

  final StatsSnapshot stats;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.page, 14, Space.page, 0),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              label: 'TODAY',
              value: '${(stats.todayMs / 60000).round()}',
              unit: 'of ${stats.goalMs ~/ 60000} min',
              progress: stats.goalProgress,
              icon: Icons.today_rounded,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              label: 'STREAK',
              value: '${stats.streakDays}',
              unit: stats.streakDays == 1 ? 'day' : 'days',
              icon: Icons.local_fire_department_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    this.progress,
  });

  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: c.textFaint),
              const SizedBox(width: 6),
              Text(label, style: context.overline(color: c.textFaint)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: context.serif(size: 30, height: 1)),
              const SizedBox(width: 5),
              Text(unit, style: context.sans(size: 11, color: c.textDim)),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: c.line,
                valueColor: AlwaysStoppedAnimation(c.accent),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TopSection extends StatelessWidget {
  const _TopSection({
    required this.title,
    required this.entries,
    this.emptyLabel = 'Nothing yet',
  });

  final String title;
  final List<TopEntry> entries;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final max = entries.isEmpty
        ? 1
        : entries.map((entry) => entry.milliseconds).reduce(math.max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title: title),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.page),
          child: Column(
            children: [
              for (var i = 0; i < entries.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text(
                          '${i + 1}'.padLeft(2, '0'),
                          style: context.numeric(
                            size: 11,
                            color: i == 0 ? c.accent : c.textFaint,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    entries[i].name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.sans(
                                      size: 13.5,
                                      weight: 500,
                                    ),
                                  ),
                                ),
                                Text(
                                  entries[i].minutesLabel,
                                  style: context.numeric(
                                    size: 10.5,
                                    color: c.textFaint,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: entries[i].milliseconds / max,
                                minHeight: 3,
                                backgroundColor: c.line,
                                valueColor: AlwaysStoppedAnimation(
                                  i == 0
                                      ? c.accent
                                      : c.accent.withValues(alpha: 0.4),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Hours extends StatelessWidget {
  const _Hours({required this.stats});

  final StatsSnapshot stats;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final peak = stats.hours.fold<int>(
      1,
      (value, hour) => math.max(value, hour.milliseconds),
    );
    final best = stats.hours.reduce(
      (a, b) => a.milliseconds >= b.milliseconds ? a : b,
    );
    if (best.milliseconds == 0) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: 'When you listen'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.page),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(Radii.lg),
              border: Border.all(color: c.line),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 64,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final hour in stats.hours)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 1),
                            child: FractionallySizedBox(
                              heightFactor: (hour.milliseconds / peak).clamp(
                                0.04,
                                1.0,
                              ),
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: hour.hour == best.hour
                                      ? c.accent
                                      : c.textFaint.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final label in ['12a', '6a', '12p', '6p', '11p'])
                      Text(
                        label,
                        style: context.numeric(size: 9, color: c.textFaint),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 14, color: c.accent),
                    const SizedBox(width: 6),
                    Text(
                      'Peak hour: ${_hourLabel(best.hour)}',
                      style: context.sans(size: 12, color: c.textDim),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _hourLabel(int hour) {
    final suffix = hour < 12 ? 'am' : 'pm';
    final shown = hour % 12 == 0 ? 12 : hour % 12;
    return '$shown$suffix';
  }
}

class _Genres extends StatelessWidget {
  const _Genres({required this.stats});

  final StatsSnapshot stats;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: 'Genres'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.page),
          child: Column(
            children: [
              for (final genre in stats.genres)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text(
                          genre.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.sans(size: 12.5, weight: 500),
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: genre.share,
                            minHeight: 5,
                            backgroundColor: c.line,
                            valueColor: AlwaysStoppedAnimation(
                              c.accent.withValues(alpha: 0.75),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 34,
                        child: Text(
                          '${(genre.share * 100).round()}%',
                          textAlign: TextAlign.right,
                          style: context.numeric(size: 10, color: c.textFaint),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.stats});

  final StatsSnapshot stats;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rows = <(String, String)>[
      ('Longest session', formatTotal(stats.longestSessionMs)),
      ('Library explored', '${(stats.exploredShare * 100).round()}%'),
      ('Songs played', '${stats.exploredTracks} of ${stats.librarySize}'),
      ('All time', formatTotal(stats.allTimeMs)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: 'Details'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.page),
          child: Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(Radii.lg),
              border: Border.all(color: c.line),
            ),
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            rows[i].$1,
                            style: context.sans(size: 13.5, color: c.textDim),
                          ),
                        ),
                        Text(
                          rows[i].$2,
                          style: context.sans(
                            size: 13.5,
                            weight: 600,
                            color: c.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i != rows.length - 1)
                    Divider(
                      height: 1,
                      color: c.line,
                      indent: 16,
                      endIndent: 16,
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
