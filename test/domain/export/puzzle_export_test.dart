import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/domain/export/puzzle_export.dart';

void main() {
  final givens = List<int>.filled(81, 0)
    ..[0] = 5
    ..[80] = 9;
  final values = List<int>.from(givens)..[1] = 3;
  final notes = List<Set<int>>.generate(81, (_) => <int>{})..[2] = {1, 2};
  final export = PuzzleExport(values: values, givens: givens, notes: notes);

  group('PuzzleExport', () {
    test('line uses dots and 81 characters', () {
      final text = export.build(
        content: ExportContent.givens,
        format: ExportFormat.line,
      );
      expect(text.length, 81);
      expect(text[0], '5');
      expect(text[1], '.');
      expect(text[80], '9');
    });

    test('progress includes placed digits', () {
      final text = export.build(
        content: ExportContent.progress,
        format: ExportFormat.line,
      );
      expect(text.substring(0, 3), '53.');
    });

    test('grid has 11 lines', () {
      final text = export.build(
        content: ExportContent.givens,
        format: ExportFormat.grid,
      );
      expect(text.split('\n').length, 11);
    });

    test('pencilmarks use the player notes', () {
      final text = export.build(
        content: ExportContent.notes,
        format: ExportFormat.pencilmarks,
      );
      final lines = text.split('\n');
      expect(lines.length, 13);
      expect(lines[1].contains(' 12 '), isTrue);
    });

    test('link encodes 81 digits', () {
      final text = export.build(
        content: ExportContent.givens,
        format: ExportFormat.link,
      );
      expect(text, startsWith('https://www.sudokuwiki.org/sudoku.htm?bd=5'));
      expect(text.split('bd=').last.length, 81);
    });

    test('prompt wraps the board and asks for no solution', () {
      final text = export.build(
        content: ExportContent.notes,
        format: ExportFormat.line,
        withPrompt: true,
      );
      expect(text, contains('do not give me the solution'));
      expect(text.trim().split('\n').last.length, 81);
    });
  });
}
