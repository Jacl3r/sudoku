import 'package:flutter/services.dart';
import 'package:sudoku/domain/engine/has_unique_solution.dart';
import 'package:sudoku/domain/engine/solver.dart';
import 'package:sudoku/domain/models/game_state.dart';
import 'package:sudoku/domain/models/puzzle.dart';
import 'package:sudoku/domain/models/sudoku_grid.dart';

class PuzzleImportService {
  Future<void> sharePuzzle(GameState state) async {
    final puzzle = state.grid.values.join();
    await Clipboard.setData(ClipboardData(text: puzzle));
  }

  Future<GameState> loadPuzzleIntoGame(String puzzleString) async {
    final given = SudokuGrid.fromString(puzzleString);
    if (!hasUniqueSolution(given)) {
      throw const FormatException(
        'The puzzle must have exactly one valid solution.',
      );
    }
    final result = solveLogically(given);
    final puzzle = Puzzle(given: given, solution: result.solvedGrid);
    return GameState.newGame(
      puzzle: puzzle,
      difficulty: result.highestDifficultyLevel,
    );
  }
}
