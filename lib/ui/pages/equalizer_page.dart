import 'package:flutter/material.dart';

import '../../audio/effects.dart';
import '../../core/services.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../widgets/buttons.dart';
import '../widgets/page_header.dart';
import '../widgets/snack.dart';

/// Equalizer, presets and bass boost for the current audio session.
class EqualizerPage extends StatefulWidget {
  const EqualizerPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const EqualizerPage());
  }

  @override
  State<EqualizerPage> createState() => _EqualizerPageState();
}

class _EqualizerPageState extends State<EqualizerPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final services = Services.i;
      final session = services.playback.player.androidAudioSessionId;
      if (session != null) services.effects.attach(session);
      services.effects.refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final effects = Services.i.effects;
    final c = context.c;
    return AnimatedBuilder(
      animation: effects,
      builder: (context, _) {
        final ready = effects.sessionId > 0;
        final supported = effects.info.supported;
        return PageScaffold(
          wash: false,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
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
              ),
              const SliverToBoxAdapter(
                child: PageHeader(
                  kicker: 'Shape the sound',
                  title: 'Equalizer',
                  padding: EdgeInsets.fromLTRB(Space.page, 10, Space.page, 8),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.page,
                    0,
                    Space.page,
                    0,
                  ),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
                    decoration: BoxDecoration(
                      color: effects.enabled && supported
                          ? c.accentSoft
                          : c.surface,
                      borderRadius: BorderRadius.circular(Radii.lg),
                      border: Border.all(
                        color: effects.enabled && supported
                            ? c.accentLine
                            : c.line,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: c.accent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(
                            Icons.equalizer_rounded,
                            size: 20,
                            color: supported ? c.accent : c.textFaint,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                !ready
                                    ? 'Waiting for a song'
                                    : supported
                                    ? (effects.enabled
                                          ? 'Equalizer on'
                                          : 'Equalizer off')
                                    : 'Not available here',
                                style: context.sans(size: 14.5, weight: 600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                !ready
                                    ? 'Play something and your phone bands load here.'
                                    : supported
                                    ? 'Changes the real sound of the player.'
                                    : 'This phone does not expose an equalizer to apps.',
                                style: context.sans(
                                  size: 11.5,
                                  color: c.textDim,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: ready && supported && effects.enabled,
                          onChanged: ready && supported
                              ? (value) => effects.setEnabled(value)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!ready)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.page,
                      20,
                      Space.page,
                      0,
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.play_circle_outline_rounded,
                          size: 34,
                          color: c.textFaint,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Start a song first',
                          textAlign: TextAlign.center,
                          style: context.serif(size: 22),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'The equalizer belongs to a playing session, so Timbre '
                          'loads your phone bands as soon as music starts.',
                          textAlign: TextAlign.center,
                          style: context.sans(
                            size: 13,
                            color: c.textDim,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        PrimaryButton(
                          label: 'Play from library',
                          icon: Icons.play_arrow_rounded,
                          onPressed: () {
                            final library = Services.i.library;
                            if (library.tracks.isEmpty) {
                              showSnack(context, 'Add some music first');
                              return;
                            }
                            Services.i.playback.playQueue(
                              library.tracks,
                              label: 'Library',
                            );
                            showSnack(
                              context,
                              'Playing. Bands will appear in a moment.',
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              if (ready && !supported)
                const SliverToBoxAdapter(
                  child: EmptyState(
                    icon: Icons.equalizer_rounded,
                    title: 'No system equalizer',
                    message:
                        'Timbre can only adjust the phone equalizer on Android. '
                        'On iPhone, use the sound options in Control Center.',
                    compact: true,
                  ),
                ),
              if (ready && supported) ...[
                SliverToBoxAdapter(child: _Presets(effects: effects)),
                SliverToBoxAdapter(child: _Bands(effects: effects)),
                if (effects.info.hasBassBoost)
                  SliverToBoxAdapter(child: _Bass(effects: effects)),
              ],
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.page,
                    20,
                    Space.page,
                    0,
                  ),
                  child: Column(
                    children: [
                      QuietButton(
                        label: 'Open phone sound settings',
                        icon: Icons.tune_rounded,
                        expand: true,
                        onPressed: () async {
                          final opened = await effects.openSystemPanel();
                          if (!context.mounted) return;
                          if (!opened) {
                            showSnack(
                              context,
                              'Your phone does not offer a sound panel',
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Bands follow what your phone provides, usually five. '
                        'Timbre never fakes a band the hardware cannot play.',
                        textAlign: TextAlign.center,
                        style: context.sans(
                          size: 11.5,
                          color: c.textFaint,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: Space.bottomClear),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Presets extends StatelessWidget {
  const _Presets({required this.effects});

  final AudioEffects effects;

  @override
  Widget build(BuildContext context) {
    final presets = effects.info.presets;
    // The reset chip already stands for Flat, so skip a device preset with the
    // same name instead of showing the word twice in a row.
    final flatIndex = presets.indexWhere(
      (preset) => _titleCase(preset).toLowerCase() == 'flat',
    );
    final flatSelected =
        effects.isFlat || (flatIndex >= 0 && effects.preset == flatIndex);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: 'Presets', size: 19),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Space.page),
            children: [
              _PresetChip(
                label: 'Flat',
                selected: flatSelected,
                onTap: () => effects.reset(),
              ),
              for (var i = 0; i < presets.length; i++)
                if (!(i == flatIndex))
                  _PresetChip(
                    label: _titleCase(presets[i]),
                    selected: effects.preset == i,
                    onTap: () => effects.setPreset(i, const []),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  static String _titleCase(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return 'Preset';
    return clean
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.base,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? c.accent : c.surfaceHigh,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: selected ? c.accent : c.line),
        ),
        child: Text(
          label,
          style: context.sans(
            size: 12.5,
            weight: selected ? 600 : 500,
            color: selected ? c.onAccent : c.textDim,
          ),
        ),
      ),
    );
  }
}

class _Bands extends StatelessWidget {
  const _Bands({required this.effects});

  final AudioEffects effects;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final bands = effects.info.bands;
    final levels = effects.levels;
    final minLevel = effects.info.minLevel.toDouble();
    final maxLevel = effects.info.maxLevel.toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          title: 'Bands',
          size: 19,
          action: 'Reset',
          onAction: () => effects.reset(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.page),
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(Radii.lg),
              border: Border.all(color: c.line),
            ),
            child: SizedBox(
              height: 210,
              child: Row(
                children: [
                  for (var i = 0; i < bands.length; i++)
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            _dbLabel(i < levels.length ? levels[i] : 0),
                            style: context.numeric(
                              size: 10,
                              color: i < levels.length && levels[i] != 0
                                  ? c.accent
                                  : c.textFaint,
                            ),
                          ),
                          Expanded(
                            child: RotatedBox(
                              quarterTurns: 3,
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 2,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6,
                                  ),
                                  overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 12,
                                  ),
                                ),
                                child: Slider(
                                  value: (i < levels.length ? levels[i] : 0)
                                      .toDouble()
                                      .clamp(minLevel, maxLevel),
                                  min: minLevel,
                                  max: maxLevel,
                                  divisions: ((maxLevel - minLevel) / 100)
                                      .round()
                                      .clamp(1, 60),
                                  activeColor: c.accent,
                                  inactiveColor: c.line,
                                  onChanged: effects.enabled
                                      ? (value) => effects.setBandLevel(
                                          i,
                                          value.round(),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          ),
                          Text(
                            _freqLabel(bands[i]),
                            style: context.numeric(size: 9.5, color: c.textDim),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.page, 8, Space.page, 0),
          child: Text(
            effects.enabled
                ? 'Drag a band up to lift it, down to cut it.'
                : 'Turn the equalizer on to change the bands.',
            style: context.sans(size: 11.5, color: c.textFaint),
          ),
        ),
      ],
    );
  }

  static String _dbLabel(int millibels) {
    final db = millibels / 100;
    if (db.abs() < 0.05) return '0';
    return '${db > 0 ? '+' : ''}${db.toStringAsFixed(0)}';
  }

  static String _freqLabel(int hz) {
    if (hz >= 1000) {
      final value = hz / 1000;
      return '${value.toStringAsFixed(value >= 10 ? 0 : 1)}k';
    }
    return '$hz';
  }
}

class _Bass extends StatelessWidget {
  const _Bass({required this.effects});

  final AudioEffects effects;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final value = effects.bass.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: 'Bass boost', size: 19),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.page),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(Radii.lg),
              border: Border.all(color: c.line),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.speaker_rounded, size: 16, color: c.textDim),
                    Expanded(
                      child: Slider(
                        value: value,
                        activeColor: c.accent,
                        inactiveColor: c.line,
                        onChanged: effects.enabled
                            ? (next) => effects.setBass(next)
                            : null,
                      ),
                    ),
                    SizedBox(
                      width: 42,
                      child: Text(
                        '${(value * 100).round()}%',
                        textAlign: TextAlign.right,
                        style: context.numeric(size: 11, color: c.textDim),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Adds weight to the low end. Use it gently.',
                  style: context.sans(size: 11, color: c.textFaint),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
