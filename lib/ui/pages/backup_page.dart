import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/format.dart';
import '../../data/settings/backup.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../widgets/buttons.dart';
import '../widgets/page_header.dart';
import '../widgets/settings_rows.dart';
import '../widgets/snack.dart';

/// Export and restore one JSON file with the listener's setup and history.
class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const BackupPage());

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool _busy = false;

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = await const BackupService().export();
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          subject: 'Timbre backup',
          text:
              'A Timbre backup with settings, playlists and listening history. '
              'Your music files are not included.',
        ),
      );
      if (!mounted) return;
      showSnack(context, 'Backup ready to save');
    } catch (error) {
      if (!mounted) return;
      showSnack(context, 'Could not make a backup');
      debugPrint('Timbre backup failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final files = await FilePicker.pickFiles(
        dialogTitle: 'Choose a Timbre backup',
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (files.isEmpty) return;
      final path = files.first.path;
      if (path == null) return;
      final file = File(path);
      final preview = await const BackupService().inspect(file);
      if (!mounted) return;
      if (preview == null) {
        showSnack(context, 'That file is not a Timbre backup');
        return;
      }
      final confirmed = await _confirm(preview);
      if (confirmed != true) return;
      final summary = await const BackupService().restore(file);
      if (!mounted) return;
      if (summary == null) {
        showSnack(context, 'Could not read that backup');
        return;
      }
      showSnack(
        context,
        'Restored ${plural(summary.playlists, 'playlist')}, '
        '${plural(summary.favorites, 'favorite')} and '
        '${plural(summary.plays, 'play')}',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _confirm(BackupPreview preview) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        final c = context.c;
        return AlertDialog(
          title: const Text('Restore this backup?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This replaces your playlists, favorites, ratings and history.',
                style: context.sans(size: 13.5, color: c.textDim, height: 1.5),
              ),
              const SizedBox(height: 14),
              _Row(label: 'Playlists', value: '${preview.playlists}'),
              _Row(label: 'Favorites', value: '${preview.favorites}'),
              _Row(label: 'Plays', value: '${preview.plays}'),
              _Row(label: 'Lyrics', value: '${preview.lyrics}'),
              _Row(
                label: 'Songs found here',
                value:
                    '${preview.matchedTracks} of ${preview.totalRefs}',
              ),
              const SizedBox(height: 10),
              Text(
                'Songs are matched by file path, then by file name, then by '
                'title and artist. Anything missing is skipped, not faked.',
                style: context.sans(size: 11.5, color: c.textFaint, height: 1.4),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Restore'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return PageScaffold(
      wash: false,
      child: ListView(
        padding: EdgeInsets.zero,
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
          const PageHeader(
            kicker: 'Move without losing it',
            title: 'Backup',
            padding: EdgeInsets.fromLTRB(Space.page, 10, Space.page, 8),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.page),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.xl),
                border: Border.all(color: c.accentLine),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [c.accent.withValues(alpha: 0.16), c.surface],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 24, color: c.accent),
                  const SizedBox(height: 12),
                  Text(
                    'One file, all your setup',
                    style: context.serif(size: 24, height: 1.1),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Settings, playlists, favorites, ratings, lyrics and '
                    'listening history. Your audio files are never included.',
                    style: context.sans(
                      size: 13,
                      color: c.textDim,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: _busy ? 'Working…' : 'Create a backup',
                    icon: Icons.ios_share_rounded,
                    expand: true,
                    loading: _busy,
                    onPressed: _export,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SettingsGroup(
            title: 'Restore',
            children: [
              SettingsRow(
                icon: Icons.restore_rounded,
                title: 'Choose a backup file',
                subtitle: 'Bring an old phone back',
                onTap: _import,
                trailing: Icon(
                  Icons.file_open_outlined,
                  size: 18,
                  color: c.textDim,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.page, 16, Space.page, 0),
            child: Text(
              'Timbre reads the backup before changing anything, then shows '
              'what it found. A backup from a different phone still finds songs '
              'that are stored in the same folders.',
              style: context.sans(size: 11.5, color: c.textFaint, height: 1.5),
            ),
          ),
          const SizedBox(height: Space.bottomClear),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: context.sans(
                size: 12.5,
                color: context.c.textDim,
              ),
            ),
          ),
          Text(
            value,
            style: context.sans(
              size: 12.5,
              weight: 600,
              color: context.c.text,
            ),
          ),
        ],
      ),
    );
  }
}
