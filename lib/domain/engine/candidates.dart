import 'package:sudoku/domain/engine/grid_utils.dart';

/// Everything a cell can still hold, given only the digits already placed.
///
/// The player's notes play no part: notes are partial, so a deduction built on
/// them would be unsound.
Set<int> possibleCandidates(List<int> values, int index) {
  if (values[index] != 0) return {};
  final used = <int>{};
  for (final peer in kGridPeers[index]) {
    if (values[peer] != 0) used.add(values[peer]);
  }
  return {1, 2, 3, 4, 5, 6, 7, 8, 9}..removeAll(used);
}

/// [possibleCandidates] for all 81 cells, computed once.
List<Set<int>> candidatesFor(List<int> values) => [
  for (var i = 0; i < 81; i++) possibleCandidates(values, i),
];
