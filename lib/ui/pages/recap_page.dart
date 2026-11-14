import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/format.dart';
import '../../core/haptics.dart';
import '../../core/services.dart';
import '../../data/history/stats.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../widgets/cover.dart';

/// A short, tappable story of the week. Built from the same numbers as Home.
class RecapPage extends StatefulWidget {
  const RecapPage({super.key});

  static Route<void> route() {
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (_, _, _) => const RecapPage(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
    );
  }

  @override
  State<RecapPage> createState() => _RecapPageState();
}

class _RecapPageState extends State<RecapPage> {
  final _pages = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final services = Services.i;
    return AnimatedBuilder(
      animation: services.stats,
      builder: (context, _) {
        final recap = services.stats.recap;
        final stats = services.stats.stats;
        final c = context.c;
        final slides = _slides(context, recap, stats);

        return Scaffold(
          backgroundColor: c.canvas,
          body: Stack(
            children: [
              PageView.builder(
                controller: _pages,
                itemCount: slides.length,
                onPageChanged: (value) => setState(() => _index = value),
                itemBuilder: (context, index) => _Slide(
                  seed: index,
                  child: slides[index],
                  onNext: () {
                    if (index == slides.length - 1) {
                      Navigator.of(context).maybePop();
                    } else {
                      _pages.nextPage(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                      );
                    }
                  },
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          for (var i = 0; i < slides.length; i++)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(
                                    begin: 0,
                                    end: i <= _index ? 1 : 0,
                                  ),
                                  duration: const Duration(milliseconds: 320),
                                  builder: (context, value, _) => Container(
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.28 + value * 0.6,
                                      ),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: Icon(
                            Icons.close_rounded,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _slides(
    BuildContext context,
    WeeklyRecap recap,
    StatsSnapshot stats,
  ) {
    final services = Services.i;
    if (recap.isEmpty) {
      return [
        const _EmptyRecap(
          icon: Icons.auto_graph_rounded,
          title: 'No listening yet',
          body:
              'Play something and your week appears here: minutes, top artist '
              'and the hour you listen most.',
        ),
      ];
    }

    final topArtist = recap.topArtist;
    final topTrack = recap.topTrack;
    final topAlbum = recap.topAlbum;
    final track = topTrack?.trackId == null
        ? null
        : services.library.trackById(topTrack!.trackId!);

    return [
      _IntroSlide(recap: recap),
      if (topArtist != null)
        _ArtistSlide(artist: topArtist, totalMinutes: recap.minutes),
      if (topTrack != null) _TrackSlide(track: track, entry: topTrack),
      _HabitSlide(recap: recap, stats: stats),
      _ShareSlide(
        recap: recap,
        topArtist: topArtist,
        topTrack: topTrack,
        topAlbum: topAlbum,
      ),
    ];
  }
}

class _Slide extends StatelessWidget {
  const _Slide({required this.child, required this.seed, required this.onNext});

  final Widget child;
  final int seed;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final colors = coverColorsFor('recap$seed');
    return GestureDetector(
      onTap: () {
        Haptics.tap();
        onNext();
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(c.accent, colors.$1, 0.45)!,
              Color.lerp(c.accent, Colors.black, 0.55)!,
              const Color(0xFF0A0B0D),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(26, 60, 26, 30),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _IntroSlide extends StatelessWidget {
  const _IntroSlide({required this.recap});

  final WeeklyRecap recap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'YOUR WEEK',
          style: context.overline(color: Colors.white70, spacing: 2),
        ),
        const SizedBox(height: 10),
        Text(
          'You listened\nfor ${recap.minutes} minutes.',
          style: context.serif(size: 40, height: 1.08, color: Colors.white),
        ),
        const SizedBox(height: 18),
        Text(
          '${plural(recap.plays, 'play')} across ${plural(recap.daysActive, 'day')}.',
          style: context.sans(
            size: 15,
            color: Colors.white.withValues(alpha: 0.8),
            height: 1.5,
          ),
        ),
        const Spacer(),
        const _TapHint(label: 'Tap to keep going'),
      ],
    );
  }
}

class _ArtistSlide extends StatelessWidget {
  const _ArtistSlide({required this.artist, required this.totalMinutes});

  final TopEntry artist;
  final int totalMinutes;

  @override
  Widget build(BuildContext context) {
    final share = totalMinutes <= 0
        ? 0.0
        : (artist.minutesLabel.replaceAll(' min', '').isEmpty
                  ? 0
                  : double.tryParse(
                          artist.minutesLabel.replaceAll(' min', ''),
                        ) ??
                        0) /
              totalMinutes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'MOST PLAYED ARTIST',
          style: context.overline(color: Colors.white70, spacing: 2),
        ),
        const SizedBox(height: 12),
        Text(
          artist.name,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: context.serif(size: 44, height: 1.02, color: Colors.white),
        ),
        const SizedBox(height: 12),
        Text(
          '${artist.minutesLabel} · ${plural(artist.plays, 'play')}',
          style: context.sans(
            size: 15,
            color: Colors.white.withValues(alpha: 0.82),
          ),
        ),
        const SizedBox(height: 22),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: share.clamp(0.05, 1.0),
            minHeight: 8,
            backgroundColor: Colors.white.withValues(alpha: 0.16),
            valueColor: const AlwaysStoppedAnimation(Colors.white),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${(share * 100).round()}% of your week',
          style: context.sans(size: 12, color: Colors.white70),
        ),
        const Spacer(),
        const _TapHint(label: 'Next'),
      ],
    );
  }
}

class _TrackSlide extends StatelessWidget {
  const _TrackSlide({required this.track, required this.entry});

  final dynamic track;
  final TopEntry entry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'ON REPEAT',
          style: context.overline(color: Colors.white70, spacing: 2),
        ),
        const SizedBox(height: 18),
        Center(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 40,
                  offset: const Offset(0, 18),
                  spreadRadius: -10,
                ),
              ],
            ),
            child: Cover(
              path: track?.coverPath,
              seed: entry.trackId ?? entry.name,
              title: entry.name,
              artist: entry.subtitle,
              size: 230,
              radius: 22,
            ),
          ),
        ),
        const SizedBox(height: 26),
        Text(
          entry.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.serif(size: 30, height: 1.08, color: Colors.white),
        ),
        const SizedBox(height: 6),
        Text(
          entry.subtitle,
          style: context.sans(
            size: 14,
            color: Colors.white.withValues(alpha: 0.78),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '${plural(entry.plays, 'play')} · ${entry.minutesLabel}',
          style: context.sans(size: 13, color: Colors.white70),
        ),
        const Spacer(),
        const _TapHint(label: 'Next'),
      ],
    );
  }
}

