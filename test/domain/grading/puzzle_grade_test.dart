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

/// Real generated puzzles, graded once on CI. If one of these tests fails
/// after a change to the coach or the bands, the bands need measuring again.

/// Singles, two Pointing Pairs and a Box/Line Reduction.
const _plainMedium =
    '067401003000000008300729010005002100180006200006800400002068009004230001000000060';

/// Eight locked-candidates steps and a Skyscraper.
const _plainHard =
    '000200000130040000048000309020000001000536200600800000000097006400050000073000080';

/// Singles and one Skyscraper: Hard by its technique, too light for the band.
const _thinHard =
    '000700008004000065090400000300000001209040830070000020010567090000100000000090050';

/// Four XY-Wings and a Skyscraper: Hard by its technique, too long for the band.
const _longHard =
    '000280040005070008000901000200000609078500000009008400804092015000000000010004020';

/// Hard by its technique and inside the band, with at most two opening
/// singles. The generator handed it out as Expert.
const _tightHard =
    '052009000300001095900000000090305071030900006700010000000500809045800000200000000';

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

    test('a typical Medium fits Medium and nothing else', () {
      final grade = _grade(_plainMedium);

      expect(grade.difficulty, Difficulty.medium);
      expect(grade.fits(Difficulty.medium), isTrue);
      expect(grade.fits(Difficulty.easy), isFalse);
      expect(grade.fits(Difficulty.hard), isFalse);
      expect(grade.fits(Difficulty.expert), isFalse);
    });

    test('a typical Hard fits Hard and scores above the typical Medium', () {
      final hard = _grade(_plainHard);
      final medium = _grade(_plainMedium);

      expect(hard.difficulty, Difficulty.hard);
      expect(hard.fits(Difficulty.hard), isTrue);
      expect(hard.fits(Difficulty.medium), isFalse);
      expect(hard.score, greaterThan(medium.score!));
    });

    test('Hard by technique but outside the band keeps its label only', () {
      for (final givens in [_thinHard, _longHard]) {
        final grade = _grade(givens);

        expect(grade.difficulty, Difficulty.hard, reason: givens);
        expect(grade.coachable, isTrue, reason: givens);
        expect(grade.fits(Difficulty.hard), isFalse, reason: givens);
      }

      expect(
        _grade(_thinHard).score,
        lessThan(_grade(_plainHard).score!),
      );
      expect(
        _grade(_longHard).score,
        greaterThan(_grade(_plainHard).score!),
      );
    });

    test('the looser rule ignores the score', () {
      expect(_grade(_thinHard).fitsLoosely(Difficulty.hard), isTrue);
    });

    test('a Hard puzzle with a tight opening fits Hard and Expert', () {
      final grade = _grade(_tightHard);

      expect(grade.difficulty, Difficulty.hard);
      expect(grade.fits(Difficulty.hard), isTrue);
      expect(grade.fits(Difficulty.expert), isTrue);
    });

    test('whatever fits also fits loosely', () {
      for (final givens in [
        _singlesOnly,
        _stuckAfterMedium,
        _stuckAfterHard,
        _plainMedium,
        _plainHard,
        _thinHard,
        _longHard,
        _tightHard,
      ]) {
        final grade = _grade(givens);

        for (final level in Difficulty.values) {
          if (!grade.fits(level)) continue;
          expect(grade.fitsLoosely(level), isTrue, reason: '$level $givens');
        }
      }
    });
  });
}
