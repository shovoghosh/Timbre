import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/haptics.dart';
import '../../core/services.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../widgets/sheets.dart';

Future<void> showSleepSheet(BuildContext context) async {
  final playback = Services.i.playback;
  final messenger = ScaffoldMessenger.of(context);

  await showTimbreSheet<void>(
    context,
    child: AnimatedBuilder(
      animation: playback,
      builder: (context, _) {
        final active = playback.hasSleepTimer;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetHeader(
              title: 'Sleep timer',
              subtitle: active
                  ? 'The music will stop gently.'
                  : 'Fade out and stop after a while.',
              trailing: active ? const SheetChip('ON') : null,
            ),
            if (active)
              ValueListenableBuilder<Duration?>(
                valueListenable: playback.sleepRemaining,
                builder: (context, remaining, _) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.c.accentSoft,
                        borderRadius: BorderRadius.circular(Radii.md),
                        border: Border.all(color: context.c.accentLine),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.bedtime_rounded,
                            size: 18,
                            color: context.c.accent,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              playback.sleepAtTrackEnd
                                  ? 'Stopping after this song'
                                  : 'Stopping in ${formatDuration((remaining ?? Duration.zero).inMilliseconds)}',
                              style: context.sans(
                                size: 13.5,
                                weight: 500,
                                color: context.c.text,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              playback.cancelSleep();
                              Navigator.of(context).pop();
                              messenger.hideCurrentSnackBar();
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Sleep timer cancelled'),
                                ),
                              );
                            },
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final minutes in [5, 10, 15, 30, 45, 60])
                    SizedBox(
                      width: (MediaQuery.sizeOf(context).width - 64) / 3,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.c.text,
                          side: BorderSide(color: context.c.line),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(Radii.md),
                          ),
                        ),
                        onPressed: () {
                          Haptics.tap();
                          playback.startSleep(Duration(minutes: minutes));
                          Navigator.of(context).pop();
                          messenger.hideCurrentSnackBar();
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Music stops in $minutes minutes'),
                            ),
                          );
                        },
                        child: Text(
                          '$minutes min',
                          style: context.sans(size: 13.5, weight: 500),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SheetTile(
              icon: Icons.music_off_rounded,
              label: 'End of this song',
              subtitle: 'Stop when the current track finishes',
              onTap: () {
                playback.sleepAfterCurrentTrack();
                Navigator.of(context).pop();
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
              child: Text(
                'Timbre fades the volume down before pausing.',
                style: context.sans(size: 11.5, color: context.c.textFaint),
              ),
            ),
          ],
        );
      },
    ),
  );
}

Future<void> showSpeedSheet(BuildContext context) async {
  final playback = Services.i.playback;
  const speeds = [0.5, 0.75, 0.8, 0.9, 1.0, 1.1, 1.25, 1.5, 1.75, 2.0];

  await showTimbreSheet<void>(
    context,
    child: AnimatedBuilder(
      animation: playback,
      builder: (context, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetHeader(
              title: 'Playback speed',
              subtitle: 'Saved for this song only.',
              trailing: SheetChip(
                '${playback.speed.toStringAsFixed(2)}x'.replaceAll('0x', 'x'),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 10),
                children: [
                  for (final speed in speeds)
                    SheetTile(
                      icon: speed == 1.0
                          ? Icons.restart_alt_rounded
                          : Icons.speed_rounded,
                      label: speed == 1.0
                          ? 'Normal'
                          : '${speed.toStringAsFixed(2).replaceAll(RegExp(r'0$'), '')}x',
                      selected: (playback.speed - speed).abs() < 0.001,
                      trailing: (playback.speed - speed).abs() < 0.001
                          ? Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: context.c.accent,
                            )
                          : null,
                      onTap: () {
                        playback.setSpeed(speed);
                        Navigator.of(context).pop();
                      },
                    ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}