class _HabitSlide extends StatelessWidget {
  const _HabitSlide({required this.recap, required this.stats});

  final WeeklyRecap recap;
  final StatsSnapshot stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'HOW YOU LISTENED',
          style: context.overline(color: Colors.white70, spacing: 2),
        ),
        const SizedBox(height: 18),
        _Fact(
          value: recap.peakLabel,
          label: 'Your peak hour',
          icon: Icons.schedule_rounded,
        ),
        const SizedBox(height: 20),
        _Fact(
          value: '${stats.streakDays}',
          label: stats.streakDays == 1 ? 'Day streak' : 'Day streak',
          icon: Icons.local_fire_department_rounded,
        ),
        const SizedBox(height: 20),
        _Fact(
          value: '${(stats.exploredShare * 100).round()}%',
          label: 'Of your library explored',
          icon: Icons.explore_outlined,
        ),
        const SizedBox(height: 20),
        _Fact(
          value: formatTotal(stats.longestSessionMs),
          label: 'Longest session',
          icon: Icons.timer_outlined,
        ),
        const Spacer(),
        const _TapHint(label: 'One more'),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.value, required this.label, required this.icon});

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, size: 22, color: Colors.white),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: context.serif(size: 30, height: 1, color: Colors.white),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: context.sans(size: 12.5, color: Colors.white70),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ShareSlide extends StatelessWidget {
  const _ShareSlide({
    required this.recap,
    required this.topArtist,
    required this.topTrack,
    required this.topAlbum,
  });

  final WeeklyRecap recap;
  final TopEntry? topArtist;
  final TopEntry? topTrack;
  final TopEntry? topAlbum;

  @override
  Widget build(BuildContext context) {
    final lines = <String>[
      'My week in Timbre',
      '${recap.minutes} minutes · ${plural(recap.plays, 'play')}',
      if (topArtist != null) 'Top artist: ${topArtist!.name}',
      if (topAlbum != null) 'Top album: ${topAlbum!.name}',
      if (topTrack != null) 'Top song: ${topTrack!.name}',
      'Peak hour: ${recap.peakLabel}',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'WRAP IT UP',
          style: context.overline(color: Colors.white70, spacing: 2),
        ),
        const SizedBox(height: 14),
        Text(
          'That was\nyour week.',
          style: context.serif(size: 40, height: 1.05, color: Colors.white),
        ),
        const SizedBox(height: 18),
        Text(
          '${recap.minutes} minutes. '
          '${topArtist == null ? '' : '${topArtist!.name} led the way. '}'
          '${plural(recap.daysActive, 'day')} of listening.',
          style: context.sans(
            size: 15,
            color: Colors.white.withValues(alpha: 0.82),
            height: 1.55,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => SharePlus.instance.share(
            ShareParams(text: lines.join('\n'), subject: 'My week in Timbre'),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.ios_share_rounded,
                  size: 18,
                  color: Colors.black,
                ),
                const SizedBox(width: 8),
                Text(
                  'Share my week',
                  style: context.sans(
                    size: 14.5,
                    weight: 600,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'Tap anywhere to close',
            style: context.sans(size: 11.5, color: Colors.white54),
          ),
        ),
      ],
    );
  }
}

class _EmptyRecap extends StatelessWidget {
  const _EmptyRecap({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 40, color: Colors.white70),
        const SizedBox(height: 18),
        Text(title, style: context.serif(size: 34, color: Colors.white)),
        const SizedBox(height: 10),
        Text(
          body,
          style: context.sans(
            size: 14,
            color: Colors.white.withValues(alpha: 0.8),
            height: 1.55,
          ),
        ),
      ],
    );
  }
}

class _TapHint extends StatelessWidget {
  const _TapHint({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: context.sans(size: 12, color: Colors.white54)),
        const SizedBox(width: 6),
        const Icon(
          Icons.arrow_forward_rounded,
          size: 14,
          color: Colors.white54,
        ),
      ],
    );
  }
}
