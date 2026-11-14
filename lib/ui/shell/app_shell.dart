import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/haptics.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../pages/home_page.dart';
import '../pages/library_page.dart';
import '../pages/search_page.dart';
import '../pages/you_page.dart';
import '../player/player_page.dart';
import 'bottom_nav.dart';
import 'mini_player.dart';

/// The four-tab home of the app. Pages stay alive once visited, so returning to
/// Library keeps the scroll position and the search text.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  final _visited = <int>{0};

  void _select(int value) {
    if (value == _index) return;
    Haptics.tap();
    setState(() {
      _index = value;
      _visited.add(value);
    });
  }

  void _openPlayer() {
    Navigator.of(context).push(PlayerPage.route());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _index != 0) _select(0);
      },
      child: Scaffold(
        backgroundColor: c.canvas,
        body: Stack(
          children: [
            Positioned.fill(
              child: IndexedStack(
                index: _index,
                children: [
                  HomePage(
                    onOpenLibrary: () => _select(1),
                    onOpenYou: () => _select(3),
                  ),
                  _visited.contains(1) ? const LibraryPage() : const SizedBox.shrink(),
                  _visited.contains(2) ? const SearchPage() : const SizedBox.shrink(),
                  _visited.contains(3) ? const YouPage() : const SizedBox.shrink(),
                ],
              ),
            ),
            // Fades the page out behind the floating controls so rows never
            // fight with the mini player.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 240,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        c.canvas.withValues(alpha: 0),
                        c.canvas.withValues(alpha: 0.85),
                        c.canvas,
                      ],
                      stops: const [0, 0.55, 1],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSize(
                      duration: Motion.base,
                      curve: Motion.curve,
                      alignment: Alignment.bottomCenter,
                      child: MiniPlayer(onOpen: _openPlayer),
                    ),
                    BottomNav(index: _index, onSelect: _select),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Blurred scrim used behind sheets and the full player.
class Scrim extends StatelessWidget {
  const Scrim({super.key, this.opacity = 0.5});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(color: Colors.black.withValues(alpha: opacity)),
      ),
    );
  }
}
