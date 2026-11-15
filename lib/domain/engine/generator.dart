import 'dart:math';

import 'package:sudoku/domain/engine/grid_builder.dart';
import 'package:sudoku/domain/engine/has_unique_solution.dart';
import 'package:sudoku/domain/grading/puzzle_grade.dart';
import 'package:sudoku/domain/models/difficulty.dart';
import 'package:sudoku/domain/models/puzzle.dart';
import 'package:sudoku/domain/models/sudoku_grid.dart';

int noOfCluesForDifficulty(Difficulty difficulty) => switch (difficulty) {
  Difficulty.easy => 36,
  Difficulty.medium => 30,
  Difficulty.hard => 24,
  Difficulty.expert => 20,
};

/// How many near misses the generator digs before it hands one out anyway.
const nearMissLimit = 40;

class Generator {
  new({Random? random})
    : _builder = GridBuilder(random: random),
      _random = random ?? Random();

  final GridBuilder _builder;
  final Random _random;

  Puzzle _generate(Difficulty difficulty) {
    final solution = _builder.build();
    var nearMisses = 0;
    while (true) {
      final puzzle = Puzzle(
        given: _digHoles(SudokuGrid(values: solution.values), difficulty),
        solution: solution,
      );

      final grade = gradePuzzle(puzzle);
      if (grade.fits(difficulty)) return puzzle;

      // A near miss has the right level but the coach cannot finish it, or
      // its score is outside the band. After too many of them the looser
      // rule is enough, so a gap in the coach cannot make this search forever.
      if (!grade.fitsLoosely(difficulty)) continue;
      nearMisses++;
      if (nearMisses > nearMissLimit) return puzzle;
    }
  }

  SudokuGrid _digHoles(SudokuGrid solution, Difficulty difficulty) {
    final cells = List<int>.from(solution.values);
    final indices = List.generate(81, (i) => i)..shuffle(_random);

    final targetClues = noOfCluesForDifficulty(difficulty);

    var count = 81;
    for (final index in indices) {
      if (count <= targetClues) break;
      final backup = cells[index];
      cells[index] = 0;
      final grid = SudokuGrid(values: cells);
      if (!hasUniqueSolution(grid)) {
        cells[index] = backup;
      } else {
        count--;
      }
    }

    return SudokuGrid(values: cells);
  }
}

Puzzle generatePuzzle(Difficulty difficulty) =>
    Generator()._generate(difficulty);
