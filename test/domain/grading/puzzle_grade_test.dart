import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/domain/engine/has_unique_solution.dart';
import 'package:sudoku/domain/grading/puzzle_grade.dart';
import 'package:sudoku/domain/models/difficulty.dart';
import 'package:sudoku/domain/models/puzzle.dart';
import 'package:sudoku/domain/models/sudoku_grid.dart';

/// Solvable with naked and hidden singles alone.
const _singlesOnly =
    '000253008700100000001000040008094000500000007109508000010000002000785000304020000';

/// The solver gets no further than medium techniques and then has to guess.
/// The old rule called this Medium. It needs chains to finish.
const _stuckAfterMedium =
    '002000045008092600047038002070300000300001050001050470005010398000080060803000000';

/// The solver gets stuck after hard techniques. The old generator handed this
/// out as Hard.
const _stuckAfterHard =
    '029600050040920070000005900000040020005003800010000700080000000103002507702000010';

PuzzleGrade _grade(String givens) {
  final given = SudokuGrid.fromString(givens);
  final solution = solveGrid(SudokuGrid.fromString(givens));
  return gradePuzzle(Puzzle(given: given, solution: solution!));
}

void main() {
  group('gradePuzzle', () {
    test('a singles-only puzzle is Easy and the coach can finish it', () {
      final grade = _grade(_singlesOnly);

      expect(grade.difficulty, Difficulty.easy);
      expect(grade.coachable, isTrue);
      expect(grade.score, isNotNull);
      expect(grade.fits(Difficulty.easy), isTrue);
    });

    test('an Easy puzzle does not fit the harder levels', () {
      final grade = _grade(_singlesOnly);

      expect(grade.fits(Difficulty.medium), isFalse);
      expect(grade.fits(Difficulty.hard), isFalse);
      expect(grade.fits(Difficulty.expert), isFalse);
    });

    test('a puzzle the solver cannot finish is Expert, however far it got', () {
      for (final givens in [_stuckAfterMedium, _stuckAfterHard]) {
        final grade = _grade(givens);

        expect(grade.difficulty, Difficulty.expert, reason: givens);
        expect(grade.fits(Difficulty.expert), isTrue, reason: givens);
        for (final level in [
          Difficulty.easy,
          Difficulty.medium,
          Difficulty.hard,
        ]) {
          expect(grade.fits(level), isFalse, reason: '$level $givens');
          expect(grade.fitsLoosely(level), isFalse, reason: '$level $givens');
        }
      }
    });

    test('a puzzle the coach cannot finish has no score', () {
      final grade = _grade(_stuckAfterHard);

      expect(grade.coachable, isFalse);
      expect(grade.score, isNull);
    });

    test('whatever fits also fits loosely', () {
      for (final givens in [_singlesOnly, _stuckAfterMedium, _stuckAfterHard]) {
        final grade = _grade(givens);

        for (final level in Difficulty.values) {
          if (!grade.fits(level)) continue;
          expect(grade.fitsLoosely(level), isTrue, reason: '$level $givens');
        }
      }
    });
  });
}
