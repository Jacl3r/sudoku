import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/domain/coach/coach_walk.dart';
import 'package:sudoku/domain/coach/puzzle_score.dart';
import 'package:sudoku/domain/models/difficulty.dart';

void main() {
  group('coach score', () {
    test('adds up the score of every step in the walk', () {
      const walk = CoachWalk(
        finished: true,
        techniques: ['Hidden Single', 'Naked Single', 'X-Wing', 'X-Wing'],
      );

      expect(walk.score, 14 + 4 + 140 + 140);
    });

    test('charges a technique without a score as real work', () {
      expect(techniqueScore('Some New Technique'), unknownTechniqueScore);
      expect(unknownTechniqueScore, greaterThan(techniqueScore('Naked Pair')));
    });

    test('a harder technique never costs less than a single', () {
      final single = techniqueScore('Hidden Single');
      for (final entry in techniqueScores.entries) {
        if (entry.key.endsWith('Single')) continue;
        expect(entry.value, greaterThan(single), reason: entry.key);
      }
    });
  });

  group('score bands', () {
    test('Easy and Expert have none', () {
      expect(scoreBandFor(Difficulty.easy), isNull);
      expect(scoreBandFor(Difficulty.expert), isNull);
    });

    test('Hard starts above where Medium ends', () {
      final medium = scoreBandFor(Difficulty.medium)!;
      final hard = scoreBandFor(Difficulty.hard)!;

      expect(medium.min, lessThan(medium.max));
      expect(hard.min, greaterThan(medium.max));
      expect(hard.min, lessThan(hard.max));
    });

    test('a band includes both of its ends', () {
      const band = ScoreBand(10, 20);

      expect(band.contains(9), isFalse);
      expect(band.contains(10), isTrue);
      expect(band.contains(20), isTrue);
      expect(band.contains(21), isFalse);
    });
  });
}
