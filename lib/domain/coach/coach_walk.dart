import 'package:sudoku/domain/coach/coach.dart';
import 'package:sudoku/domain/coach/coach_technique.dart';
import 'package:sudoku/domain/models/puzzle.dart';

/// What happened when the coach walked a puzzle on its own.
class CoachWalk {
  const new({required this.finished, required this.techniques});

  /// True when the coach got from the givens to the solved grid.
  final bool finished;

  /// The technique of every step the coach took, in order.
  final List<CoachTechnique> techniques;

  /// The work in the walk: the scores of all its steps added up.
  int get score {
    var total = 0;
    for (final technique in techniques) {
      total += technique.score;
    }
    return total;
  }
}

/// Walks the puzzle the way a player would who applies every coach step: a
/// placement fills the cell, an elimination goes into the ledger. The notes
/// stay empty, because the coach never reasons from them.
CoachWalk walkWithCoach(Puzzle puzzle) {
  final values = puzzle.given.values;
  final givens = puzzle.given.values;
  final solution = puzzle.solution.values;
  final notes = List<Set<int>>.generate(81, (_) => <int>{});
  final eliminations = List<Set<int>>.generate(81, (_) => <int>{});
  final techniques = <CoachTechnique>[];

  CoachWalk result({required bool finished}) =>
      CoachWalk(finished: finished, techniques: techniques);

  // Every step fills a cell or removes a candidate, so 81 * 9 bounds the walk.
  for (var i = 0; i < 81 * 9; i++) {
    if (!values.contains(0)) return result(finished: true);

    final step = findCoachStep(
      values: values,
      notes: notes,
      eliminations: eliminations,
      solution: solution,
      givens: givens,
    );
    if (step == null) return result(finished: false);

    // A step without a technique is a mistake step. The coach only gives one
    // after a wrong digit, so the walk has gone wrong.
    final kind = step.kind;
    if (kind == null) return result(finished: false);

    final placement = step.placement;
    if (placement != null) {
      if (values[placement.cell] != 0) return result(finished: false);
      values[placement.cell] = placement.digit;
      techniques.add(kind);
      continue;
    }

    // A step that removes nothing new would repeat forever.
    var removed = false;
    for (final entry in step.eliminations.entries) {
      if (values[entry.key] != 0) continue;
      final ledger = eliminations[entry.key];
      final before = ledger.length;
      ledger.addAll(entry.value);
      if (ledger.length > before) removed = true;
    }
    if (!removed) return result(finished: false);
    techniques.add(kind);
  }

  return result(finished: !values.contains(0));
}
