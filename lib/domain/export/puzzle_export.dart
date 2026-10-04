import 'package:sudoku/domain/coach/coach.dart';
import 'package:sudoku/domain/models/game_state.dart';

/// What part of the game goes into the export.
enum ExportContent {
  givens('Puzzle', 'Just the starting digits.'),
  progress('Progress', 'Starting digits plus everything you placed.'),
  notes(
    'Notes',
    'Your digits and candidates. Cells without notes get every '
        'possible candidate.',
  );

  const ExportContent(this.label, this.description);
  final String label;
  final String description;
}

/// How the export is written.
enum ExportFormat {
  line('Digits', 'One line, dots for empty cells. Most apps import this.'),
  grid('Grid', 'Readable 9x9 text grid.'),
  pencilmarks(
    'Pencilmarks',
    'Grid with every candidate. Works with HoDoKu and similar solvers.',
  ),
  link('Link', 'Opens the board in the SudokuWiki solver.');

  const ExportFormat(this.label, this.description);
  final String label;
  final String description;
}

class PuzzleExport {
  const PuzzleExport({
    required this.values,
    required this.givens,
    required this.notes,
  });

  factory PuzzleExport.fromState(GameState state) => PuzzleExport(
    values: state.grid.values,
    givens: state.puzzle.given.values,
    notes: state.notes,
  );

  final List<int> values;
  final List<int> givens;
  final List<Set<int>> notes;

  /// Digits that are visible for the chosen content.
  List<int> digitsFor(ExportContent content) =>
      content == ExportContent.givens ? givens : values;

  /// Candidates per cell: the player's notes, otherwise everything possible.
  List<Set<int>> candidates() => [
    for (var i = 0; i < 81; i++)
      if (values[i] != 0)
        <int>{}
      else if (notes[i].isNotEmpty)
        Set<int>.from(notes[i])
      else
        possibleCandidates(values, i),
  ];

  String build({
    required ExportContent content,
    required ExportFormat format,
    bool withPrompt = false,
  }) {
    final body = switch (format) {
      ExportFormat.line => toLine(digitsFor(content)),
      ExportFormat.grid => toGrid(digitsFor(content)),
      ExportFormat.pencilmarks => toPencilmarks(
        content == ExportContent.notes ? values : digitsFor(content),
        content == ExportContent.notes
            ? candidates()
            : [
                for (var i = 0; i < 81; i++)
                  possibleCandidates(digitsFor(content), i),
              ],
      ),
      ExportFormat.link => toSudokuWikiLink(digitsFor(content)),
    };
    if (!withPrompt) return body;
    return _prompt(content: content, format: format, body: body);
  }

  static String toLine(List<int> digits) =>
      digits.map((v) => v == 0 ? '.' : '$v').join();

  static String toGrid(List<int> digits) {
    final buffer = StringBuffer();
    for (var r = 0; r < 9; r++) {
      if (r == 3 || r == 6) buffer.writeln('------+-------+------');
      final row = <String>[];
      for (var c = 0; c < 9; c++) {
        if (c == 3 || c == 6) row.add('|');
        final v = digits[r * 9 + c];
        row.add(v == 0 ? '.' : '$v');
      }
      buffer.writeln(row.join(' '));
    }
    return buffer.toString().trimRight();
  }

  /// HoDoKu-style pencilmark grid: solved cells show their digit, open
  /// cells show all candidates, columns padded to equal width per stack.
  static String toPencilmarks(List<int> digits, List<Set<int>> candidates) {
    String cellText(int i) {
      if (digits[i] != 0) return '${digits[i]}';
      final sorted = candidates[i].toList()..sort();
      return sorted.isEmpty ? '.' : sorted.join();
    }

    final widths = List<int>.filled(9, 1);
    for (var c = 0; c < 9; c++) {
      for (var r = 0; r < 9; r++) {
        final len = cellText(r * 9 + c).length;
        if (len > widths[c]) widths[c] = len;
      }
    }

    String separator(String left, String mid, String right) {
      final stacks = [
        for (var s = 0; s < 3; s++)
          '-' * (widths[s * 3] + widths[s * 3 + 1] + widths[s * 3 + 2] + 4),
      ];
      return '$left${stacks.join(mid)}$right';
    }

    final buffer = StringBuffer()..writeln(separator('.', '.', '.'));
    for (var r = 0; r < 9; r++) {
      if (r == 3 || r == 6) buffer.writeln(separator(':', '+', ':'));
      final line = StringBuffer('|');
      for (var c = 0; c < 9; c++) {
        line.write(' ${cellText(r * 9 + c).padRight(widths[c])}');
        if (c % 3 == 2) line.write(' |');
      }
      buffer.writeln(line);
    }
    buffer.write(separator("'", '.', "'"));
    return buffer.toString();
  }

  static String toSudokuWikiLink(List<int> digits) =>
      'https://www.sudokuwiki.org/sudoku.htm?bd=${digits.join()}';

  String _prompt({
    required ExportContent content,
    required ExportFormat format,
    required String body,
  }) {
    final state = switch (content) {
      ExportContent.givens => 'Here is the starting position.',
      ExportContent.progress =>
        'Here is my current position (starting digits plus my own).',
      ExportContent.notes =>
        'Here is my current position with my candidates. Cells I have not '
            'noted show every digit that is still possible.',
    };
    final notation = switch (format) {
      ExportFormat.line =>
        'Format: 81 characters, row by row, "." is an empty cell.',
      ExportFormat.grid => 'Format: 9x9 grid, "." is an empty cell.',
      ExportFormat.pencilmarks =>
        'Format: pencilmark grid, multi-digit entries are candidates.',
      ExportFormat.link =>
        'The board is encoded in this SudokuWiki link (81 digits, 0 = empty).',
    };
    return [
      'I am solving a classic 9x9 Sudoku and I am stuck. '
          'Please do not give me the solution.',
      '',
      'Find the next logical step from this exact position. '
          'Start with a small nudge: name the technique and the area to look '
          'at. Only explain the full step (cells, digits, eliminations) if I '
          'ask for it. Use R1C1 notation (row 1 to 9 from top, column 1 to 9 '
          'from left).',
      '',
      state,
      notation,
      '',
      body,
    ].join('\n');
  }
}
