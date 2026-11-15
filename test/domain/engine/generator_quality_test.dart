// The report is the point of this file, so it prints.
// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/domain/coach/coach_walk.dart';
import 'package:sudoku/domain/engine/generator.dart';
import 'package:sudoku/domain/grading/puzzle_grade.dart';
import 'package:sudoku/domain/models/difficulty.dart';

/// Puzzles sampled per difficulty. Raise it for steadier numbers.
const _samples = 20;

/// Lowest, the 10th, 25th, 50th, 75th and 90th percentile, and highest.
String _spread(List<int> values) {
  if (values.isEmpty) return 'none';
  final sorted = values.toList()..sort();
  int at(double share) => sorted[((sorted.length - 1) * share).round()];
  return 'min ${sorted.first}, p10 ${at(0.1)}, p25 ${at(0.25)}, '
      'median ${at(0.5)}, p75 ${at(0.75)}, p90 ${at(0.9)}, '
      'max ${sorted.last} (${sorted.length} puzzles)';
}

/// The steps beyond singles in the coach's walk, e.g. "Skyscraper x1".
String _stepsBeyondSingles(CoachWalk walk) {
  final steps = <String, int>{};
  for (final technique in walk.techniques) {
    if (technique.label.endsWith('Single')) continue;
    steps[technique.label] = (steps[technique.label] ?? 0) + 1;
  }
  return [for (final e in steps.entries) '${e.key} x${e.value}'].join(', ');
}

void main() {
  test(
    'every generated puzzle fits the difficulty it was asked for',
    () {
      final misfits = <Difficulty, List<String>>{};

      for (final difficulty in Difficulty.values) {
        final misfitsHere = <String>[];
        final scores = <int>[];
        final lines = <String>[];
        final clueCounts = <int, int>{};
        var deadEnds = 0;
        var total = Duration.zero;
        var slowest = Duration.zero;

        for (var i = 0; i < _samples; i++) {
          final watch = Stopwatch()..start();
          final puzzle = generatePuzzle(difficulty);
          watch.stop();
          total += watch.elapsed;
          if (watch.elapsed > slowest) slowest = watch.elapsed;

          final givens = puzzle.given.values.join();
          final clues = puzzle.given.values.where((v) => v != 0).length;
          clueCounts[clues] = (clueCounts[clues] ?? 0) + 1;

          final grade = gradePuzzle(puzzle);
          if (!grade.fits(difficulty)) misfitsHere.add(givens);

          final score = grade.score;
          if (score == null) {
            deadEnds++;
          } else {
            scores.add(score);
          }
          lines.add(
            '$givens ${grade.difficulty.displayName} '
            '${score ?? 'dead end'}: '
            '${_stepsBeyondSingles(walkWithCoach(puzzle))}',
          );
        }

        misfits[difficulty] = misfitsHere;

        final clueSummary = [
          for (final count in clueCounts.keys.toList()..sort())
            '$count clues x${clueCounts[count]}',
        ].join(', ');

        print('--- ${difficulty.displayName} ($_samples puzzles) ---');
        print('do not fit: ${misfitsHere.length}');
        print('coach dead ends: $deadEnds');
        print(
          'time per puzzle: avg ${total.inMilliseconds ~/ _samples} ms, '
          'slowest ${slowest.inMilliseconds} ms',
        );
        print('clue counts: $clueSummary');
        print('coach score: ${_spread(scores)}');
        for (final line in lines) {
          print('  $line');
        }
      }

      for (final difficulty in Difficulty.values) {
        expect(
          misfits[difficulty],
          isEmpty,
          reason:
              '${difficulty.displayName} produced puzzles that do not fit '
              'that difficulty',
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 30)),
  );
}
