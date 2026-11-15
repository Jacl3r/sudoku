import 'package:sudoku/domain/coach/coach.dart';
import 'package:sudoku/domain/models/puzzle.dart';

/// Whether the coach alone gets from the givens to the solved grid.
///
/// Walks the puzzle the way a player would who applies every coach step: a
/// placement fills the cell, an elimination goes into the ledger. The notes
/// stay empty, because the coach never reasons from them.
bool coachCanFinish(Puzzle puzzle) {
  final values = puzzle.given.values;
  final givens = puzzle.given.values;
  final solution = puzzle.solution.values;
  final notes = List<Set<int>>.generate(81, (_) => <int>{});
  final eliminations = List<Set<int>>.generate(81, (_) => <int>{});

  // Every step fills a cell or removes a candidate, so 81 * 9 bounds the walk.
  for (var i = 0; i < 81 * 9; i++) {
    if (!values.contains(0)) return true;

    final step = findCoachStep(
      values: values,
      notes: notes,
      eliminations: eliminations,
      solution: solution,
      givens: givens,
    );
    if (step == null) return false;

    final placement = step.placement;
    if (placement != null) {
      if (values[placement.cell] != 0) return false;
      values[placement.cell] = placement.digit;
      continue;
    }

    // A step that removes nothing new would repeat forever. That also covers a
    // mistake step, which the coach only gives after a wrong digit.
    var removed = false;
    for (final entry in step.eliminations.entries) {
      if (values[entry.key] != 0) continue;
      final ledger = eliminations[entry.key];
      final before = ledger.length;
      ledger.addAll(entry.value);
      if (ledger.length > before) removed = true;
    }
    if (!removed) return false;
  }

  return !values.contains(0);
}
