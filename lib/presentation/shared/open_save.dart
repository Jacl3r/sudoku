import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sudoku/domain/models/difficulty.dart';
import 'package:sudoku/presentation/screens/game_screen.dart';
import 'package:sudoku/providers/difficulty_provider.dart';
import 'package:sudoku/providers/game_notifier.dart';

/// Opens a saved game and shows the board.
///
/// The difficulty and the save key have to be set *before* the screen builds,
/// or [GameNotifier] loads the wrong game; that ordering used to be repeated at
/// every entry point, along with the route. Now it lives here.
void openSavedGame(
  BuildContext context,
  WidgetRef ref, {
  required String key,
  required Difficulty difficulty,
  bool replace = false,
}) {
  ref.read(difficultyProvider.notifier).set(difficulty);
  ref.read(activeSaveKeyProvider.notifier).set(key);

  final route = MaterialPageRoute<void>(builder: (_) => const GameScreen());
  final navigator = Navigator.of(context);
  if (replace) {
    navigator.pushReplacement(route);
  } else {
    navigator.push(route);
  }
}
