import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../audio/playback_controller.dart';
import '../../core/format.dart';
import '../../core/haptics.dart';
import '../../core/services.dart';
import '../../data/models/track.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../widgets/cover.dart';
import '../widgets/snack.dart';
import '../widgets/song_menu.dart';
import 'art_skins.dart';
import 'lyrics_sheet.dart';
import 'queue_sheet.dart';
import 'scrub_bar.dart';
import 'timer_sheets.dart';

/// The full player. Swipe the artwork area for three looks, drag down to close.
class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  static Route<void> route() {
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, animation, secondaryAnimation) =>
          const PlayerPage(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Motion.emphasis,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );
  }

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage>
    with TickerProviderStateMixin {
  final PageController _pages = PageController();
  late final AnimationController _dismiss = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  /// One shot entrance, so the cover, words and controls arrive in order.
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 640),
  )..forward();
  int _skin = 0;
  double _drag = 0;
  double _dismissFrom = 0;
  double _dismissTo = 0;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _dismiss.addListener(() {
      setState(() {
        _drag = _dismissFrom + (_dismissTo - _dismissFrom) * _dismiss.value;
      });
    });
    _dismiss.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        Navigator.of(context).maybePop();
      }
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    _dismiss.dispose();
    _enter.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_dismissing) return;
    final next = _drag + details.delta.dy;
    setState(() => _drag = next < 0 ? next * 0.25 : next);
  }

  void _onDragEnd(DragEndDetails details) {
    if (_dismissing) return;
    final velocity = details.velocity.pixelsPerSecond.dy;
    if (_drag > 120 || velocity > 900) {
      _dismissing = true;
      _dismissFrom = _drag;
      _dismissTo = MediaQuery.sizeOf(context).height;
      _dismiss.forward(from: 0);
    } else {
      setState(() => _drag = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = Services.i;
    final playback = services.playback;
    final favorites = services.favorites;

    return AnimatedBuilder(
      animation: Listenable.merge([playback, favorites]),
      builder: (context, _) {
        final track = playback.current;
        final c = context.c;
        return Scaffold(
          backgroundColor: c.canvas,
          body: Transform.translate(
            offset: Offset(0, _drag),
            child: GestureDetector(
              onVerticalDragUpdate: _onDragUpdate,
              onVerticalDragEnd: _onDragEnd,
              child: Stack(
                children: [
                  Positioned.fill(child: _Backdrop(track: track)),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            c.canvas.withValues(alpha: c.isDark ? 0.42 : 0.55),
                            c.canvas.withValues(alpha: c.isDark ? 0.72 : 0.82),
                            c.canvas,
                          ],
                          stops: const [0, 0.52, 1],
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    child: track == null
                        ? const SizedBox.shrink()
                        : _content(context, playback, track, services),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _content(
    BuildContext context,
    PlaybackController playback,
    Track track,
    dynamic services,
  ) {
    return LayoutBuilder(
      builder: (context, box) {
        final artHeight = math.min(
          box.maxWidth - 44,
          math.max(190.0, box.maxHeight * 0.42),
        );
        return Column(
          children: [
            _Rise(
              animation: _enter,
              interval: const Interval(0, 0.34),
              child: _TopBar(
                label: playback.label.isEmpty ? 'Your library' : playback.label,
                onClose: () => Navigator.of(context).maybePop(),
                onMore: () => showSongMenu(context, track),
              ),
            ),
            FadeTransition(
              opacity: CurvedAnimation(
                parent: _enter,
                curve: const Interval(0.04, 0.52, curve: Curves.easeOutCubic),
              ),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.93, end: 1).animate(
                  CurvedAnimation(
                    parent: _enter,
                    curve: const Interval(
                      0.04,
                      0.58,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: SizedBox(
                    height: artHeight,
                    child: PageView(
                      controller: _pages,
                      onPageChanged: (value) => setState(() => _skin = value),
                      children: [
                        SleeveArt(
                          coverPath: track.coverPath,
                          seed: track.id,
                          title: track.title,
                          artist: track.displayArtist,
                        ),
                        VinylArt(
                          coverPath: track.coverPath,
                          seed: track.id,
                          title: track.title,
                          artist: track.displayArtist,
                          playing: playback.playing,
                        ),
                        SpectrumArt(playing: playback.playing, seed: track.id),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _Rise(
              animation: _enter,
              interval: const Interval(0.16, 0.56),
              child: _SkinDots(
                count: 3,
                index: _skin,
                onSelect: (index) {
                  Haptics.tap();
                  _pages.animateToPage(
                    index,
                    duration: Motion.base,
                    curve: Motion.curve,
                  );
                },
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, inner) {
                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: inner.maxHeight),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _Rise(
                              animation: _enter,
                              interval: const Interval(0.22, 0.62),
                              child: _TrackInfo(
                                track: track,
                                isFavorite: services.favorites.contains(
                                  track.id,
                                ),
                                onFavorite: () async {
                                  final added = await services.favorites.toggle(
                                    track.id,
                                  );
                                  Haptics.press();
                                  if (context.mounted) {
                                    showSnack(
                                      context,
                                      added
                                          ? 'Added to favorites'
                                          : 'Removed from favorites',
                                    );
                                  }
                                },
                              ),
                            ),
                            const SizedBox(height: 14),
                            _Rise(
                              animation: _enter,
                              interval: const Interval(0.3, 0.72),
                              child: ScrubBar(playback: playback),
                            ),
                            const SizedBox(height: 10),
                            _Rise(
                              animation: _enter,
                              interval: const Interval(0.38, 0.82),
                              child: _Controls(playback: playback),
                            ),
                            const SizedBox(height: 10),
                            _Rise(
                              animation: _enter,
                              interval: const Interval(0.46, 0.94),
                              child: _Actions(
                                playback: playback,
                                track: track,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Fades and lifts a child in, on its own slice of the entrance animation.
class _Rise extends StatelessWidget {
  const _Rise({
    required this.animation,
    required this.interval,
    required this.child,
  });

  final Animation<double> animation;
  final Interval interval;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curved = animation.drive(
      CurveTween(
        curve: Interval(
          interval.begin,
          interval.end,
          curve: Curves.easeOutCubic,
        ),
      ),
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

class _Backdrop extends StatefulWidget {
  const _Backdrop({required this.track});

  final Track? track;

  @override
  State<_Backdrop> createState() => _BackdropState();
}

class _BackdropState extends State<_Backdrop>
    with SingleTickerProviderStateMixin {
  /// A very slow drift, so the artwork behind the player breathes instead of
  /// sitting still.
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.track?.id ?? 'timbre';
    final pair = coverColorsFor(id);
    final cover = widget.track?.coverPath;
    final art = Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [pair.$2, pair.$1],
            ),
          ),
        ),
        if (cover != null && cover.isNotEmpty && File(cover).existsSync())
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 54, sigmaY: 54),
            child: Transform.scale(
              scale: 1.25,
              child: Image.file(
                File(cover),
                fit: BoxFit.cover,
                cacheWidth: 240,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
      ],
    );
    return AnimatedBuilder(
      animation: _drift,
      child: art,
      builder: (context, child) {
        final t = Curves.easeInOutSine.transform(_drift.value);
        return Transform.scale(scale: 1.03 + t * 0.05, child: child);
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.label,
    required this.onClose,
    required this.onMore,
  });

  final String label;
  final VoidCallback onClose;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      height: 54,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            _RoundIcon(icon: Icons.keyboard_arrow_down_rounded, onTap: onClose),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'PLAYING FROM',
                    style: context.overline(color: c.textFaint, spacing: 1.3),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.sans(
                      size: 12,
                      weight: 600,
                      color: c.textDim,
                    ),
                  ),
                ],
              ),
            ),
            _RoundIcon(icon: Icons.more_horiz_rounded, onTap: onMore),
          ],
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 24, color: context.c.text),
      style: IconButton.styleFrom(
        backgroundColor: context.c.surface.withValues(alpha: 0.42),
        minimumSize: const Size(40, 40),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class _SkinDots extends StatelessWidget {
  const _SkinDots({
    required this.count,
    required this.index,
    required this.onSelect,
  });

  final int count;
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          GestureDetector(
            onTap: () => onSelect(i),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: AnimatedContainer(
                duration: Motion.base,
                width: i == index ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == index ? c.accent : c.lineStrong,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TrackInfo extends StatefulWidget {
  const _TrackInfo({
    required this.track,
    required this.isFavorite,
    required this.onFavorite,
  });

  final Track track;
  final bool isFavorite;
  final VoidCallback onFavorite;

  @override
  State<_TrackInfo> createState() => _TrackInfoState();
}

class _TrackInfoState extends State<_TrackInfo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
  );

  late final Animation<double> _popScale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 1.3,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 38,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.3,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 62,
    ),
  ]).animate(_pop);

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  void _favorite() {
    _pop.forward(from: 0);
    widget.onFavorite();
  }

  String get _detail {
    final parts = <String>[];
    final extension = p
        .extension(widget.track.path)
        .replaceAll('.', '')
        .toUpperCase();
    if (extension.isNotEmpty) parts.add(extension);
    if (widget.track.year > 0) parts.add('${widget.track.year}');
    if (widget.track.bitrate > 0) parts.add('${widget.track.bitrate ~/ 1000} kbps');
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final track = widget.track;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                track.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.serif(size: 27, height: 1.08, spacing: -0.4),
              ),
              const SizedBox(height: 6),
              Text(
                track.displayArtist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.sans(size: 14, color: c.textDim),
              ),
              if (_detail.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  _detail,
                  style: context.numeric(size: 10.5, color: c.textFaint),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _favorite,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: ScaleTransition(
              scale: _popScale,
              child: Icon(
                widget.isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                size: 26,
                color: widget.isFavorite ? c.accent : c.textDim,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.playback});

  final PlaybackController playback;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _Toggle(
          icon: Icons.shuffle_rounded,
          active: playback.isShuffled,
          tooltip: 'Shuffle',
          onTap: () {
            Haptics.tap();
            playback.setShuffle(!playback.isShuffled);
          },
        ),
        _Skip(
          icon: Icons.skip_previous_rounded,
          onTap: playback.previous,
          tooltip: 'Previous',
        ),
        _Play(playback: playback),
        _Skip(
          icon: Icons.skip_next_rounded,
          onTap: playback.next,
          tooltip: 'Next',
        ),
        _Toggle(
          icon: playback.repeat == PlayerRepeatMode.one
              ? Icons.repeat_one_rounded
              : Icons.repeat_rounded,
          active: playback.repeat != PlayerRepeatMode.off,
          tooltip: playback.repeat.label,
          onTap: () {
            Haptics.tap();
            playback.cycleRepeat();
          },
        ),
      ],
    );
  }
}

class _Play extends StatefulWidget {
  const _Play({required this.playback});

  final PlaybackController playback;

  @override
  State<_Play> createState() => _PlayState();
}

class _PlayState extends State<_Play> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void initState() {
    super.initState();
    widget.playback.addListener(_syncPulse);
    _syncPulse();
  }

  @override
  void dispose() {
    widget.playback.removeListener(_syncPulse);
    _pulse.dispose();
    super.dispose();
  }

  /// The button breathes while music plays, and settles when it does not.
  void _syncPulse() {
    final active = widget.playback.playing && !widget.playback.buffering;
    if (active && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!active && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      onTap: () {
        Haptics.bump();
        widget.playback.toggle();
      },
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_pulse.value);
          return Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: c.accentFill,
              boxShadow: [
                BoxShadow(
                  color: c.accent.withValues(alpha: 0.3 + t * 0.16),
                  blurRadius: 24 + t * 12,
                  offset: const Offset(0, 10),
                  spreadRadius: -6,
                ),
              ],
            ),
            child: Transform.scale(scale: 1 + t * 0.025, child: child),
          );
        },
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: widget.playback.buffering
                ? SizedBox(
                    key: const ValueKey('buffering'),
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: c.onAccent,
                    ),
                  )
                : Icon(
                    widget.playback.playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    key: ValueKey(widget.playback.playing),
                    size: 38,
                    color: c.onAccent,
                  ),
          ),
        ),
      ),
    );
  }
}

class _Skip extends StatelessWidget {
  const _Skip({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: () {
        Haptics.tap();
        onTap();
      },
      iconSize: 34,
      icon: Icon(icon, color: context.c.text),
      style: IconButton.styleFrom(minimumSize: const Size(52, 52)),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.icon,
    required this.active,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 21,
                color: active ? c.accent : c.textDim,
              ),
              const SizedBox(height: 3),
              Container(
                width: 3.5,
                height: 3.5,
                decoration: BoxDecoration(
                  color: active ? c.accent : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.playback, required this.track});

  final PlaybackController playback;
  final Track track;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _Action(
          icon: Icons.lyrics_outlined,
          label: 'Lyrics',
          onTap: () => showLyricsSheet(context, track),
        ),
        _Action(
          icon: Icons.queue_music_rounded,
          label: 'Up next',
          onTap: () => showQueueSheet(context),
        ),
        ValueListenableBuilder<Duration?>(
          valueListenable: playback.sleepRemaining,
          builder: (context, remaining, _) {
            final atEnd = playback.sleepAtTrackEnd;
            final active = remaining != null || atEnd;
            return _Action(
              icon: Icons.bedtime_outlined,
              label: active
                  ? (atEnd
                        ? 'End'
                        : formatDuration(remaining!.inMilliseconds))
                  : 'Sleep',
              active: active,
              onTap: () => showSleepSheet(context),
            );
          },
        ),
        _Action(
          icon: Icons.speed_rounded,
          label: playback.speed == 1
              ? 'Speed'
              : '${playback.speed.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')}x',
          active: playback.speed != 1,
          onTap: () => showSpeedSheet(context),
        ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      onTap: () {
        Haptics.tap();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            Icon(
              icon,
              size: 21,
              color: active ? c.accent : c.textDim,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: context.sans(
                size: 10,
                weight: active ? 600 : 500,
                color: active ? c.accent : c.textFaint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
