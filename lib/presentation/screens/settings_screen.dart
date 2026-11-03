import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sudoku/presentation/models/app_settings.dart';
import 'package:sudoku/presentation/models/theme_config.dart';
import 'package:sudoku/presentation/screens/about_screen.dart';
import 'package:sudoku/presentation/screens/custom_colors_screen.dart';
import 'package:sudoku/presentation/widgets/game_preview.dart';
import 'package:sudoku/presentation/widgets/notes_grid.dart';
import 'package:sudoku/presentation/widgets/theme_swatch.dart';
import 'package:sudoku/providers/settings_provider.dart';
import 'package:sudoku/providers/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final themeConfig = ref.watch(themeConfigProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SingleChildScrollView(
        padding: const .only(bottom: 48),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: .start,
              children: [
                const _SectionHeader('Appearance'),
                Padding(
                  padding: const .symmetric(horizontal: 12),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (var i = 0; i < builtInThemes.length; i++)
                        ThemeSwatch(index: i, config: builtInThemes[i]),
                    ],
                  ),
                ),
                SwitchListTile(
                  title: const Text('True black'),
                  value: settings.trueBlackMode,
                  contentPadding: const .symmetric(horizontal: 12),
                  onChanged: (v) async {
                    await notifier.update((s) => s.copyWith(trueBlackMode: v));
                  },
                ),
                _VariantPicker(
                  selected: settings.schemeVariant,
                  seed: themeConfig.seedColor,
                  brightness: themeConfig.brightness,
                  onSelected: (v) async {
                    await notifier.update((s) => s.copyWith(schemeVariant: v));
                  },
                ),
                Consumer(
                  builder: (_, ref, _) {
                    final count = ref.watch(customThemeProvider).length;
                    return ListTile(
                      title: const Text('Custom colors'),
                      subtitle: Text(
                        count == 0
                            ? 'Add and manage your own themes'
                            : '$count',
                      ),
                      contentPadding: const .symmetric(horizontal: 12),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const CustomColorsScreen(),
                          ),
                        );
                      },
                    );
                  },
                ),

                const _SectionHeader('Board'),
                SwitchListTile(
                  title: const Text('Mask given cells'),
                  subtitle: const Text('Dim the digits the puzzle started with'),
                  value: settings.maskGivenCells,
                  contentPadding: const .symmetric(horizontal: 12),
                  onChanged: (v) async {
                    await notifier.update((s) => s.copyWith(maskGivenCells: v));
                  },
                ),
                SwitchListTile(
                  title: const Text('Highlight same digits'),
                  subtitle: const Text(
                    'Tint cells that hold or note the selected digit',
                  ),
                  value: settings.highlightSameDigits,
                  contentPadding: const .symmetric(horizontal: 12),
                  onChanged: (v) async {
                    await notifier.update(
                      (s) => s.copyWith(highlightSameDigits: v),
                    );
                  },
                ),
                SwitchListTile(
                  title: const Text('Show remaining counts'),
                  subtitle: const Text('Counts left per digit on the keypad'),
                  value: settings.showRemainingCounts,
                  contentPadding: const .symmetric(horizontal: 12),
                  onChanged: (v) async {
                    await notifier.update(
                      (s) => s.copyWith(showRemainingCounts: v),
                    );
                  },
                ),
                Padding(
                  padding: const .all(12),
                  child: Center(
                    child: GamePreview(
                      showRemainingCounts: settings.showRemainingCounts,
                      maskGivenCells: settings.maskGivenCells,
                      highlightSameDigits: settings.highlightSameDigits,
                      notesLayout: settings.notesLayout,
                      removeAnimations: settings.removeAnimations,
                    ),
                  ),
                ),

                const _SectionHeader('Notes'),
                Padding(
                  padding: const .all(12),
                  child: Column(
                    crossAxisAlignment: .stretch,
                    children: [
                      Row(
                        spacing: 12,
                        children: [
                          Expanded(
                            child: SegmentedButton<NotesLayout>(
                              segments: [
                                for (final layout in NotesLayout.values)
                                  ButtonSegment(
                                    value: layout,
                                    label: Text(layout.label),
                                  ),
                              ],
                              selected: {settings.notesLayout},
                              onSelectionChanged: (selection) {
                                notifier.update(
                                  (s) => s.copyWith(
                                    notesLayout: selection.first,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        settings.notesLayout.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _NotesLayoutDemo(selected: settings.notesLayout),
                    ],
                  ),
                ),
                SwitchListTile(
                  title: const Text('Remove notes automatically'),
                  subtitle: const Text(
                    'Clear a digit from neighbouring notes when you place it',
                  ),
                  value: settings.autoRemoveNotes,
                  contentPadding: const .symmetric(horizontal: 12),
                  onChanged: (v) async {
                    await notifier.update(
                      (s) => s.copyWith(autoRemoveNotes: v),
                    );
                  },
                ),

                const _SectionHeader('Game'),
                SwitchListTile(
                  title: const Text('Show timer'),
                  value: settings.showTimer,
                  contentPadding: const .symmetric(horizontal: 12),
                  onChanged: (v) async {
                    await notifier.update((s) => s.copyWith(showTimer: v));
                  },
                ),
                SwitchListTile(
                  title: const Text('Remove animations'),
                  subtitle: const Text('Skip transitions and cell movement'),
                  value: settings.removeAnimations,
                  contentPadding: const .symmetric(horizontal: 12),
                  onChanged: (v) async {
                    await notifier.update(
                      (s) => s.copyWith(removeAnimations: v),
                    );
                  },
                ),

                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About'),
                  subtitle: const Text('Version, license and links'),
                  contentPadding: const .symmetric(horizontal: 12),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AboutScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 24, 12, 8),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: .bold,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

const _variantOptions = [
  DynamicSchemeVariant.tonalSpot,
  DynamicSchemeVariant.fidelity,
  DynamicSchemeVariant.vibrant,
];

String _variantLabel(DynamicSchemeVariant variant) => switch (variant) {
  .tonalSpot => 'Default',
  .fidelity => 'Fidelity',
  .vibrant => 'Vibrant',
  _ => 'Custom',
};

String _variantDescription(DynamicSchemeVariant variant) => switch (variant) {
  .tonalSpot => 'Balanced: soft tints and muted accents.',
  .fidelity => 'Keeps colours closer to the chosen seed.',
  .vibrant => 'Stronger, more saturated accents.',
  _ => 'A Material colour scheme variant.',
};

/// One row per scheme variant, each showing the colours it would produce.
class _VariantPicker extends StatelessWidget {
  const _VariantPicker({
    required this.selected,
    required this.seed,
    required this.brightness,
    required this.onSelected,
  });

  final DynamicSchemeVariant selected;
  final Color seed;
  final Brightness brightness;
  final ValueChanged<DynamicSchemeVariant> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pageScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: .stretch,
      children: [
        for (final variant in _variantOptions)
          _VariantOption(
            variant: variant,
            selected: variant == selected,
            scheme: ColorScheme.fromSeed(
              seedColor: seed,
              brightness: brightness,
              dynamicSchemeVariant: variant,
            ),
            onTap: () => onSelected(variant),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Text(
            _variantDescription(selected),
            style: theme.textTheme.bodySmall?.copyWith(
              color: pageScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _VariantOption extends StatelessWidget {
  const _VariantOption({
    required this.variant,
    required this.selected,
    required this.scheme,
    required this.onTap,
  });

  final DynamicSchemeVariant variant;
  final bool selected;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pageScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: .circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Row(
              mainAxisSize: .min,
              spacing: 6,
              children: [
                for (final color in [
                  scheme.primary,
                  scheme.secondary,
                  scheme.tertiary,
                ])
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(_variantLabel(variant))),
            if (selected)
              Icon(Icons.check_rounded, size: 18, color: pageScheme.primary),
          ],
        ),
      ),
    );
  }
}

/// Two empty cells rendered with each notes layout, so the choice is visible.
class _NotesLayoutDemo extends StatelessWidget {
  const _NotesLayoutDemo({required this.selected});

  final NotesLayout selected;

  static const _notes = {1, 2, 4, 6, 8};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      children: [
        for (final layout in NotesLayout.values)
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  padding: const .all(4),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: .circular(6),
                    border: .all(
                      color: layout == selected
                          ? scheme.primary
                          : scheme.outlineVariant,
                      width: layout == selected ? 2 : 1,
                    ),
                  ),
                  child: switch (layout) {
                    .grid => const NotesGrid(notes: _notes, cellSize: 64),
                    .fixed => const FixedNotesGrid(notes: _notes, cellSize: 64),
                  },
                ),
                const SizedBox(height: 6),
                Text(
                  layout.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: layout == selected
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
