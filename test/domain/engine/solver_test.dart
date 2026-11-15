import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/domain/engine/has_unique_solution.dart';
import 'package:sudoku/domain/models/sudoku_grid.dart';

import '../../helpers/sudoku_grids.dart';

void main() {
  group('Sudoku Solver', () {
    test('solves a simple puzzle', () {
      final grid = TestGrids.simplePuzzle();
      final solved = solveGrid(SudokuGrid(values: grid.values));

      expect(solved, isNotNull);
      expect(solved?.values.every((element) => element != 0), isTrue);
    });

    test('fills every cell of a puzzle that needs trial and error', () {
      const givens =
          '029600050040920070000005900000040020005003800010000700080000000103002507702000010';
      final solved = solveGrid(SudokuGrid.fromString(givens));

      expect(solved, isNotNull);
      expect(solved!.values.contains(0), isFalse);
      for (var i = 0; i < 81; i++) {
        final given = givens.codeUnitAt(i) - 48;
        if (given != 0) expect(solved.values[i], given);
      }
    });

    test('returns null for unsolvable puzzle', () {
      final unsolvableGrid = TestGrids.unsolvableGrid();
      final solved = solveGrid(SudokuGrid(values: unsolvableGrid.values));

      expect(solved, isNull);
    });

    test('hasUniqueSolution returns true for a puzzle with one solution', () {
      final grid = TestGrids.simplePuzzle();

      expect(hasUniqueSolution(SudokuGrid(values: grid.values)), isTrue);
    });

    test('hasUniqueSolution returns false for a puzzle with '
        'more than one solution', () {
      final emptyGrid = SudokuGrid();

      expect(hasUniqueSolution(SudokuGrid(values: emptyGrid.values)), isFalse);
    });
  });
}
