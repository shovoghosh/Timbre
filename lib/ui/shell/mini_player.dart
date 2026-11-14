import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../audio/playback_controller.dart';
import '../../core/services.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../widgets/cover.dart';
import '../widgets/pressable.dart';

/// The always-available bar above the tabs. Tapping it opens the full player.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key, required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final playback = Services.i.playback;
    return AnimatedBuilder(
      animation: playback,
      builder: (context, _) {
        final track = playback.current;
        if (track == null) return const SizedBox(width: double.infinity);
        final c = context.c;

        final content = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 7, 6, 7),
              child: Row(
                children: [
                  Cover(
                    path: track.coverPath,
                    seed: track.id,
                    title: track.title,
                    artist: track.displayArtist,
                    size: 42,
                    radius: 11,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.sans(
                            size: 13,
                            weight: 600,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          track.displayArtist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.sans(
                            size: 11,
                            color: c.textDim,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  _MiniButton(
                    icon: playback.playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    filled: true,
                    onTap: playback.toggle,
                    tooltip: playback.playing ? 'Pause' : 'Play',
                  ),
                  _MiniButton(
                    icon: Icons.skip_next_rounded,
                    onTap: playback.next,
                    tooltip: 'Next',
                  ),
                ],
              ),
            ),
            _MiniProgress(playback: playback),
          ],
        );

        final panel = Material(
          color: c.surface.withValues(alpha: c.glass ? 0.9 : 1),
          child: InkWell(onTap: onOpen, child: content),
        );

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.lg),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: c.isDark ? 0.4 : 0.12),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                  spreadRadius: -8,
                ),
              ],
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.lg),
              border: Border.all(color: c.line),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.lg),
              child: c.glass
                  ? BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                      child: panel,
                    )
                  : panel,
            ),
          ),
        );
      },
    );
  }
}

class _MiniProgress extends StatelessWidget {
  const _MiniProgress({required this.playback});

  final PlaybackController playback;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      height: 2,
      child: AnimatedBuilder(
        animation: Listenable.merge([playback.position, playback.duration]),
        builder: (context, _) {
          final total = playback.duration.value.inMilliseconds;
          final fraction = total <= 0
              ? 0.0
              : playback.position.value.inMilliseconds / total;
          final percent = (fraction.clamp(0.0, 1.0) * 1000).round();
          return Row(
            children: [
              Expanded(
                flex: percent,
                child: Container(
                  color: percent == 0 ? Colors.transparent : c.accent,
                ),
              ),
              Expanded(
                flex: 1000 - percent,
                child: Container(color: c.line),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  const _MiniButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.filled = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: onTap,
        scale: 0.9,
        child: Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.only(left: 2),
          decoration: BoxDecoration(
            color: filled ? c.accent : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: filled ? 22 : 24,
            color: filled ? c.onAccent : c.text,
          ),
        ),
      ),
    );
  }
}
