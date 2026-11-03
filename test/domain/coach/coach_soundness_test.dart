import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/domain/coach/coach.dart';
import 'package:sudoku/domain/coach/coach_step.dart';
import 'package:sudoku/domain/engine/game_engine.dart';
import 'package:sudoku/domain/engine/generator.dart';
import 'package:sudoku/domain/models/difficulty.dart';
import 'package:sudoku/domain/models/game_state.dart';

/// True when some completion of the candidate constraints puts [digit] in
/// [cell]. A deduction is only sound if this is false for everything it removes.
bool _keepsCandidate(
  List<int> values,
  List<Set<int>> candidates, {
  required int cell,
  required int digit,
}) {
  final grid = List<int>.from(values);
  final allowed = [for (final set in candidates) Set<int>.from(set)];

  if (grid[cell] != 0) return grid[cell] == digit;
  if (!allowed[cell].contains(digit)) return false;
  allowed[cell] = {digit};

  final rows = List<int>.filled(9, 0);
  final cols = List<int>.filled(9, 0);
  final boxes = List<int>.filled(9, 0);

  int box(int i) => (i ~/ 27) * 3 + (i % 9) ~/ 3;

  for (var i = 0; i < 81; i++) {
    final value = grid[i];
    if (value == 0) continue;
    final bit = 1 << (value - 1);
    final r = i ~/ 9;
    final c = i % 9;
    final b = box(i);
    if ((rows[r] & bit) != 0 || (cols[c] & bit) != 0 || (boxes[b] & bit) != 0) {
      return false;
    }
    rows[r] |= bit;
    cols[c] |= bit;
    boxes[b] |= bit;
  }

  var nodes = 0;

  bool solve() {
    if (++nodes > 300000) {
      throw StateError(
        'completion search exceeded 300000 nodes; shrink the position or '
        'raise the budget',
      );
    }

    var best = -1;
    var bestOptions = const <int>[];
    for (var i = 0; i < 81; i++) {
      if (grid[i] != 0) continue;
      final used = rows[i ~/ 9] | cols[i % 9] | boxes[box(i)];
      final options = [
        for (final d in allowed[i])
          if ((used & (1 << (d - 1))) == 0) d,
      ];
      if (options.isEmpty) return false;
      if (best == -1 || options.length < bestOptions.length) {
        best = i;
        bestOptions = options;
        if (options.length == 1) break;
      }
    }

    if (best == -1) return true;

    final r = best ~/ 9;
    final c = best % 9;
    final b = box(best);
    for (final digit in bestOptions) {
      final bit = 1 << (digit - 1);
      grid[best] = digit;
      rows[r] |= bit;
      cols[c] |= bit;
      boxes[b] |= bit;
      if (solve()) return true;
      grid[best] = 0;
      rows[r] &= ~bit;
      cols[c] &= ~bit;
      boxes[b] &= ~bit;
    }
    return false;
  }

  return solve();
}

void main() {
  group('Coach soundness', () {
    test('every elimination during a real solve is sound', () {
      var checked = 0;
      for (final difficulty in [Difficulty.hard, Difficulty.expert]) {
        final puzzle = generatePuzzle(difficulty);
        final engine = GameEngine(
          GameState.newGame(puzzle: puzzle, difficulty: difficulty),
        );

        for (var move = 0; move < 400; move++) {
          final state = engine.currentState;
          if (state.puzzleComplete) break;

          final values = state.grid.values;
          final board = CoachBoard.fromState(values, [
            for (var i = 0; i < 81; i++) state.coachEliminationsAt(i),
          ]);
          final candidates = [
            for (var i = 0; i < 81; i++) board.digitsAt(i).toSet(),
          ];

          // Early positions are nearly empty; proving a digit impossible there
          // costs far more than it is worth, and eliminations only start to
          // appear once the board is populated.
          final empty = values.where((v) => v == 0).length;
          if (empty <= 45) {
            for (final detect in coachDetectors) {
              final step = detect(board);
              if (step == null) continue;
              step.eliminations.forEach((cell, digits) {
                for (final digit in digits) {
                  expect(
                    _keepsCandidate(
                      values,
                      candidates,
                      cell: cell,
                      digit: digit,
                    ),
                    isFalse,
                    reason:
                        '${step.technique} removed $digit from '
                        '${cellName(cell)} at move $move, but some completion '
                        'keeps it',
                  );
                  checked++;
                }
              });
            }
          }

          final step = nextCoachStep(state);
          if (step == null) break;
          engine.applyCoachStep(step);
        }
      }

      expect(
        checked,
        greaterThan(0),
        reason: 'the oracle never ran, so this test proves nothing',
      );
    }, timeout: const Timeout(Duration(seconds: 300)));
  });
}
