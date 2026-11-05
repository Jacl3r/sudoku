import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sudoku/domain/models/imported_game.dart';
import 'package:sudoku/presentation/screens/game_screen.dart';
import 'package:sudoku/presentation/shared/utils.dart';
import 'package:sudoku/presentation/widgets/import_sudoku_dialog.dart';
import 'package:sudoku/providers/difficulty_provider.dart';
import 'package:sudoku/providers/game_notifier.dart';
import 'package:sudoku/providers/services_provider.dart';

/// Puzzles imported from outside the app, kept separately from the difficulty
/// slots so they can be worked on in parallel.
class ImportedPuzzlesScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final games = ref.watch(importedGamesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Imported puzzles')),
      floatingActionButton: IconButton(
        icon: const Icon(Icons.add),
        tooltip: 'Import a puzzle',
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => const ImportSudokuDialog(),
        ),
      ),
      floatingActionButtonLocation: .centerFloat,
      body: games.isEmpty
          ? Center(
              child: Padding(
                padding: const .all(24),
                child: Text(
                  'No imported puzzles yet.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const .only(bottom: 96),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: ListView.separated(
                    padding: const .all(12),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: games.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, index) => _ImportedRow(game: games[index]),
                  ),
                ),
              ),
            ),
    );
  }
}

class _ImportedRow extends ConsumerWidget {
  const new({required this.game});

  final ImportedGame game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filled = game.state.grid.values.where((v) => v != 0).length;
    final date = DateFormat('d MMM').format(game.savedAt);

    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: .circular(12)),
      tileColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      title: Text(game.state.difficulty.displayName),
      subtitle: Text(
        '$date · $filled of 81 · ${formatTime(game.state.elapsed)}',
      ),
      onTap: () {
        ref.read(difficultyProvider.notifier).set(game.state.difficulty);
        ref.read(activeSaveKeyProvider.notifier).set(game.key);
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => const GameScreen()));
      },
      trailing: PopupMenuButton<String>(
        tooltip: 'More',
        onSelected: (_) async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Delete this puzzle?'),
              content: const Text('Its progress will be lost.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
          if (confirmed != true || !context.mounted) return;
          await ref.read(saveGameServiceProvider).deleteImport(game.id);
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    );
  }
}
