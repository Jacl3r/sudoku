import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/domain/coach/coach.dart';
import 'package:sudoku/domain/engine/game_engine.dart';
import 'package:sudoku/domain/engine/generator.dart';
import 'package:sudoku/domain/models/difficulty.dart';
import 'package:sudoku/domain/models/game_state.dart';
import 'package:sudoku/domain/models/puzzle.dart';

import '../../helpers/sudoku_grids.dart';

/// Walks a puzzle with the coach only. Every step must agree with the
/// solution. Returns the names of the techniques used.
List<String> _walk(Puzzle puzzle, {bool withNotes = false}) {
  final engine = GameEngine(
    GameState.newGame(puzzle: puzzle, difficulty: Difficulty.easy),
  );
  if (withNotes) engine.autoFillNotes();
  final used = <String>[];
  for (var guard = 0; guard < 1000; guard++) {
    final state = engine.currentState;
    if (state.puzzleComplete) break;
    final step = nextCoachStep(state);
    if (step == null) break;
    expect(step.isMistake, isFalse, reason: 'no mistakes were made');

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
      final empty = List.generate(81, (i) => i).firstWhere(
        (i) => puzzle.given.valueAt(i) == 0,
      );
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
      final empty = List.generate(81, (i) => i).firstWhere(
        (i) => puzzle.given.valueAt(i) == 0,
      );
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
        final before = engine.currentState.notes
            .map((s) => Set<int>.from(s))
            .toList();
        engine
          ..applyCoachStep(step)
          ..undo();
        expect(engine.currentState.notes, before);
        return;
      }
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  group('Coach patterns', () {
    int cell(int r, int c) => (r - 1) * 9 + (c - 1);

    /// Every cell holds every digit except 5, which only sits in [fives].
    CoachBoard boardWithFives(Set<int> fives) {
      final values = List<int>.filled(81, 0);
      final notes = List<Set<int>>.generate(
        81,
        (i) => {1, 2, 3, 4, 6, 7, 8, 9, if (fives.contains(i)) 5},
      );
      return CoachBoard.fromPlayer(values, notes);
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
