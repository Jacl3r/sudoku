import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/domain/models/difficulty.dart';
import 'package:sudoku/domain/models/game_action.dart';
import 'package:sudoku/domain/models/game_state.dart';
import 'package:sudoku/domain/models/puzzle.dart';

import '../../helpers/sudoku_grids.dart';

void main() {
  final puzzle = Puzzle(
    given: TestGrids.simplePuzzle(),
    solution: TestGrids.simpleSolution(),
  );

  GameState base() {
    final eliminations = List<Set<int>>.generate(81, (_) => <int>{});
    eliminations[3] = {5};
    final notes = List<Set<int>>.generate(81, (_) => <int>{});
    notes[2] = {1, 2};
    notes[4] = {3};
    return GameState.newGame(
      puzzle: puzzle,
      difficulty: Difficulty.easy,
    ).copyWith(
      notes: notes,
      coachEliminations: eliminations,
      history: const [],
    );
  }

  group('UndoStep', () {
    test('restores one cell and leaves the other cells alone', () {
      final state = base().copyWith(
        notes: [for (final cell in base().notes) Set<int>.from(cell)],
      );
      final restored = const UndoStep(
        values: {2: 0},
        notes: {
          2: {9},
        },
      ).restore(state);

      expect(restored.notes[2], {9});
      expect(restored.notes[4], {
        3,
      }, reason: 'untouched cells keep their notes');
      expect(state.notes[2], {
        1,
        2,
      }, reason: 'restore does not mutate its input');
    });

    test('allNotes replaces the whole board', () {
      final all = List<Set<int>>.generate(81, (_) => <int>{});
      final restored = UndoStep(allNotes: all).restore(base());
      expect(restored.notes.every((cell) => cell.isEmpty), isTrue);
    });

    test('a null ledger leaves the current one alone', () {
      final restored = const UndoStep(allNotes: []).restore(base());
      // An empty allNotes list still replaces the notes; the ledger is untouched.
      expect(restored.coachEliminations[3], {5});
    });

    test('a short ledger restores at full length', () {
      final restored = const UndoStep(
        eliminations: [
          {7},
        ],
      ).restore(base());
      expect(restored.coachEliminations, hasLength(81));
      expect(restored.coachEliminations[0], {7});
      expect(restored.coachEliminations[3], isEmpty);
    });

    test('one step is trimmed from the history', () {
      const action = DigitAction(
        cellIndex: 2,
        previousValue: 0,
        previousNotes: {},
        newValue: 4,
      );
      final state = base().copyWith(history: [action]);
      expect(action.undo(state).history, isEmpty);
    });

    test('equality follows the values, not the insertion order', () {
      const a = UndoStep(
        values: {1: 0, 2: 5},
        notes: {
          1: {3, 4},
        },
      );
      const b = UndoStep(
        values: {2: 5, 1: 0},
        notes: {
          1: {4, 3},
        },
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('actions that differ only in their result are not equal', () {
      const first = AutoNotesAction(previousNotes: []);
      const second = AutoNotesAction(previousNotes: []);
      expect(first, second);
      expect(
        const DigitAction(
          cellIndex: 2,
          previousValue: 0,
          previousNotes: {},
          newValue: 4,
        ),
        isNot(
          const DigitAction(
            cellIndex: 2,
            previousValue: 0,
            previousNotes: {},
            newValue: 5,
          ),
        ),
      );
    });
  });
}
