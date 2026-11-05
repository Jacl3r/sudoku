import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/domain/coach/coach.dart';
import 'package:sudoku/domain/coach/coach_step.dart';
import 'package:sudoku/domain/engine/game_engine.dart';
import 'package:sudoku/domain/engine/generator.dart';
import 'package:sudoku/domain/models/difficulty.dart';
import 'package:sudoku/domain/models/game_state.dart';
import 'package:sudoku/domain/models/puzzle.dart';

import '../../helpers/sudoku_grids.dart';

/// Stable description of a step, used to prove it is not repeated.
String _signature(CoachStep step) {
  final eliminations = [
    for (final entry in step.eliminations.entries)
      '${entry.key}:${(entry.value.toList()..sort()).join()}',
  ]..sort();
  final placement = step.placement;
  return '${step.technique}|${placement?.cell}:${placement?.digit}|'
      '${eliminations.join(',')}|'
      '${(step.restoreNotes.toList()..sort()).join()}'
      '|${step.erase}';
}

/// Walks a puzzle with the coach only. Every step must agree with the
/// solution. Returns the names of the techniques used.
List<String> _walk(Puzzle puzzle, {bool withNotes = false}) {
  final engine = GameEngine(
    GameState.newGame(puzzle: puzzle, difficulty: Difficulty.easy),
  );
  if (withNotes) engine.autoFillNotes();
  final used = <String>[];
  final seen = <String>{};
  for (var guard = 0; guard < 1000; guard++) {
    final state = engine.currentState;
    if (state.puzzleComplete) break;
    final step = nextCoachStep(state);
    if (step == null) break;
    expect(step.isMistake, isFalse, reason: 'no mistakes were made');
    expect(
      step.placement != null ||
          step.eliminations.isNotEmpty ||
          step.restoreNotes.isNotEmpty ||
          step.erase != null,
      isTrue,
      reason: '${step.technique} does nothing and would loop forever',
    );
    expect(
      seen.add(_signature(step)),
      isTrue,
      reason: '${step.technique} repeated the same step',
    );

    final placement = step.placement;
    if (placement != null) {
      expect(
        placement.digit,
        puzzle.solution.valueAt(placement.cell),
        reason: '${step.technique} placed a wrong digit',
      );
    }
    step.eliminations.forEach((cell, digits) {
      expect(
        digits.contains(puzzle.solution.valueAt(cell)),
        isFalse,
        reason: '${step.technique} removed the solution from $cell',
      );
    });
    used.add(step.technique);
    engine.applyCoachStep(step);
  }
  return used;
}

