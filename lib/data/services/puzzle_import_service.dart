import 'package:sudoku/data/utils/puzzle_parser.dart';
import 'package:sudoku/domain/engine/has_unique_solution.dart';
import 'package:sudoku/domain/grading/puzzle_grade.dart';
import 'package:sudoku/domain/models/game_state.dart';
import 'package:sudoku/domain/models/puzzle.dart';
import 'package:sudoku/domain/models/sudoku_grid.dart';

class PuzzleImportService {
  new({this.parser = const PuzzleParser()});

  final PuzzleParser parser;

  Future<GameState> importPuzzle(String raw) async {
    return loadPuzzleIntoGame(parser.parse(raw));
  }

  Future<GameState> loadPuzzleIntoGame(String puzzleString) async {
    final given = SudokuGrid.fromString(puzzleString);
    if (!hasUniqueSolution(given)) {
      throw const FormatException(
        'The puzzle must have exactly one valid solution.',
      );
    }
    // The logical solver's own grid is not a reliable solution: when it has
    // to guess, its backtracking leaves cells empty.
    final solution = solveGrid(given);
    if (solution == null) {
      throw const FormatException('The puzzle has no solution.');
    }
    final puzzle = Puzzle(given: given, solution: solution);
    return GameState.newGame(
      puzzle: puzzle,
      difficulty: gradePuzzle(puzzle).difficulty,
    );
  }
}
