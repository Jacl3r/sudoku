import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/domain/coach/coach_technique.dart';
import 'package:sudoku/domain/coach/coach_walk.dart';
import 'package:sudoku/domain/engine/has_unique_solution.dart';
import 'package:sudoku/domain/models/puzzle.dart';
import 'package:sudoku/domain/models/sudoku_grid.dart';

const _singlesOnly =
    '000253008700100000001000040008094000500000007109508000010000002000785000304020000';

const _needsChains =
    '029600050040920070000005900000040020005003800010000700080000000103002507702000010';

Puzzle _puzzle(String givens) {
  final given = SudokuGrid.fromString(givens);
  final solution = solveGrid(SudokuGrid.fromString(givens));
  return Puzzle(given: given, solution: solution!);
}

void main() {
  group('walkWithCoach', () {
    test('walks a singles-only puzzle to the end', () {
      final puzzle = _puzzle(_singlesOnly);

      expect(walkWithCoach(puzzle).finished, isTrue);
    });

    test('reports a dead end on a puzzle that needs chains', () {
      // One of the puzzles the old generator handed out as Hard. It has one
      // solution, but needs chain techniques the coach does not know.
      final puzzle = _puzzle(_needsChains);

      expect(walkWithCoach(puzzle).finished, isFalse);
    });

    test('scores a singles-only walk as the sum of its singles', () {
      final walk = walkWithCoach(_puzzle(_singlesOnly));
      final empty = _singlesOnly.split('').where((c) => c == '0').length;

      expect(walk.techniques, hasLength(empty));
      expect(
        walk.score,
        walk.techniques.fold<int>(0, (sum, t) => sum + t.score),
      );
      expect(
        walk.techniques.toSet().difference({
          CoachTechnique.hiddenSingle,
          CoachTechnique.nakedSingle,
        }),
        isEmpty,
      );
    });

    test('leaves the puzzle it was given untouched', () {
      final puzzle = _puzzle(_singlesOnly);

      walkWithCoach(puzzle);

      expect(puzzle.given.toString81(), _singlesOnly);
    });
  });
}
