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
