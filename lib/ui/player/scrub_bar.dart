import 'package:flutter/material.dart';

import '../../audio/playback_controller.dart';
import '../../core/format.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';

/// Scrubbable progress line with live times. Drives the player and the mini
/// player.
class ScrubBar extends StatefulWidget {
  const ScrubBar({
    super.key,
    required this.playback,
    this.compact = false,
    this.showTimes = true,
    this.tint,
  });

  final PlaybackController playback;
  final bool compact;
  final bool showTimes;
  final Color? tint;

  @override
  State<ScrubBar> createState() => _ScrubBarState();
}

class _ScrubBarState extends State<ScrubBar> {
  bool _dragging = false;
  double _fraction = 0;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final playback = widget.playback;
    final height = widget.compact ? 3.0 : 5.0;
    final knob = widget.compact ? 0.0 : 9.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (details) {
                final total = playback.duration.value.inMilliseconds;
                if (total <= 0) return;
                setState(() {
                  _dragging = true;
                  _fraction = (details.localPosition.dx / width).clamp(0.0, 1.0);
                });
              },
              onHorizontalDragUpdate: (details) {
                if (!_dragging) return;
                setState(() {
                  _fraction = (details.localPosition.dx / width).clamp(0.0, 1.0);
                });
              },
              onHorizontalDragEnd: (_) {
                final total = playback.duration.value;
                final target = total * _fraction;
                setState(() => _dragging = false);
                playback.seek(target);
              },
              onHorizontalDragCancel: () => setState(() => _dragging = false),
              onTapDown: (details) {
                final total = playback.duration.value;
                if (total.inMilliseconds <= 0) return;
                final fraction = (details.localPosition.dx / width).clamp(0.0, 1.0);
                playback.seek(total * fraction);
              },
              child: SizedBox(
                height: widget.compact ? 22 : 30,
                child: AnimatedBuilder(
                  animation: Listenable.merge([
                    playback.position,
                    playback.duration,
                  ]),
                  builder: (context, _) {
                    final total = playback.duration.value.inMilliseconds;
                    final live = total <= 0
                        ? 0.0
                        : (playback.position.value.inMilliseconds / total)
                              .clamp(0.0, 1.0);
                    final fraction = _dragging ? _fraction : live;
                    return Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.centerLeft,
                      children: [
                        Container(
                          height: height,
                          decoration: BoxDecoration(
                            color: c.lineStrong,
                            borderRadius: BorderRadius.circular(height),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: fraction,
                          child: Container(
                            height: height,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(height),
                              gradient: LinearGradient(
                                colors: [
                                  widget.tint ?? c.accent,
                                  Color.lerp(
                                    widget.tint ?? c.accent,
                                    c.onAccent,
                                    0.35,
                                  )!,
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (knob > 0)
                          Positioned(
                            left: (width * fraction - knob / 2)
                                .clamp(-knob, width - 0),
                            top: (30 - knob * 2) / 2,
                            child: AnimatedContainer(
                              duration: Motion.fast,
                              width: _dragging ? knob * 1.5 : knob,
                              height: _dragging ? knob * 1.5 : knob,
                              decoration: BoxDecoration(
                                color: widget.tint ?? c.accent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: c.canvas.withValues(alpha: 0.7),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        if (_dragging && total > 0)
                          Positioned(
                            left: (width * _fraction - 26).clamp(0, width - 52),
                            top: -22,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: c.surfaceHigh,
                                borderRadius: BorderRadius.circular(Radii.pill),
                                border: Border.all(color: c.line),
                              ),
                              child: Text(
                                formatDuration((total * _fraction).round()),
                                style: context.numeric(
                                  size: 11,
                                  color: c.text,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        ),
        if (widget.showTimes) ...[
          const SizedBox(height: 2),
          AnimatedBuilder(
            animation: Listenable.merge([
              playback.position,
              playback.duration,
            ]),
            builder: (context, _) {
              final total = playback.duration.value;
              final live = playback.position.value;
              final shown = _dragging ? total * _fraction : live;
              final remaining = total - shown;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formatDuration(shown.inMilliseconds),
                    style: context.numeric(size: 11.5, color: c.textDim),
                  ),
                  Text(
                    remaining.inMilliseconds <= 0
                        ? '0:00'
                        : '-${formatDuration(remaining.inMilliseconds)}',
                    style: context.numeric(size: 11.5, color: c.textFaint),
                  ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}
