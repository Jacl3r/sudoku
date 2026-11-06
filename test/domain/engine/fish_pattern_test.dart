import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/domain/engine/fish_pattern.dart';

/// Has-candidate built from a set of cells allowed to hold the digit 1.
HasCandidate _only(List<int> cells) =>
    (cell, digit) => digit == 1 && cells.contains(cell);

void main() {
  group('findFishPatterns', () {
    test('finds an X-Wing and its targets', () {
      // Digit 1 fits only in R1C1, R1C2, R5C1, R5C2, plus a target in R3C1.
      final has = _only([0, 1, 36, 37, 18]);
      final fish = findFishPatterns(
        digit: 1,
        size: 2,
        byRow: true,
        has: has,
      ).first;

      expect(fish.name, 'X-Wing');
      expect(fish.baseLines, [0, 4]);
      expect(fish.coverLines, [0, 1]);
      expect(fish.patternCells, {0, 1, 36, 37});
      expect(fish.targets, [18], reason: 'R3C1 sees both tips');
    });

    test('a line with three candidates is not part of an X-Wing', () {
      final has = _only([0, 1, 2, 36, 37]);
      final fish = findFishPatterns(digit: 1, size: 2, byRow: true, has: has);
      expect(fish, isEmpty);
    });

    test('reads columns as the base lines when asked', () {
      final has = _only([0, 9, 1, 10]);
      final fish = findFishPatterns(
        digit: 1,
        size: 2,
        byRow: false,
        has: has,
      ).first;
      expect(fish.name, 'X-Wing');
      expect(fish.baseLines, [0, 1]);
      expect(fish.patternCells, {0, 9, 1, 10});
    });

    test('finds a Swordfish of three lines', () {
      // Rows 1, 5 and 9 hold the digit in two of columns 1-3: C1+C2, C2+C3,
      // C1+C3, so the three rows cover three columns between them.
      final has = _only([0, 1, 37, 38, 72, 74]);
      final fish = findFishPatterns(
        digit: 1,
        size: 3,
        byRow: true,
        has: has,
      ).first;
      expect(fish.name, 'Swordfish');
      expect(fish.baseLines, [0, 4, 8]);
      expect(fish.patternCells, {0, 1, 37, 38, 72, 74});
    });

    test('a pattern with nothing to remove reports no targets', () {
      final has = _only([0, 1, 36, 37]);
      final fish = findFishPatterns(
        digit: 1,
        size: 2,
        byRow: true,
        has: has,
      ).first;
      expect(fish.targets, isEmpty);
    });
  });
}
