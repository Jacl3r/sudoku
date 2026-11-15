import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/domain/coach/coach_technique.dart';

void main() {
  group('CoachTechnique', () {
    test('every technique has its own name', () {
      final labels = CoachTechnique.values.map((t) => t.label).toSet();

      expect(labels, hasLength(CoachTechnique.values.length));
    });

    test('anything beyond a single costs more than a single', () {
      const singles = {CoachTechnique.nakedSingle, CoachTechnique.hiddenSingle};
      final dearestSingle = CoachTechnique.hiddenSingle.score;

      for (final technique in CoachTechnique.values) {
        if (singles.contains(technique)) continue;
        expect(
          technique.score,
          greaterThan(dearestSingle),
          reason: technique.label,
        );
      }
    });
  });
}
