import 'package:flutter/material.dart';

import '../../audio/playback_controller.dart';
import '../../core/services.dart';
import '../../data/library/lyrics_store.dart';
import '../../data/models/track.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../widgets/pressable.dart';
import '../widgets/sheets.dart';

/// Lyrics sheet with synced highlighting and a simple editor.
Future<void> showLyricsSheet(BuildContext context, Track track) async {
  final store = Services.i.lyrics;
  final playback = Services.i.playback;
  final lyrics = await loadLyrics(track, store);
  if (!context.mounted) return;

  await showTimbreSheet<void>(
    context,
    maxHeightFactor: 0.88,
    child: _LyricsBody(
      track: track,
      initial: lyrics,
      store: store,
      playback: playback,
    ),
  );
}

class _LyricsBody extends StatefulWidget {
  const _LyricsBody({
    required this.track,
    required this.initial,
    required this.store,
    required this.playback,
  });

  final Track track;
  final Lyrics initial;
  final LyricsStore store;
  final PlaybackController playback;

  @override
  State<_LyricsBody> createState() => _LyricsBodyState();
}

class _LyricsBodyState extends State<_LyricsBody> {
  late Lyrics _lyrics = widget.initial;
  final _scroll = ScrollController();
  final _keys = <int, GlobalKey>{};
  final _editor = TextEditingController();
  bool _editing = false;
  int _lastIndex = -1;

  @override
  void initState() {
    super.initState();
    _editor.text = widget.store.of(widget.track.id) ?? '';
  }

  @override
  void dispose() {
    _scroll.dispose();
    _editor.dispose();
    super.dispose();
  }

  void _scrollTo(int index) {
    if (index < 0 || index == _lastIndex) return;
    _lastIndex = index;
    final key = _keys[index];
    final context = key?.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: 0.38,
    );
  }

  Future<void> _save() async {
    final text = _editor.text.trim();
    await widget.store.set(widget.track.id, text);
    final reloaded = await loadLyrics(widget.track, widget.store);
    if (!mounted) return;
    setState(() {
      _lyrics = reloaded;
      _editing = false;
      _lastIndex = -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (_editing) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetHeader(
              title: 'Edit lyrics',
              subtitle:
                  'Paste plain words or a timed .lrc file. Timed lines follow the music.',
              trailing: TextButton(
                onPressed: () => setState(() => _editing = false),
                child: const Text('Cancel'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 300,
                decoration: BoxDecoration(
                  color: c.surfaceHigh,
                  borderRadius: BorderRadius.circular(Radii.md),
                  border: Border.all(color: c.line),
                ),
                child: TextField(
                  controller: _editor,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: context.sans(size: 14, height: 1.6),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(14),
                    hintText: '[00:12.00] First line\n[00:18.40] Second line',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Saved on this phone only.',
                      style: context.sans(size: 11.5, color: c.textFaint),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await widget.store.clear(widget.track.id);
                      _editor.clear();
                      if (!mounted) return;
                      setState(() {
                        _lyrics = const Lyrics(lines: [], synced: false);
                        _editing = false;
                      });
                    },
                    child: const Text('Delete'),
                  ),
                  const SizedBox(width: 6),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: c.accent,
                      foregroundColor: c.onAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Radii.pill),
                      ),
                    ),
                    onPressed: _save,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
        ),
      );
    }

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.74,
      child: Column(
        children: [
          SheetHeader(
            title: 'Lyrics',
            subtitle: widget.track.title,
            trailing: Pressable(
              onTap: () => setState(() => _editing = true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: c.surfaceHigh,
                  borderRadius: BorderRadius.circular(Radii.pill),
                  border: Border.all(color: c.line),
                ),
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 14, color: c.textDim),
                    const SizedBox(width: 6),
                    Text(
                      _lyrics.isEmpty ? 'Add' : 'Edit',
                      style: context.sans(size: 12, weight: 600, color: c.text),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _lyrics.isEmpty
                ? _EmptyLyrics(
                    onAdd: () => setState(() => _editing = true),
                  )
                : _lyrics.synced
                ? AnimatedBuilder(
                    animation: widget.playback,
                    builder: (context, _) {
                      final position = widget.playback.position.value;
                      final index = _lyrics.indexAt(position);
                      WidgetsBinding.instance.addPostFrameCallback(
                        (_) => _scrollTo(index),
                      );
                      return ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                        itemCount: _lyrics.lines.length,
                        itemBuilder: (context, i) {
                          final line = _lyrics.lines[i];
                          final active = i == index;
                          final passed = index >= 0 && i < index;
                          return Padding(
                            key: _keys.putIfAbsent(i, GlobalKey.new),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: AnimatedDefaultTextStyle(
                              duration: Motion.base,
                              style: context.serif(
                                size: active ? 26 : 22,
                                height: 1.25,
                                color: active
                                    ? c.text
                                    : passed
                                    ? c.textFaint
                                    : c.textDim,
                              ),
                              child: Text(line.text),
                            ),
                          );
                        },
                      );
                    },
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                    child: SelectableText(
                      _lyrics.lines.map((line) => line.text).join('\n'),
                      style: context.sans(
                        size: 15,
                        height: 1.75,
                        color: c.text,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyLyrics extends StatelessWidget {
  const _EmptyLyrics({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lyrics_outlined, size: 34, color: c.textFaint),
            const SizedBox(height: 14),
            Text(
              'No lyrics yet',
              style: context.serif(size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              'Paste words or a timed .lrc file. Timbre keeps them on this phone.',
              textAlign: TextAlign.center,
              style: context.sans(size: 13, color: c.textDim, height: 1.5),
            ),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: onAdd,
              style: OutlinedButton.styleFrom(
                foregroundColor: c.text,
                side: BorderSide(color: c.lineStrong),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
              ),
              child: const Text('Add lyrics'),
            ),
          ],
        ),
      ),
    );
  }
}
