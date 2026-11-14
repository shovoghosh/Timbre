import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/format.dart';
import '../../core/services.dart';
import '../../theme/theme_controller.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../player/timer_sheets.dart';
import 'equalizer_page.dart';
import '../widgets/brand.dart';
import '../widgets/buttons.dart';
import '../widgets/page_header.dart';
import '../widgets/pressable.dart';
import '../widgets/segmented.dart';
import '../widgets/settings_rows.dart';
import '../widgets/sheets.dart';
import '../widgets/snack.dart';

/// Shared shell for a pushed settings page.
class SettingsScaffold extends StatelessWidget {
  const SettingsScaffold({
    super.key,
    required this.title,
    this.kicker,
    required this.children,
  });

  final String title;
  final String? kicker;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      wash: false,
      child: Column(
        children: [
          Padding(
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
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                PageHeader(
                  kicker: kicker,
                  title: title,
                  padding: const EdgeInsets.fromLTRB(
                    Space.page,
                    10,
                    Space.page,
                    8,
                  ),
                ),
                ...children,
                const SizedBox(height: Space.bottomClear),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const AppearancePage());

  @override
  Widget build(BuildContext context) {
    final theme = Services.i.theme;
    return AnimatedBuilder(
      animation: theme,
      builder: (context, _) {
        final c = context.c;
        return SettingsScaffold(
          kicker: 'Make it yours',
          title: 'Appearance',
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.page),
              child: _AppearancePreview(theme: theme),
            ),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.page),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Theme', style: context.sans(size: 13, weight: 600)),
                  const SizedBox(height: 8),
                  Segmented<ThemeChoice>(
                    items: ThemeChoice.values
                        .map(
                          (value) => (
                            value,
                            value == ThemeChoice.system ? 'Auto' : value.label,
                          ),
                        )
                        .toList(),
                    selected: theme.choice,
                    onSelect: theme.setChoice,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Text(
                        'Accent',
                        style: context.sans(size: 13, weight: 600),
                      ),
                      const SizedBox(width: 8),
                      if (theme.followsArtwork)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: c.accentSoft,
                            borderRadius: BorderRadius.circular(Radii.pill),
                          ),
                          child: Text(
                            'from cover',
                            style: context.sans(
                              size: 10.5,
                              weight: 600,
                              color: c.accent,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 9,
                    runSpacing: 9,
                    children: [
                      for (final accent in accents)
                        Pressable(
                          onTap: () => theme.setAccent(accent),
                          scale: 0.9,
                          child: Tooltip(
                            message: accent.name,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color:
                                      theme.accent.id == accent.id &&
                                          !theme.followsArtwork
                                      ? c.text
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: accent.color,
                                    shape: BoxShape.circle,
                                  ),
                                  child:
                                      theme.accent.id == accent.id &&
                                          !theme.followsArtwork
                                      ? Icon(
                                          Icons.check_rounded,
                                          size: 16,
                                          color: accent.usesInkText
                                              ? Colors.black
                                              : Colors.white,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SettingsGroup(
              children: [
                SwitchRow(
                  icon: Icons.palette_outlined,
                  title: 'Match the cover',
                  subtitle: 'Take the accent from the playing artwork.',
                  value: theme.dynamicAccent,
                  onChanged: theme.setDynamicAccent,
                ),
                SwitchRow(
                  icon: Icons.blur_on_rounded,
                  title: 'Frosted bars',
                  subtitle: 'Blur what sits behind the bar and mini player.',
                  value: theme.glass,
                  onChanged: theme.setGlass,
                ),
                SwitchRow(
                  icon: Icons.vibration_rounded,
                  title: 'Haptics',
                  subtitle: 'A small tap when you touch a control.',
                  value: theme.haptics,
                  onChanged: theme.setHaptics,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.page),
              child: QuietButton(
                label: 'Reset appearance',
                icon: Icons.restart_alt_rounded,
                expand: true,
                onPressed: theme.reset,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AppearancePreview extends StatelessWidget {
  const _AppearancePreview({required this.theme});

  final ThemeController theme;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final playback = Services.i.playback;
    final track = playback.current;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.xl),
        border: Border.all(color: c.line),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: c.accentFill,
            ),
            child: Center(
              child: BrandMark(size: 26, color: c.onAccent, gradient: false),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track?.title ?? 'This is your player',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.serif(size: 18, height: 1.1),
                ),
                const SizedBox(height: 3),
                Text(
                  track?.displayArtist ?? 'A preview of the current look',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.sans(size: 11.5, color: c.textDim),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.play_arrow_rounded, size: 14, color: c.accent),
                    const SizedBox(width: 4),
                    Text(
                      theme.choice.label,
                      style: context.sans(
                        size: 10.5,
                        weight: 600,
                        color: c.accent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PlaybackPage extends StatelessWidget {
  const PlaybackPage({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const PlaybackPage());

  @override
  Widget build(BuildContext context) {
    final settings = Services.i.settings;
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        final c = context.c;
        return SettingsScaffold(
          kicker: 'How it sounds',
          title: 'Playback',
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, 8),
              child: Container(
                padding: const EdgeInsets.all(16),
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
                        Text(
                          'Daily listening goal',
                          style: context.sans(size: 13.5, weight: 600),
                        ),
                        const Spacer(),
                        Text(
                          '${settings.dailyGoalMinutes} min',
                          style: context.numeric(size: 12, color: c.accent),
                        ),
                      ],
                    ),
                    Slider(
                      value: settings.dailyGoalMinutes.toDouble().clamp(5, 180),
                      min: 5,
                      max: 180,
                      divisions: 35,
                      activeColor: c.accent,
                      inactiveColor: c.line,
                      onChanged: (value) =>
                          settings.setDailyGoal((value / 5).round() * 5),
                    ),
                    Text(
                      'Used by the streak and the Home goal ring.',
                      style: context.sans(size: 11, color: c.textFaint),
                    ),
                  ],
                ),
              ),
            ),
            SettingsGroup(
              title: 'Transitions',
              children: [
                SwitchRow(
                  icon: Icons.graphic_eq_rounded,
                  title: 'Soft fades',
                  subtitle: 'Ease the volume in and out instead of cutting.',
                  value: settings.fade,
                  onChanged: settings.setFade,
                ),
                SwitchRow(
                  icon: Icons.bedtime_outlined,
                  title: 'Fade the sleep timer',
                  subtitle: 'Lower the volume before pausing.',
                  value: settings.sleepFade,
                  onChanged: settings.setSleepFade,
                ),
              ],
            ),
            const SizedBox(height: 22),
            SettingsGroup(
              title: 'Headphones',
              children: [
                SwitchRow(
                  icon: Icons.headphones_outlined,
                  title: 'Pause when unplugged',
                  subtitle: 'Stop the music if headphones disconnect.',
                  value: settings.pauseOnUnplug,
                  onChanged: settings.setPauseOnUnplug,
                ),
                SwitchRow(
                  icon: Icons.play_circle_outline_rounded,
                  title: 'Resume when plugged back in',
                  subtitle: 'Pick up where you stopped.',
                  value: settings.resumeOnPlug,
                  onChanged: settings.setResumeOnPlug,
                ),
              ],
            ),
            const SizedBox(height: 22),
            SettingsGroup(
              title: 'Audio',
              children: [
                SwitchRow(
                  icon: Icons.fast_forward_rounded,
                  title: 'Skip silence',
                  subtitle: 'Jump over long quiet gaps in a track.',
                  value: settings.skipSilence,
                  onChanged: settings.setSkipSilence,
                ),
                SwitchRow(
                  icon: Icons.volume_up_outlined,
                  title: 'Even out loudness',
                  subtitle: 'Quiet tracks come up to the same level.',
                  value: settings.normalizeVolume,
                  onChanged: settings.setNormalizeVolume,
                ),
              ],
            ),
            const SizedBox(height: 22),
            SettingsGroup(
              title: 'Tools',
              children: [
                SettingsRow(
                  icon: Icons.bedtime_outlined,
                  title: 'Sleep timer',
                  subtitle: 'Stop after a set time or this song',
                  onTap: () => showSleepSheet(context),
                ),
                SettingsRow(
                  icon: Icons.equalizer_rounded,
                  title: 'Equalizer',
                  subtitle: 'Bands, presets and bass',
                  onTap: () =>
                      Navigator.of(context).push(EqualizerPage.route()),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class LibrarySettingsPage extends StatelessWidget {
  const LibrarySettingsPage({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const LibrarySettingsPage());

  @override
  Widget build(BuildContext context) {
    final services = Services.i;
    final library = services.library;
    return AnimatedBuilder(
      animation: library,
      builder: (context, _) {
        final c = context.c;
        return SettingsScaffold(
          kicker: 'Your files',
          title: 'Library',
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, 6),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(Radii.lg),
                  border: Border.all(color: c.line),
                ),
                child: Row(
                  children: [
                    _MiniStat(value: '${library.songCount}', label: 'songs'),
                    _divider(c.line),
                    _MiniStat(value: '${library.albumCount}', label: 'albums'),
                    _divider(c.line),
                    _MiniStat(
                      value: formatBytes(library.totalBytes),
                      label: 'on disk',
                    ),
                  ],
                ),
              ),
            ),
            if (library.lastScanAt > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.page,
                  0,
                  Space.page,
                  8,
                ),
                child: Text(
                  'Last scan ${formatDay(library.lastScanAt)}',
                  style: context.sans(size: 11, color: c.textFaint),
                ),
              ),
            SettingsGroup(
              title: 'Sources',
              children: [
                SettingsRow(
                  icon: Icons.radar_rounded,
                  title: 'Scan again',
                  subtitle: 'Look for new or moved music',
                  onTap: () async {
                    final ok = await library.scan();
                    if (!context.mounted) return;
                    showSnack(
                      context,
                      ok
                          ? 'Found ${plural(library.songCount, 'song')}'
                          : 'Scan did not finish',
                    );
                  },
                ),
                SettingsRow(
                  icon: Icons.folder_open_rounded,
                  title: 'Choose folders',
                  subtitle: 'Include or skip folders',
                  onTap: () => _showFolders(context),
                ),
                SettingsRow(
                  icon: Icons.timer_outlined,
                  title: 'Hide short clips',
                  subtitle: 'Keep anything under 30 seconds out',
                  trailing: Switch.adaptive(
                    value: library.hideShortClips,
                    onChanged: library.setHideShortClips,
                  ),
                  onTap: () =>
                      library.setHideShortClips(!library.hideShortClips),
                ),
              ],
            ),
            const SizedBox(height: 22),
            SettingsGroup(
              title: 'Danger zone',
              children: [
                SettingsRow(
                  icon: Icons.delete_outline_rounded,
                  title: 'Clear the library',
                  subtitle: 'Forget the songs, keep the files',
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Clear the library?'),
                        content: const Text(
                          'Timbre forgets what it found. Your audio files stay where they are.',
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
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) await library.clearLibrary();
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _divider(Color color) => Container(
    width: 1,
    height: 34,
    margin: const EdgeInsets.symmetric(horizontal: 14),
    color: color,
  );

  void _showFolders(BuildContext context) {
    final library = Services.i.library;
    showTimbreSheet<void>(
      context,
      child: AnimatedBuilder(
        animation: library,
        builder: (context, _) {
          return SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.7,
            child: Column(
              children: [
                SheetHeader(
                  title: 'Folders',
                  subtitle: 'Turn a folder off to leave it out.',
                  trailing: SheetChip(plural(library.folders.length, 'folder')),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: library.folders.length,
                    itemBuilder: (context, index) {
                      final folder = library.folders[index];
                      final hidden = library.isFolderHidden(folder.path);
                      return SwitchListTile.adaptive(
                        value: !hidden,
                        onChanged: (value) =>
                            library.setFolderHidden(folder.path, !value),
                        title: Text(
                          folder.name,
                          style: context.sans(size: 14, weight: 500),
                        ),
                        subtitle: Text(
                          '${folder.path} · ${plural(folder.count, 'song')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.sans(
                            size: 11,
                            color: context.c.textFaint,
                          ),
                        ),
                        activeThumbColor: context.c.accent,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: QuietButton(
                          label: 'Include all',
                          expand: true,
                          onPressed: () => library.setAllFoldersHidden(false),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: QuietButton(
                          label: 'None',
                          expand: true,
                          onPressed: () => library.setAllFoldersHidden(true),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: context.serif(size: 22, height: 1)),
          const SizedBox(height: 3),
          Text(
            label,
            style: context.sans(size: 10.5, color: context.c.textFaint),
          ),
        ],
      ),
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const AboutPage());

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SettingsScaffold(
      kicker: 'The small print',
      title: 'About',
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, 12),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.xl),
              border: Border.all(color: c.line),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [c.accent.withValues(alpha: 0.16), c.surface],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    BrandMark(size: 34),
                    SizedBox(width: 12),
                    Wordmark(size: 30),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'A player for the music you already own. No account, no ads, '
                  'nothing uploaded.',
                  style: context.sans(size: 13, color: c.textDim, height: 1.5),
                ),
                const SizedBox(height: 10),
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    final version = snapshot.hasData
                        ? 'Version ${snapshot.data!.version} (${snapshot.data!.buildNumber})'
                        : 'Version 1.0.0';
                    return Text(
                      version,
                      style: context.numeric(size: 10.5, color: c.textFaint),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        SettingsGroup(
          children: [
            SettingsRow(
              icon: Icons.description_outlined,
              title: 'Licenses',
              subtitle: 'Open source packages and fonts',
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'Timbre',
                applicationVersion: '1.0.0',
                applicationIcon: const Padding(
                  padding: EdgeInsets.all(8),
                  child: BrandMark(size: 48),
                ),
              ),
            ),
            SettingsRow(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy',
              subtitle: 'What leaves this phone (almost nothing)',
              onTap: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Privacy'),
                  content: const SingleChildScrollView(
                    child: Text(
                      'Timbre reads the audio files you allow and keeps its '
                      'library, playlists and listening history on this phone.\n\n'
                      'It only goes online when you search for a cover, and then '
                      'sends the words you typed to the iTunes and Deezer search '
                      'APIs. Nothing else is uploaded, and there is no account or '
                      'analytics.',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ),
            const SettingsRow(
              icon: Icons.music_note_rounded,
              title: 'Made for local music',
              subtitle: 'Your songs never leave this device.',
              trailing: SizedBox.shrink(),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.page, 20, Space.page, 0),
          child: Text(
            'Type: Instrument Serif and Instrument Sans, used under the SIL '
            'Open Font License.',
            textAlign: TextAlign.center,
            style: context.sans(size: 10.5, color: c.textFaint, height: 1.5),
          ),
        ),
      ],
    );
  }
}
