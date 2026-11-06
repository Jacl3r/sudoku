import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sudoku/presentation/shared/utils.dart';
import 'package:sudoku/providers/board_notifier.dart';
import 'package:sudoku/providers/coach_provider.dart';
import 'package:sudoku/providers/game_command.dart';
import 'package:sudoku/providers/game_notifier.dart';

/// Asks before restarting the current puzzle. Shared by the toolbar and the
/// `r` shortcut.
Future<void> confirmReset(BuildContext context, GameNotifier notifier) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Reset game?'),
      content: const Text(
        'This will restart the current puzzle. '
        'Your progress will be lost.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Reset'),
        ),
      ],
      actionsAlignment: .spaceBetween,
    ),
  );
  if (confirmed == true) {
    // Restarting resets the board's selection too, so the caller needs one call
    // rather than two.
    notifier.apply(const RestartGame());
  }
}

/// The hint sheet. Shared by the toolbar and the `h` shortcut.
Future<void> showHintSheet(
  BuildContext context,
  WidgetRef ref,
  GameNotifier notifier,
) async {
  await showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const .only(bottom: 48, top: 24),
        child: Column(
          mainAxisSize: .min,
          children: [
            Text('Hints', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.school_outlined),
              title: const Text('Next step'),
              subtitle: const Text('A tip in stages, not the answer'),
              onTap: () {
                Navigator.pop(ctx);
                final game = ref.read(gameProvider).value;
                if (game != null) {
                  ref.read(coachProvider.notifier).start(game);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.lightbulb_outline_rounded),
              title: const Text('Reveal a cell'),
              onTap: () {
                Navigator.pop(ctx);
                notifier.apply(const RevealHint());
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_circle_outline_rounded),
              title: const Text('Validate'),
              onTap: () {
                Navigator.pop(ctx);
                notifier.apply(const ValidateBoard());
              },
            ),
            ListTile(
              leading: const Icon(Icons.autorenew),
              title: const Text('Auto fill all notes'),
              onTap: () {
                Navigator.pop(ctx);
                notifier.apply(const FillNotes());
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class ActionRow extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(boardProvider);
    final boardNotifier = ref.read(boardProvider.notifier);
    final gameNotifier = ref.read(gameProvider.notifier);
    final isFinished = ref.watch(isFinishedProvider);

    return IgnorePointer(
      ignoring: isFinished,
      child: Row(
        spacing: 6,
        mainAxisAlignment: .spaceEvenly,
        children: [
          _ActionButton(
            icon: Icons.refresh_rounded,
            onTap: () => confirmReset(context, gameNotifier),
            tooltip: 'Reset',
            shortcut: 'R',
          ),
          _ActionButton(
            icon: Icons.lightbulb_outline_rounded,
            onTap: () => showHintSheet(context, ref, gameNotifier),
            tooltip: 'Hint',
            shortcut: 'H',
          ),
          _ActionButton(
            icon: Icons.edit_outlined,
            active: board.inputMode == .pencil,
            onTap: boardNotifier.toggleInputMode,
            tooltip: 'Pencil',
            shortcut: 'N',
          ),
          _ActionButton(
            icon: Icons.undo_rounded,
            onTap: () => gameNotifier.apply(const UndoStep()),
            tooltip: 'Undo',
            shortcut: 'U',
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const new({
    required this.icon,
    this.onTap,
    this.active = false,
    required this.tooltip,
    this.shortcut,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool active;
  final String tooltip;
  final String? shortcut;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = onTap == null
        ? scheme.onSurface.withValues(alpha: 0.3)
        : active
        ? scheme.surface
        : scheme.onSurface;

    return Tooltip(
      message: shortcut == null ? tooltip : shortcutHint(tooltip, shortcut!),
      child: InkWell(
        onTap: onTap,
        borderRadius: .circular(6),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: active ? scheme.primary : Colors.transparent,
            borderRadius: .circular(6),
          ),
          child: Icon(icon, color: color, size: 26),
        ),
      ),
    );
  }
}
