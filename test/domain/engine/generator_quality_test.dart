// The report is the point of this file, so it prints.
// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/domain/engine/generator.dart';
import 'package:sudoku/domain/engine/solver.dart';
import 'package:sudoku/domain/models/difficulty.dart';

/// Puzzles sampled per difficulty. Raise it for steadier numbers.
const _samples = 20;

void main() {
  test(
    'generated puzzles can be finished with the techniques the app knows',
    () {
      final stuck = <Difficulty, List<String>>{};

      for (final difficulty in Difficulty.values) {
        final stuckHere = <String>[];
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
          for (final technique in result.techniquesApplied.toSet()) {
            final name = '$technique';
            techniqueCounts[name] = (techniqueCounts[name] ?? 0) + 1;
          }
        }

        stuck[difficulty] = stuckHere;

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
        print(
          'time per puzzle: avg ${total.inMilliseconds ~/ _samples} ms, '
          'slowest ${slowest.inMilliseconds} ms',
        );
        print('clue counts: $clueSummary');
        print('puzzles using each technique: $techniqueSummary');
        for (final puzzle in stuckHere) {
          print('  stuck: $puzzle');
        }
      }

      // Expert is allowed to be harder than the solver. The others are not.
      for (final difficulty in Difficulty.values) {
        if (difficulty == Difficulty.expert) continue;
        expect(
          stuck[difficulty],
          isEmpty,
          reason:
              '${difficulty.displayName} produced puzzles that no technique '
              'in the app can finish',
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 30)),
  );
}
