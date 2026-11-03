import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/domain/models/difficulty.dart';
import 'package:sudoku/domain/models/game_state.dart';
import 'package:sudoku/domain/models/puzzle.dart';
import 'package:sudoku/providers/coach_provider.dart';

import '../helpers/sudoku_grids.dart';

void main() {
  group('coachBoardKey', () {
    final puzzle = Puzzle(
      given: TestGrids.simplePuzzle(),
      solution: TestGrids.simpleSolution(),
    );
    final base = GameState.newGame(
      puzzle: puzzle,
      difficulty: Difficulty.easy,
    );
    final empty = List.generate(81, (i) => i).firstWhere(
      (i) => puzzle.given.valueAt(i) == 0,
    );

    test('ignores the player notes', () {
      final noted = List<Set<int>>.generate(81, (_) => <int>{});
      noted[empty] = {2, 3};
      expect(
        coachBoardKey(base.copyWith(notes: noted)),
        coachBoardKey(base),
      );
    });

    test('changes when an elimination is recorded', () {
      final eliminations = List<Set<int>>.generate(81, (_) => <int>{});
      eliminations[empty] = {5};
      expect(
        coachBoardKey(base.copyWith(coachEliminations: eliminations)),
        isNot(coachBoardKey(base)),
      );
    });

    test('changes when a digit is placed', () {
      final grid = base.grid.clone()..setValue(empty, 4);
      expect(coachBoardKey(base.copyWith(grid: grid)), isNot(coachBoardKey(base)));
    });
  });
}
