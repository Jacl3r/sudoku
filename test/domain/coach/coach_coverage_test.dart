import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/domain/coach/coach.dart';
import 'package:sudoku/domain/engine/generator.dart';
import 'package:sudoku/domain/engine/techniques/techniques.dart';
import 'package:sudoku/domain/models/difficulty.dart';
import 'package:sudoku/domain/models/game_state.dart';
import 'package:sudoku/domain/models/hint.dart';
import 'package:sudoku/domain/models/sudoku_grid.dart';

void main() {
  group('Coach coverage', () {
    final techniques = allTechniques;

    /// One round of `solveLogically`: the first hint of the first technique that
    /// has any.
    Hint? nextSolverHint(SudokuGrid grid) {
      for (final technique in techniques) {
        final hints = technique.getHints(grid);
        if (hints.isNotEmpty) return hints.first;
      }
      return null;
    }

    test('has a step wherever the solver can make progress', () {
      var positions = 0;

      for (final difficulty in Difficulty.values) {
        for (var attempt = 0; attempt < 3; attempt++) {
          final puzzle = generatePuzzle(difficulty);
          final grid = SudokuGrid(values: puzzle.given.values);
          final eliminations = List<Set<int>>.generate(81, (_) => <int>{});

          for (var move = 0; move < 200; move++) {
            final hint = nextSolverHint(grid);
            if (hint == null) break;

            positions++;
            // The solver's state, handed to the coach: same digits, same
            // candidate removals.
            final state = GameState(
              puzzle: puzzle,
              difficulty: difficulty,
              grid: SudokuGrid(values: grid.values),
              notes: List.generate(81, (_) => <int>{}),
              history: const [],
              coachEliminations: [
                for (final set in eliminations) Set<int>.from(set),
              ],
            );
            expect(
              nextCoachStep(state),
              isNotNull,
              reason:
                  'the solver can progress at move $move on '
                  '${difficulty.displayName} but the coach found nothing',
            );

            hint.apply(grid);
            if (hint is IndirectHint) {
              eliminations[hint.cellIndex].addAll(hint.valuesToRemove);
            }
          }
        }
      }

      expect(
        positions,
        greaterThan(0),
        reason: 'the solver never had progress, so this test proves nothing',
      );
    }, timeout: const Timeout(Duration(seconds: 300)));
  });
}
