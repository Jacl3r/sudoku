import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/domain/models/difficulty.dart';
import 'package:sudoku/domain/models/game_action.dart';
import 'package:sudoku/domain/models/game_state.dart';
import 'package:sudoku/domain/models/puzzle.dart';

import '../../helpers/sudoku_grids.dart';

void main() {
  group('GameState coach eliminations', () {
    final puzzle = Puzzle(
      given: TestGrids.simplePuzzle(),
      solution: TestGrids.simpleSolution(),
    );

    GameState stateWithLedger() {
      final eliminations = List<Set<int>>.generate(81, (_) => <int>{});
      eliminations[3] = {5, 7};
      return GameState.newGame(
        puzzle: puzzle,
        difficulty: Difficulty.easy,
      ).copyWith(coachEliminations: eliminations);
    }

    Map<String, dynamic> encoded() =>
        jsonDecode(jsonEncode(stateWithLedger().toJson()))
            as Map<String, dynamic>;

    test('survive a save round trip', () {
      final restored = GameState.fromJson(encoded());
      expect(restored.coachEliminationsAt(3), {5, 7});
      expect(restored.coachEliminationsAt(4), isEmpty);
    });

    test('a save without the field loads with an empty ledger', () {
      final json = encoded()..remove('coachEliminations');
      final restored = GameState.fromJson(json);
      expect(restored.coachEliminationsAt(3), isEmpty);
      expect(restored.notes.length, 81);
    });
  });

  group('GameState history', () {
    final puzzle = Puzzle(
      given: TestGrids.simplePuzzle(),
      solution: TestGrids.simpleSolution(),
    );

    List<Set<int>> ledger(int cell, Set<int> digits) =>
        List<Set<int>>.generate(81, (_) => <int>{})..[cell] = digits;

    GameState stateWithHistory() => GameState.newGame(
      puzzle: puzzle,
      difficulty: Difficulty.expert,
    ).copyWith(
      history: [
        DigitAction(
          cellIndex: 2,
          previousValue: 0,
          newValue: 4,
          previousNotes: {
            2: {1, 9},
            10: {},
          },
          previousCoachEliminations: ledger(5, {7}),
        ),
        const PencilAction(
          cellIndex: 3,
          previousNotes: {1, 2},
          newNotes: {1, 2, 6},
          previousValue: 0,
        ),
        const EraseAction(
          cellIndex: 10,
          previousValue: 3,
          previousNotes: {3, 4},
        ),
        AutoNotesAction(
          previousNotes: List.generate(81, (_) => <int>{})..[3] = {1, 5},
        ),
        CoachNotesAction(
          previousNotes: List.generate(81, (_) => <int>{}),
          previousCoachEliminations: ledger(7, {2, 8}),
        ),
      ],
    );

    Map<String, dynamic> encoded(GameState state) =>
        jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>;

    test('every action type survives a save round trip', () {
      final state = stateWithHistory();
      final restored = GameState.fromJson(encoded(state));

      expect(restored.history, equals(state.history));
      expect(restored.history.length, 5);
    });

    test('a save without the field loads with an empty history', () {
      final json = encoded(stateWithHistory())..remove('history');
      final restored = GameState.fromJson(json);

      expect(restored.history, isEmpty);
      expect(restored.notes.length, 81);
    });

    test('empty elimination snapshots are left out of the save', () {
      final emptyLedger = List<Set<int>>.generate(81, (_) => <int>{});
      DigitAction action(List<Set<int>> snapshots) => DigitAction(
        cellIndex: 2,
        previousValue: 0,
        newValue: 4,
        previousNotes: const {},
        previousCoachEliminations: snapshots,
      );

      expect(
        action(emptyLedger).toJson().containsKey('eliminations'),
        isFalse,
      );
      expect(action(const []).toJson().containsKey('eliminations'), isFalse);

      final encodedLedger = action(ledger(5, {7})).toJson()['eliminations'];
      expect(encodedLedger, hasLength(81));
      expect((encodedLedger as List)[5], [7]);
    });
  });
}
