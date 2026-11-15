// The report is the point of this file, so it prints.
// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/domain/coach/coach_walk.dart';
import 'package:sudoku/domain/coach/puzzle_score.dart';
import 'package:sudoku/domain/engine/generator.dart';
import 'package:sudoku/domain/engine/solver.dart';
import 'package:sudoku/domain/models/difficulty.dart';

/// Puzzles sampled per difficulty. Raise it for steadier numbers.
const _samples = 150;

/// Lowest, the 10th, 25th, 50th, 75th and 90th percentile, and highest.
String _spread(List<int> values) {
  if (values.isEmpty) return 'none';
  final sorted = values.toList()..sort();
  int at(double share) => sorted[((sorted.length - 1) * share).round()];
  return 'min ${sorted.first}, p10 ${at(0.1)}, p25 ${at(0.25)}, '
      'median ${at(0.5)}, p75 ${at(0.75)}, p90 ${at(0.9)}, '
      'max ${sorted.last} (${sorted.length} puzzles)';
}

void main() {
  test(
    'puzzles below Expert can be finished by the solver and the coach',
    () {
      final stuck = <Difficulty, List<String>>{};
      final coachDeadEnds = <Difficulty, List<String>>{};
      final unscored = <String>{};

      for (final difficulty in Difficulty.values) {
        final stuckHere = <String>[];
        final deadEndsHere = <String>[];
        final scores = <int>[];
        final walkLines = <String>[];
        final clueCounts = <int, int>{};
        final techniqueCounts = <String, int>{};
        var total = Duration.zero;
        var slowest = Duration.zero;

        for (var i = 0; i < _samples; i++) {
          final watch = Stopwatch()..start();
          final puzzle = generatePuzzle(difficulty);
          watch.stop();
          total += watch.elapsed;
          if (watch.elapsed > slowest) slowest = watch.elapsed;

          final values = puzzle.given.values;
          final clues = values.where((v) => v != 0).length;
          clueCounts[clues] = (clueCounts[clues] ?? 0) + 1;

          final result = solveLogically(puzzle.given);
          if (result.bruteForceUsed) stuckHere.add(values.join());

          final walk = walkWithCoach(puzzle);
          if (walk.finished) {
            scores.add(walk.score);
          } else {
            deadEndsHere.add(values.join());
          }
          final steps = <String, int>{};
          for (final technique in walk.techniques) {
            if (!techniqueScores.containsKey(technique)) {
              unscored.add(technique);
            }
            if (technique.endsWith('Single')) continue;
            steps[technique] = (steps[technique] ?? 0) + 1;
          }
          walkLines.add(
            '${walk.finished ? walk.score : 'dead end'}: '
            '${[for (final e in steps.entries) '${e.key} x${e.value}'].join(', ')}',
          );
          for (final technique in result.techniquesApplied.toSet()) {
            final name = '$technique';
            techniqueCounts[name] = (techniqueCounts[name] ?? 0) + 1;
          }
        }

        stuck[difficulty] = stuckHere;
        coachDeadEnds[difficulty] = deadEndsHere;

        final clueSummary = [
          for (final count in clueCounts.keys.toList()..sort())
            '$count clues x${clueCounts[count]}',
        ].join(', ');
        final techniqueSummary = [
          for (final name in techniqueCounts.keys.toList()..sort())
            '$name x${techniqueCounts[name]}',
        ].join(', ');

        print('--- ${difficulty.displayName} ($_samples puzzles) ---');
        print('stuck without guessing: ${stuckHere.length}');
        print('coach dead ends: ${deadEndsHere.length}');
        print(
          'time per puzzle: avg ${total.inMilliseconds ~/ _samples} ms, '
          'slowest ${slowest.inMilliseconds} ms',
        );
        print('clue counts: $clueSummary');
        print('coach score: ${_spread(scores)}');
        for (final line in walkLines) {
          print('  walk $line');
        }
        print('puzzles using each technique: $techniqueSummary');
        for (final puzzle in stuckHere) {
          print('  stuck: $puzzle');
        }
        for (final puzzle in deadEndsHere) {
          print('  coach dead end: $puzzle');
        }
      }

      expect(
        unscored,
        isEmpty,
        reason: 'these coach techniques have no entry in techniqueScores',
      );

      // Expert is allowed to be harder than the solver and the coach. The
      // others are not.
      for (final difficulty in Difficulty.values) {
        if (difficulty == Difficulty.expert) continue;
        expect(
          stuck[difficulty],
          isEmpty,
          reason:
              '${difficulty.displayName} produced puzzles that no technique '
              'in the app can finish',
        );
        expect(
          coachDeadEnds[difficulty],
          isEmpty,
          reason:
              '${difficulty.displayName} produced puzzles the coach cannot '
              'walk to the end',
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 30)),
  );
}
