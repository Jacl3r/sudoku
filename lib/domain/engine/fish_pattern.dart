import 'package:sudoku/domain/engine/grid_utils.dart';

/// Whether [cell] is empty and can still hold [digit].
typedef HasCandidate = bool Function(int cell, int digit);

/// A fish: [size] lines (rows, or columns when [byRow] is false) where the
/// digit is confined to the same [size] cross lines.
///
/// X-Wing is size 2, Swordfish size 3. Both the solver's techniques and the
/// coach look for these, on their own candidate sources, so the geometry lives
/// here and only the source differs.
final class FishPattern {
  const new({
    required this.digit,
    required this.byRow,
    required this.baseLines,
    required this.coverLines,
    required this.patternCells,
    required this.targets,
  });

  final int digit;

  /// True when [baseLines] are rows and [coverLines] columns.
  final bool byRow;

  /// The lines holding the digit, ascending.
  final List<int> baseLines;

  /// The cross lines the digit is confined to, in discovery order.
  final List<int> coverLines;

  /// The cells of the pattern itself.
  final Set<int> patternCells;

  /// Cells outside the pattern that see all of it and can lose [digit], in
  /// discovery order.
  final List<int> targets;

  String get name => baseLines.length == 2 ? 'X-Wing' : 'Swordfish';

  Set<int> get focusCells => {
    for (final line in baseLines)
      ...(byRow ? kGridUnits[line] : kGridUnits[9 + line]),
  };
}

/// Every fish of [size] for [digit] in one orientation.
List<FishPattern> findFishPatterns({
  required int digit,
  required int size,
  required bool byRow,
  required HasCandidate has,
}) {
  final lines = <int, List<int>>{};
  for (var line = 0; line < 9; line++) {
    final units = byRow ? kGridUnits[line] : kGridUnits[9 + line];
    final cross = <int>[];
    for (final cell in units) {
      if (has(cell, digit)) cross.add(byRow ? cell % 9 : cell ~/ 9);
    }
    if (cross.length >= 2 && cross.length <= size) lines[line] = cross;
  }
  if (lines.length < size) return const [];

  final found = <FishPattern>[];
  for (final combo in _combinations(lines.keys.toList(), size)) {
    final cover = <int>{for (final line in combo) ...lines[line]!};
    if (cover.length != size) continue;

    final pattern = <int>{};
    for (final line in combo) {
      for (final cross in lines[line]!) {
        pattern.add(byRow ? line * 9 + cross : cross * 9 + line);
      }
    }

    final targets = <int>[
      for (final cross in cover)
        for (final cell in byRow ? kGridUnits[9 + cross] : kGridUnits[cross])
          if (!pattern.contains(cell) && has(cell, digit)) cell,
    ];

    found.add(
      FishPattern(
        digit: digit,
        byRow: byRow,
        baseLines: combo,
        coverLines: cover.toList(),
        patternCells: pattern,
        targets: targets,
      ),
    );
  }
  return found;
}

Iterable<List<T>> _combinations<T>(
  List<T> items,
  int k, [
  int start = 0,
]) sync* {
  if (k == 0) {
    yield <T>[];
    return;
  }
  for (var i = start; i <= items.length - k; i++) {
    for (final rest in _combinations(items, k - 1, i + 1)) {
      yield [items[i], ...rest];
    }
  }
}
