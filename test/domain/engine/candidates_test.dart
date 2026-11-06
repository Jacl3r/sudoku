import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/domain/engine/candidates.dart';

void main() {
  group('candidates', () {
    test('a filled cell has none', () {
      final values = List<int>.filled(81, 0)..[0] = 5;
      expect(possibleCandidates(values, 0), isEmpty);
    });

    test('peers of a placed digit lose that digit', () {
      final values = List<int>.filled(81, 0)..[0] = 5;
      // R1C2 shares a row, R2C1 shares a column, R2C2 shares the box.
      for (final peer in [1, 9, 10]) {
        expect(possibleCandidates(values, peer), isNot(contains(5)));
        expect(possibleCandidates(values, peer), hasLength(8));
      }
      // R5C5 sees none of them.
      expect(possibleCandidates(values, 40), hasLength(9));
    });

    test('the whole board matches the per-cell rule', () {
      final values = List<int>.filled(81, 0)
        ..[0] = 5
        ..[40] = 3;
      final all = candidatesFor(values);
      expect(all, hasLength(81));
      for (final i in [1, 9, 10, 4, 41, 49]) {
        expect(all[i], possibleCandidates(values, i));
      }
      expect(all[0], isEmpty);
    });
  });
}
