import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/data/services/puzzle_import_service.dart';
import 'package:sudoku/domain/models/difficulty.dart';
import 'package:sudoku/domain/models/game_state.dart';

import '../../helpers/puzzle_strings.dart';

void main() {
  group('PuzzleImportService', () {
    test(
      'loadPuzzleIntoGame returns GameState with computed difficulty',
      () async {
        final service = PuzzleImportService();
        final result = await service.loadPuzzleIntoGame(TestPuzzles.valid);
        expect(result, isA<GameState>());
        expect(result.difficulty, equals(Difficulty.easy));
      },
    );

    test('a puzzle the solver cannot finish is imported as Expert', () async {
      // The solver gets no further than medium techniques here and then has
      // to guess. The old rule imported this as Medium.
      const givens =
          '002000045008092600047038002070300000300001050001050470005010398000080060803000000';
      final service = PuzzleImportService();
      final result = await service.loadPuzzleIntoGame(givens);

      expect(result.difficulty, equals(Difficulty.expert));
      expect(result.puzzle.solution.values.contains(0), isFalse);
    });

    test('importPuzzle parses raw input then loads it', () async {
      final service = PuzzleImportService();
      final result = await service.importPuzzle(TestPuzzles.valid9Line);
      expect(result, isA<GameState>());
      expect(result.difficulty, equals(Difficulty.easy));
    });

    test('importPuzzle throws when raw input is not 81 digits', () async {
      final service = PuzzleImportService();
      expect(
        () => service.importPuzzle(TestPuzzles.tooShort),
        throwsA(isA<FormatException>()),
      );
    });

    test('loadPuzzleIntoGame throws for puzzle with no solution', () async {
      final service = PuzzleImportService();
      expect(
        () => service.loadPuzzleIntoGame(TestPuzzles.rowConflict),
        throwsA(isA<FormatException>()),
      );
    });

    test(
      'loadPuzzleIntoGame throws for puzzle with multiple solutions',
      () async {
        final service = PuzzleImportService();
        expect(
          () => service.loadPuzzleIntoGame(TestPuzzles.empty),
          throwsA(isA<FormatException>()),
        );
      },
    );
  });
}