void main() {
  group('Coach', () {
    test('solves the simple puzzle with correct steps only', () {
      final puzzle = Puzzle(
        given: TestGrids.simplePuzzle(),
        solution: TestGrids.simpleSolution(),
      );
      _walk(puzzle);
      // The simple puzzle only needs singles.
    });

    test('never contradicts the solution on generated puzzles', () {
      for (final difficulty in Difficulty.values) {
        for (var n = 0; n < 2; n++) {
          final puzzle = generatePuzzle(difficulty);
          _walk(puzzle);
          _walk(puzzle, withNotes: true);
        }
      }
    }, timeout: const Timeout(Duration(seconds: 180)));

    test('points at a wrong digit before anything else', () {
      final puzzle = Puzzle(
        given: TestGrids.simplePuzzle(),
        solution: TestGrids.simpleSolution(),
      );
      final engine = GameEngine(
        GameState.newGame(puzzle: puzzle, difficulty: Difficulty.easy),
      );
      final empty = List.generate(
        81,
        (i) => i,
      ).firstWhere((i) => puzzle.given.valueAt(i) == 0);
      final wrong = puzzle.solution.valueAt(empty) % 9 + 1;
      engine.inputDigit(empty, wrong);

      final step = nextCoachStep(engine.currentState);
      expect(step?.erase, empty);

      engine.applyCoachStep(step!);
      expect(engine.currentState.grid.valueAt(empty), 0);
    });

    test('notices a note that removed the right digit', () {
      final puzzle = Puzzle(
        given: TestGrids.simplePuzzle(),
        solution: TestGrids.simpleSolution(),
      );
      final engine = GameEngine(
        GameState.newGame(puzzle: puzzle, difficulty: Difficulty.easy),
      );
      final empty = List.generate(
        81,
        (i) => i,
      ).firstWhere((i) => puzzle.given.valueAt(i) == 0);
      final wrongNote = puzzle.solution.valueAt(empty) % 9 + 1;
      engine.toggleNote(empty, wrongNote);

      final step = nextCoachStep(engine.currentState);
      expect(step?.restoreNotes, contains(empty));

      engine.applyCoachStep(step!);
      expect(
        engine.currentState.notes[empty],
        contains(puzzle.solution.valueAt(empty)),
      );
    });

    test('applying an elimination can be undone in one step', () {
      // Fill all notes, then walk until the first elimination.
      final puzzle = generatePuzzle(Difficulty.hard);
      final engine = GameEngine(
        GameState.newGame(puzzle: puzzle, difficulty: Difficulty.hard),
      )..autoFillNotes();
      for (var guard = 0; guard < 200; guard++) {
        final step = nextCoachStep(engine.currentState);
        if (step == null) return;
        if (step.eliminations.isEmpty) {
          engine.applyCoachStep(step);
          continue;
        }
        final beforeNotes = engine.currentState.notes
            .map(Set<int>.from)
            .toList();
        final beforeEliminations = [
          for (var i = 0; i < 81; i++)
            Set<int>.from(engine.currentState.coachEliminationsAt(i)),
        ];
        engine
          ..applyCoachStep(step)
          ..undo();
        expect(engine.currentState.notes, beforeNotes);
        expect([
          for (var i = 0; i < 81; i++)
            engine.currentState.coachEliminationsAt(i),
        ], beforeEliminations);
        return;
      }
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('player notes never change the step', () {
      final puzzle = generatePuzzle(Difficulty.hard);
      final engine = GameEngine(
        GameState.newGame(puzzle: puzzle, difficulty: Difficulty.hard),
      );
      final plain = nextCoachStep(engine.currentState)!;

      final empty = List.generate(
        81,
        (i) => i,
      ).firstWhere((i) => puzzle.given.valueAt(i) == 0);
      // A note that keeps the solution digit is a legal note the coach must
      // ignore rather than reason from.
      engine.toggleNote(empty, puzzle.solution.valueAt(empty));
      expect(
        _signature(nextCoachStep(engine.currentState)!),
        _signature(plain),
      );

      engine.autoFillNotes();
      expect(
        _signature(nextCoachStep(engine.currentState)!),
        _signature(plain),
      );
    });

    test('applying an elimination never re-offers it', () {
      final puzzle = generatePuzzle(Difficulty.hard);
      final engine = GameEngine(
        GameState.newGame(puzzle: puzzle, difficulty: Difficulty.hard),
      );
      var checked = 0;
      for (var guard = 0; guard < 300 && checked < 5; guard++) {
        final step = nextCoachStep(engine.currentState);
        if (step == null) break;
        final applied = {
          for (final entry in step.eliminations.entries)
            for (final digit in entry.value) (entry.key, digit),
        };
        final before = _signature(step);
        engine.applyCoachStep(step);
        if (engine.currentState.puzzleComplete) break;
        final next = nextCoachStep(engine.currentState);
        if (next != null) {
          expect(
            _signature(next),
            isNot(before),
            reason: 'the coach offered the same step again',
          );
          next.eliminations.forEach((cell, digits) {
            for (final digit in digits) {
              expect(
                applied.contains((cell, digit)),
                isFalse,
                reason: 're-offered $digit in $cell',
              );
            }
          });
        }
        if (applied.isNotEmpty) checked++;
      }
      expect(checked, greaterThan(0), reason: 'no elimination step was found');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('applying an elimination records it without inventing notes', () {
      final puzzle = generatePuzzle(Difficulty.hard);
      final engine = GameEngine(
        GameState.newGame(puzzle: puzzle, difficulty: Difficulty.hard),
      );
      for (var guard = 0; guard < 300; guard++) {
        final step = nextCoachStep(engine.currentState);
        if (step == null) return;
        if (step.eliminations.isEmpty) {
          engine.applyCoachStep(step);
          continue;
        }
        engine.applyCoachStep(step);
        final state = engine.currentState;
        expect(
          state.notes.every((n) => n.isEmpty),
          isTrue,
          reason: 'the coach invented notes on a digits-only board',
        );
        step.eliminations.forEach((cell, digits) {
          expect(state.coachEliminationsAt(cell), containsAll(digits));
        });
        return;
      }
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('eliminations only change cells that already have notes', () {
      final puzzle = generatePuzzle(Difficulty.hard);
      final engine = GameEngine(
        GameState.newGame(puzzle: puzzle, difficulty: Difficulty.hard),
      );
      for (var guard = 0; guard < 300; guard++) {
        final step = nextCoachStep(engine.currentState);
        if (step == null) return;
        if (step.eliminations.isEmpty) {
          engine.applyCoachStep(step);
          continue;
        }
        final target = step.eliminations.keys.first;
        final removed = step.eliminations[target]!;
        final kept = {1, 2, 3, 4, 5, 6, 7, 8, 9}.difference(removed).first;

        // The player wrote two candidates in the target cell; only the one the
        // step rules out may disappear.
        engine
          ..toggleNote(target, removed.first)
          ..toggleNote(target, kept)
          ..applyCoachStep(step);
        expect(engine.currentState.notes[target], {kept});
        expect(
          engine.currentState.coachEliminationsAt(target),
          containsAll(removed),
        );
        return;
      }
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('replacing a digit or noting over it also invalidates the ledger', () {
      final puzzle = generatePuzzle(Difficulty.hard);
      final engine = GameEngine(
        GameState.newGame(puzzle: puzzle, difficulty: Difficulty.hard),
      );
      var recorded = false;
      for (var guard = 0; guard < 300 && !recorded; guard++) {
        final step = nextCoachStep(engine.currentState);
        if (step == null) break;
        engine.applyCoachStep(step);
        recorded = engine.currentState.coachEliminations.any(
          (e) => e.isNotEmpty,
        );
      }
      expect(recorded, isTrue, reason: 'no elimination was recorded');

      final cell = List.generate(81, (i) => i).firstWhere(
        (i) =>
            puzzle.given.valueAt(i) == 0 &&
            engine.currentState.grid.valueAt(i) == 0,
      );
      final correct = puzzle.solution.valueAt(cell);
      final other = correct % 9 + 1;
      engine.inputDigit(cell, correct);
      final ledger = [
        for (var i = 0; i < 81; i++)
          Set<int>.from(engine.currentState.coachEliminationsAt(i)),
      ];

      engine.inputDigit(cell, other);
      expect(
        engine.currentState.coachEliminations.every((e) => e.isEmpty),
        isTrue,
        reason: 'replacing a digit must invalidate recorded deductions',
      );
      engine.undo();
      expect([
        for (var i = 0; i < 81; i++) engine.currentState.coachEliminationsAt(i),
      ], ledger);

      engine.toggleNote(cell, other);
      expect(
        engine.currentState.coachEliminations.every((e) => e.isEmpty),
        isTrue,
        reason: 'turning a digit into a note must invalidate deductions',
      );
      engine.undo();
      expect([
        for (var i = 0; i < 81; i++) engine.currentState.coachEliminationsAt(i),
      ], ledger);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('erasing a digit clears the ledger and undo restores it', () {
      final puzzle = generatePuzzle(Difficulty.hard);
      final engine = GameEngine(
        GameState.newGame(puzzle: puzzle, difficulty: Difficulty.hard),
      );
      var recorded = false;
      for (var guard = 0; guard < 300 && !recorded; guard++) {
        final step = nextCoachStep(engine.currentState);
        if (step == null) break;
        engine.applyCoachStep(step);
        recorded = engine.currentState.coachEliminations.any(
          (e) => e.isNotEmpty,
        );
      }
      expect(recorded, isTrue, reason: 'no elimination was recorded');

      final cell = List.generate(81, (i) => i).firstWhere(
        (i) =>
            puzzle.given.valueAt(i) == 0 &&
            engine.currentState.grid.valueAt(i) == 0,
      );
      engine.inputDigit(cell, puzzle.solution.valueAt(cell));
      final ledger = [
        for (var i = 0; i < 81; i++)
          Set<int>.from(engine.currentState.coachEliminationsAt(i)),
      ];
      engine.erase(cell);
      expect(
        engine.currentState.coachEliminations.every((e) => e.isEmpty),
        isTrue,
        reason: 'erasing a digit must invalidate recorded deductions',
      );
      engine.undo();
      expect([
        for (var i = 0; i < 81; i++) engine.currentState.coachEliminationsAt(i),
      ], ledger);
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('Coach patterns', () {
    int cell(int r, int c) => (r - 1) * 9 + (c - 1);

    /// Every cell holds every digit except 5, which only sits in [fives].
    CoachBoard boardWithFives(Set<int> fives) {
      final values = List<int>.filled(81, 0);
      final masks = List<int>.filled(81, 0);
      const digits = {1, 2, 3, 4, 6, 7, 8, 9};
      for (var i = 0; i < 81; i++) {
        for (final d in digits) {
          masks[i] |= 1 << (d - 1);
        }
        if (fives.contains(i)) masks[i] |= 1 << 4;
      }
      return CoachBoard(values, masks);
    }

    test('finds a Two-String Kite', () {
      // Row 1: R1C2, R1C7. Column 1: R2C1, R7C1. R1C2 and R2C1 share box 1.
      // Tips R1C7 and R7C1 both see R7C7.
      final board = boardWithFives({
        cell(1, 2),
        cell(1, 7),
        cell(2, 1),
        cell(7, 1),
        cell(7, 7),
      });
      final step = detectTwoStringKite(board);
      expect(step, isNotNull);
      expect(step!.technique, 'Two-String Kite');
      expect(step.eliminations, {
        cell(7, 7): {5},
      });
    });

    test('finds a Skyscraper', () {
      // Rows 1 and 4 share column 1. Tips R1C5 and R4C6 both see R2C6.
      final board = boardWithFives({
        cell(1, 1),
        cell(1, 5),
        cell(4, 1),
        cell(4, 6),
        cell(2, 6),
      });
      final step = detectSkyscraper(board);
      expect(step, isNotNull);
      expect(step!.technique, 'Skyscraper');
      expect(step.eliminations, {
        cell(2, 6): {5},
      });
      expect(step.patternCells, {
        cell(1, 1),
        cell(1, 5),
        cell(4, 1),
        cell(4, 6),
      });
    });
  });
}
