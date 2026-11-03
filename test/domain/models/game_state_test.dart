import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/domain/models/difficulty.dart';
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
}
