
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../data/library/cover_search.dart';
import '../../data/models/track.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../widgets/buttons.dart';
import '../widgets/cover.dart';
import '../widgets/sheets.dart';
import '../widgets/snack.dart';

/// Change the cover for a song or its whole album: pick a file or search online.
Future<void> showCoverSheet(BuildContext context, Track track) {
  return showTimbreSheet<void>(
    context,
    maxHeightFactor: 0.9,
    child: _CoverBody(track: track),
  );
}

class _CoverBody extends StatefulWidget {
  const _CoverBody({required this.track});

  final Track track;

  @override
  State<_CoverBody> createState() => _CoverBodyState();
}

class _CoverBodyState extends State<_CoverBody> {
  static const _search = CoverSearch();

  final _controller = TextEditingController();
  List<CoverHit> _hits = const [];
  bool _loading = true;
  String? _error;
  int? _applying;

  @override
  void initState() {
    super.initState();
    _controller.text = '${widget.track.displayArtist} ${widget.track.displayAlbum}';
    _run();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final hits = await _search.search(_controller.text);
      if (!mounted) return;
      setState(() {
        _hits = hits;
        _loading = false;
        _error = hits.isEmpty ? 'No covers found. Try fewer words.' : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Cover search needs a connection.';
      });
    }
  }

  Future<void> _applyHit(int index) async {
    final track = widget.track;
    final services = Services.i;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _applying = index);
    final file = await _search.download(_hits[index]);
    if (!mounted) return;
    if (file == null) {
      setState(() => _applying = null);
      showSnack(context, 'Could not download that cover');
      return;
    }
    await services.library.setCustomCover(track, file.path);
    if (!mounted) return;
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Cover updated')));
  }

  Future<void> _pickFile() async {
    final picked = await FilePicker.pickFiles(type: FileType.image);
    if (picked.isEmpty) return;
    final path = picked.first.path;
    if (path == null) return;
    await Services.i.library.setCustomCover(widget.track, path);
    if (!mounted) return;
    Navigator.of(context).pop();
    showSnack(context, 'Cover updated');
  }

  Future<void> _reset() async {
    await Services.i.library.clearCustomCover(widget.track);
    if (!mounted) return;
    Navigator.of(context).pop();
    showSnack(context, 'Back to the file cover');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.78,
      child: Column(
        children: [
          SheetHeader(
            title: 'Cover',
            subtitle: widget.track.title,
            trailing: SheetChip(
              widget.track.artKey == null ? 'this song' : 'whole album',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _run(),
                    style: context.sans(size: 14),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Artist, album',
                      filled: true,
                      fillColor: c.surfaceHigh,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(Radii.md),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleButton(
                  icon: Icons.search_rounded,
                  tooltip: 'Search',
                  onPressed: _run,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: QuietButton(
                    label: 'Choose a file',
                    icon: Icons.image_outlined,
                    expand: true,
                    onPressed: _pickFile,
                  ),
                ),
                const SizedBox(width: 8),
                CircleButton(
                  icon: Icons.restart_alt_rounded,
                  tooltip: 'Use the art inside the file',
                  onPressed: _reset,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: c.line),
          Expanded(child: _grid(c)),
        ],
      ),
    );
  }

  Widget _grid(TimbreColors c) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: context.sans(size: 13, color: c.textDim, height: 1.5),
              ),
              const SizedBox(height: 12),
              QuietButton(label: 'Try again', onPressed: _run),
            ],
          ),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemCount: _hits.length,
      itemBuilder: (context, index) {
        final hit = _hits[index];
        return GestureDetector(
          onTap: () => _applyHit(index),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  hit.url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Cover(
                    seed: hit.title,
                    title: hit.title,
                    radius: 10,
                  ),
                ),
              ),
              Positioned(
                left: 4,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    hit.source,
                    style: context.sans(
                      size: 8,
                      weight: 600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              if (_applying == index)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
