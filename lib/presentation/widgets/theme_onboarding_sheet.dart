import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sudoku/presentation/models/theme_config.dart';
import 'package:sudoku/providers/theme_provider.dart';

/// Shown once on first launch so the palettes are discoverable when they
/// matter, instead of living permanently on the home screen.
class ThemeOnboardingSheet extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .start,
          children: [
            Text('Pick a look', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text('Change it any time in Settings → Appearance.', style: muted),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final config in builtInThemes.take(6))
                  _ThemeOption(config: config),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: .centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Keep default'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeOption extends ConsumerWidget {
  const new({required this.config});

  final ThemeConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeConfigProvider);
    final active =
        current.seedColor == config.seedColor &&
        current.brightness == config.brightness;
    final scheme = ColorScheme.fromSeed(
      seedColor: config.seedColor,
      brightness: config.brightness,
    );

    return GestureDetector(
      onTap: () {
        ref.read(themeConfigProvider.notifier).select(config);
        Navigator.of(context).pop();
      },
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: scheme.surface,
          shape: .circle,
          border: Border.all(
            color: active ? scheme.primary : scheme.outlineVariant,
            width: active ? 3 : 1,
          ),
        ),
        child: Center(
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(color: scheme.primary, shape: .circle),
          ),
        ),
      ),
    );
  }
}
