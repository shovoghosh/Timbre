import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../data/library/import_service.dart';
import '../../theme/theme_controller.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../shell/app_shell.dart';
import '../widgets/brand.dart';
import '../widgets/buttons.dart';
import '../widgets/cover.dart';
import '../widgets/pressable.dart';
import '../widgets/segmented.dart';
import '../widgets/snack.dart';

/// Three short steps before the first listen.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pages = PageController();
  int _index = 0;
  bool _scanning = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await Services.i.settings.setOnboarded(true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const AppShell()),
    );
  }

  void _next() {
    if (_index == 2) {
      _finish();
      return;
    }
    _pages.nextPage(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _scan() async {
    if (_scanning) return;
    setState(() => _scanning = true);
    final library = Services.i.library;
    final ok = await library.scan();
    if (!mounted) return;
    setState(() => _scanning = false);
    if (ok) {
      showSnack(
        context,
        library.songCount == 0
            ? 'No songs found yet'
            : 'Found ${library.songCount} songs',
      );
      _next();
    } else {
      showSnack(
        context,
        library.permissionBlocked
            ? 'Music access is blocked. You can allow it in Settings.'
            : 'You can scan later from the Library tab.',
      );
    }
  }

  Future<void> _import() async {
    final outcome = await const ImportService().pickAndImport();
    if (!mounted) return;
    if (outcome.cancelled) return;
    if (outcome.hasTracks) {
      await Services.i.library.addTracks(outcome.tracks);
      if (!mounted) return;
      showSnack(context, 'Imported ${outcome.tracks.length} songs');
      _next();
    } else {
      showSnack(context, 'Nothing was imported');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.canvas,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    c.accent.withValues(alpha: 0.18),
                    c.canvas,
                    c.canvas,
                  ],
                  stops: const [0, 0.45, 1],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
                  child: Row(
                    children: [
                      const BrandMark(size: 22),
                      const SizedBox(width: 8),
                      const Wordmark(size: 22),
                      const Spacer(),
                      TextButton(
                        onPressed: _finish,
                        child: Text(
                          'Skip',
                          style: context.sans(size: 13, color: c.textDim),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pages,
                    onPageChanged: (value) => setState(() => _index = value),
                    children: [
                      const _Welcome(),
                      _BringMusic(
                        scanning: _scanning,
                        onScan: _scan,
                        onImport: _import,
                      ),
                      const _MakeItYours(),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < 3; i++)
                            AnimatedContainer(
                              duration: Motion.base,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: i == _index ? 18 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: i == _index ? c.accent : c.lineStrong,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      PrimaryButton(
                        label: _index == 2 ? 'Start listening' : 'Next',
                        expand: true,
                        onPressed: _next,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: c.accentSoft,
              shape: BoxShape.circle,
              border: Border.all(color: c.accentLine),
            ),
            child: const Center(child: BrandMark(size: 44)),
          ),
          const SizedBox(height: 26),
          Text(
            'Your music,\nin its own order.',
            style: context.serif(size: 38, height: 1.04, spacing: -0.6),
          ),
          const SizedBox(height: 14),
          Text(
            'Timbre plays the files already on your phone. No account, no ads, '
            'nothing uploaded, and it works with the screen off.',
            style: context.sans(size: 14.5, color: c.textDim, height: 1.55),
          ),
          const SizedBox(height: 26),
          const _Point(icon: Icons.folder_open_rounded, text: 'You choose the folders'),
          const _Point(icon: Icons.album_outlined, text: 'Covers from your files'),
          const _Point(icon: Icons.insights_rounded, text: 'Listening stats you can share'),
        ],
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 17, color: c.accent),
          const SizedBox(width: 10),
          Text(
            text,
            style: context.sans(size: 13.5, color: c.text, weight: 500),
          ),
        ],
      ),
    );
  }
}

class _BringMusic extends StatelessWidget {
  const _BringMusic({
    required this.scanning,
    required this.onScan,
    required this.onImport,
  });

  final bool scanning;
  final VoidCallback onScan;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final library = Services.i.library;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('STEP TWO', style: context.overline(color: c.textFaint)),
          const SizedBox(height: 10),
          Text(
            'Bring your\nlibrary in.',
            style: context.serif(size: 34, height: 1.06, spacing: -0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'Timbre asks for audio access once, then lists the folders that '
            'hold music. You keep the ones you want. Nothing is copied or sent.',
            style: context.sans(size: 14, color: c.textDim, height: 1.55),
          ),
          const SizedBox(height: 22),
          _FolderPreview(),
          const SizedBox(height: 22),
          PrimaryButton(
            label: scanning ? 'Reading your library…' : 'Scan my music',
            icon: Icons.radar_rounded,
            expand: true,
            loading: scanning,
            onPressed: scanning ? null : onScan,
          ),
          const SizedBox(height: 10),
          QuietButton(
            label: 'Import files instead',
            icon: Icons.file_download_outlined,
            expand: true,
            onPressed: onImport,
            height: 50,
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              library.isScanning
                  ? 'Scanning now'
                  : 'You can do this later from the Library tab.',
              style: context.sans(size: 11.5, color: c.textFaint),
            ),
          ),
        ],
      ),
    );
  }
}

class _FolderPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final items = [
      ('Music', '142 songs', true),
      ('Podcasts', '18 clips', false),
      ('Ringtones', '6 clips', false),
    ];
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.xl),
        border: Border.all(color: c.line),
      ),
      child: Column(
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: item.$3 ? c.accentSoft : c.surfaceHigh,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      Icons.folder_rounded,
                      size: 17,
                      color: item.$3 ? c.accent : c.textFaint,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.$1,
                          style: context.sans(size: 13, weight: 500),
                        ),
                        Text(
                          item.$2,
                          style: context.sans(
                            size: 10.5,
                            color: c.textFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    item.$3
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    size: 18,
                    color: item.$3 ? c.accent : c.lineStrong,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MakeItYours extends StatelessWidget {
  const _MakeItYours();

  @override
  Widget build(BuildContext context) {
    final theme = Services.i.theme;
    return AnimatedBuilder(
      animation: theme,
      builder: (context, _) {
        final c = context.c;
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('LAST STEP', style: context.overline(color: c.textFaint)),
              const SizedBox(height: 10),
              Text(
                'Make it\nyours.',
                style: context.serif(size: 34, height: 1.06, spacing: -0.5),
              ),
              const SizedBox(height: 12),
              Text(
                'Pick a look now, change it any time. The accent can also follow '
                'the cover of whatever is playing.',
                style: context.sans(size: 14, color: c.textDim, height: 1.55),
              ),
              const SizedBox(height: 22),
              Segmented<ThemeChoice>(
                items: ThemeChoice.values
                    .map((value) => (value, value == ThemeChoice.system ? 'Auto' : value.label))
                    .toList(),
                selected: theme.choice,
                onSelect: theme.setChoice,
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final accent in accents)
                    Pressable(
                      onTap: () => theme.setAccent(accent),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.accent.id == accent.id
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
                            child: theme.accent.id == accent.id
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
                ],
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(Radii.lg),
                  border: Border.all(color: c.line),
                ),
                child: Row(
                  children: [
                    const Cover(seed: 'timbre-onboarding', size: 52, radius: 12),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Something for the walk home',
                            style: context.serif(size: 16),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'A preview of your new look',
                            style: context.sans(
                              size: 11,
                              color: c.textDim,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.play_arrow_rounded,
                      color: c.accent,
                      size: 26,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
