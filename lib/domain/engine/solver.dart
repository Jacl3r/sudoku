import 'package:sudoku/domain/engine/has_unique_solution.dart';
import 'package:sudoku/domain/engine/techniques/techniques.dart';
import 'package:sudoku/domain/models/difficulty.dart';
import 'package:sudoku/domain/models/solver_result.dart';
import 'package:sudoku/domain/models/sudoku_grid.dart';

SolverResult solveLogically(SudokuGrid grid) {
  final gridCopy = grid.clone();
  final techniquesApplied = <Type>[];
  var highestLevel = Difficulty.easy;
  bool progress;
  do {
    progress = false;
    for (final technique in allTechniques) {
      final hints = technique.getHints(gridCopy);
      if (hints.isNotEmpty) {
        hints[0].apply(gridCopy);
        techniquesApplied.add(technique.runtimeType);
        if (technique.level > highestLevel) {
          highestLevel = technique.level;
        }
        progress = true;
        break;
      }
    }
  } while (progress && !gridCopy.isSolved());

  // When the techniques run out, the rest of the solution comes from the
  // search. The half-solved grid is only kept if the puzzle has no solution.
  final bruteForceUsed = !gridCopy.isSolved();
  final solvedGrid = bruteForceUsed ? solveGrid(grid) ?? gridCopy : gridCopy;

  return SolverResult(
    highestDifficultyLevel: highestLevel,
    techniquesApplied: techniquesApplied,
    bruteForceUsed: bruteForceUsed,
    solvedGrid: solvedGrid,
  );
}
