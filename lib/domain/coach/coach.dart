import 'package:flutter/foundation.dart';
import 'package:sudoku/domain/coach/coach_step.dart';
import 'package:sudoku/domain/engine/grid_utils.dart';
import 'package:sudoku/domain/engine/techniques/techniques.dart';
import 'package:sudoku/domain/models/game_state.dart';
import 'package:sudoku/domain/models/hint.dart';
import 'package:sudoku/domain/models/sudoku_grid.dart';

/// Finds the next step for the current game, based on what the player
/// actually has on the board (digits and their own notes).
CoachStep? nextCoachStep(GameState state) => findCoachStep(
  values: state.grid.values,
  notes: state.notes,
  solution: state.puzzle.solution.values,
  givens: state.puzzle.given.values,
);

CoachStep? findCoachStep({
  required List<int> values,
  required List<Set<int>> notes,
  required List<int> solution,
  required List<int> givens,
}) {
  final mistake = _findMistake(values, notes, solution, givens);
  if (mistake != null) return mistake;

  final board = CoachBoard.fromPlayer(values, notes);
  for (final detector in _detectors) {
    final step = detector(board);
    if (step != null) return step;
  }
  return _fallback(board);
}

/// All candidates a cell could still hold, given only the placed digits.
Set<int> possibleCandidates(List<int> values, int index) {
  if (values[index] != 0) return {};
  final used = <int>{};
  for (final p in kGridPeers[index]) {
    if (values[p] != 0) used.add(values[p]);
  }
  return {1, 2, 3, 4, 5, 6, 7, 8, 9}..removeAll(used);
}

/// Candidates the coach reasons with: the player's notes where they have
/// some, otherwise everything that is still possible.
class CoachBoard {
  CoachBoard(this.values, this.masks);

  factory CoachBoard.fromPlayer(List<int> values, List<Set<int>> notes) {
    final masks = List<int>.filled(81, 0);
    for (var i = 0; i < 81; i++) {
      if (values[i] != 0) continue;
      var cands = possibleCandidates(values, i);
      if (notes[i].isNotEmpty) {
        final narrowed = cands.intersection(notes[i]);
        if (narrowed.isNotEmpty) cands = narrowed;
      }
      for (final d in cands) {
        masks[i] |= 1 << (d - 1);
      }
    }
    return CoachBoard(List<int>.from(values), masks);
  }

  final List<int> values;
  final List<int> masks;

  bool has(int i, int d) => values[i] == 0 && (masks[i] & (1 << (d - 1))) != 0;

  List<int> digitsAt(int i) => [
    for (var d = 1; d <= 9; d++)
      if (has(i, d)) d,
  ];

  int countAt(int i) => digitsAt(i).length;

  List<int> cellsFor(List<int> unit, int d) => [
    for (final i in unit)
      if (has(i, d)) i,
  ];

  SudokuGrid toGrid() =>
      SudokuGrid(
    values: List<int>.from(values),
    candidates: List<int>.from(masks),
  );
}

@visibleForTesting
CoachStep? detectSkyscraper(CoachBoard b) => _skyscraper(b);

@visibleForTesting
CoachStep? detectTwoStringKite(CoachBoard b) => _twoStringKite(b);

typedef _Detector = CoachStep? Function(CoachBoard b);

final List<_Detector> _detectors = [
  _hiddenSingle,
  _nakedSingle,
  _pointing,
  _boxLineReduction,
  (b) => _nakedSubset(b, 2),
  (b) => _hiddenSubset(b, 2),
  (b) => _nakedSubset(b, 3),
  (b) => _hiddenSubset(b, 3),
  (b) => _fish(b, 2),
  _skyscraper,
  _twoStringKite,
  _xyWing,
  (b) => _fish(b, 3),
  _xyzWing,
];

// ---------------------------------------------------------------------------
// Helpers

String unitName(int u) {
  if (u < 9) return 'row ${u + 1}';
  if (u < 18) return 'column ${u - 8}';
  return 'box ${u - 17}';
}

List<int> _rowCells(int r) => kGridUnits[r];
List<int> _colCells(int c) => kGridUnits[9 + c];
List<int> _boxCells(int b) => kGridUnits[18 + b];

bool _sees(int a, int b) => kGridPeerSets[a].contains(b);

Iterable<List<T>> _combinations<T>(List<T> items, int k, [int start = 0]) sync* {
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

/// Cells (outside [exclude]) that see every cell in [anchors] and still
/// hold [digit].
Set<int> _seeingAll(
  CoachBoard b,
  Iterable<int> anchors,
  int digit,
  Set<int> exclude,
) {
  final result = <int>{};
  for (var i = 0; i < 81; i++) {
    if (exclude.contains(i) || !b.has(i, digit)) continue;
    if (anchors.every((a) => _sees(i, a))) result.add(i);
  }
  return result;
}

Map<int, Set<int>> _elim(Iterable<int> cells, int digit) => {
  for (final c in cells) c: {digit},
};

// ---------------------------------------------------------------------------
// Mistakes

CoachStep? _findMistake(
  List<int> values,
  List<Set<int>> notes,
  List<int> solution,
  List<int> givens,
) {
  for (var i = 0; i < 81; i++) {
    if (givens[i] != 0 || values[i] == 0) continue;
    if (values[i] != solution[i]) {
      final box = getBox(i);
      return CoachStep(
        headline: 'Something on the board is off.',
        technique: 'Mistake',
        about: 'One of your digits does not fit the solution. '
            'Everything built on it will lead nowhere.',
        nudge: 'Check your digits in box ${box + 1}.',
        explanation: 'The ${values[i]} in ${cellName(i)} is wrong. '
            'Erase it and look at that area again.',
        focusCells: _boxCells(box).toSet(),
        patternCells: {i},
        erase: i,
      );
    }
  }
  for (var i = 0; i < 81; i++) {
    if (values[i] != 0 || notes[i].isEmpty) continue;
    if (!notes[i].contains(solution[i])) {
      final box = getBox(i);
      return CoachStep(
        headline: 'One of your notes went too far.',
        technique: 'Note removed too early',
        about: 'A candidate was removed that is still possible. '
            'Steps based on it can be wrong.',
        nudge: 'Check your notes in box ${box + 1}.',
        explanation: 'The notes in ${cellName(i)} are missing a digit that '
            'can still go there. Reset them to every possible candidate.',
        focusCells: _boxCells(box).toSet(),
        patternCells: {i},
        restoreNotes: {i},
      );
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// Singles

const _hiddenSingleAbout =
    'A digit that has only one possible cell left in a row, column or box.';

CoachStep? _hiddenSingle(CoachBoard b) {
  // Boxes first: that is where people usually spot them.
  const order = [
    18, 19, 20, 21, 22, 23, 24, 25, 26, //
    0, 1, 2, 3, 4, 5, 6, 7, 8,
    9, 10, 11, 12, 13, 14, 15, 16, 17,
  ];
  for (final u in order) {
    final unit = kGridUnits[u];
    for (var d = 1; d <= 9; d++) {
      final cells = b.cellsFor(unit, d);
      if (cells.length != 1) continue;
      final cell = cells.first;
      return CoachStep(
        headline: 'There is a Hidden Single.',
        technique: 'Hidden Single',
        about: _hiddenSingleAbout,
        nudge: 'Look at where $d can go in ${unitName(u)}.',
        explanation: 'In ${unitName(u)}, $d only fits in ${cellName(cell)}. '
            'Every other cell there is blocked.',
        focusCells: unit.toSet(),
        patternCells: {cell},
        patternDigits: {d},
        placement: (cell: cell, digit: d),
      );
    }
  }
  return null;
}

CoachStep? _nakedSingle(CoachBoard b) {
  for (var i = 0; i < 81; i++) {
    if (b.values[i] != 0) continue;
    final digits = b.digitsAt(i);
    if (digits.length != 1) continue;
    final d = digits.first;
    final box = getBox(i);
    return CoachStep(
      headline: 'There is a Naked Single.',
      technique: 'Naked Single',
      about: 'A cell with only one candidate left.',
      nudge: 'One cell in box ${box + 1} has only one option left.',
      explanation: '${cellName(i)} can only be $d. '
          'Every other digit already appears in its row, column or box.',
      focusCells: _boxCells(box).toSet(),
      patternCells: {i},
      patternDigits: {d},
      placement: (cell: i, digit: d),
    );
  }
  return null;
}

// ---------------------------------------------------------------------------
// Intersections

CoachStep? _pointing(CoachBoard b) {
  for (var box = 0; box < 9; box++) {
    final boxCells = _boxCells(box);
    for (var d = 1; d <= 9; d++) {
      final cells = b.cellsFor(boxCells, d);
      if (cells.length < 2) continue;
      final rows = cells.map(getRow).toSet();
      final cols = cells.map(getCol).toSet();
      for (final (lineIndex, line) in [
        if (rows.length == 1) (rows.first, _rowCells(rows.first)),
        if (cols.length == 1) (9 + cols.first, _colCells(cols.first)),
      ]) {
        final targets = line
            .where((i) => getBox(i) != box && b.has(i, d))
            .toList();
        if (targets.isEmpty) continue;
        final lineName = unitName(lineIndex);
        return CoachStep(
          headline: 'Look for a Pointing Pair.',
          technique: cells.length == 2 ? 'Pointing Pair' : 'Pointing Triple',
          about: 'When a digit inside a box is limited to one row or column, '
              'it cannot appear anywhere else on that line.',
          nudge: 'Look at where $d can go in box ${box + 1}.',
          explanation: 'In box ${box + 1}, every $d sits in $lineName '
              '(${cellList(cells)}). So the $d of $lineName must be inside '
              'box ${box + 1}. Remove $d from ${cellList(targets)}.',
          focusCells: boxCells.toSet(),
          patternCells: cells.toSet(),
          patternDigits: {d},
          eliminations: _elim(targets, d),
        );
      }
    }
  }
  return null;
}

CoachStep? _boxLineReduction(CoachBoard b) {
  for (var u = 0; u < 18; u++) {
    final line = kGridUnits[u];
    for (var d = 1; d <= 9; d++) {
      final cells = b.cellsFor(line, d);
      if (cells.length < 2) continue;
      final boxes = cells.map(getBox).toSet();
      if (boxes.length != 1) continue;
      final box = boxes.first;
      final targets = _boxCells(box)
          .where((i) => !line.contains(i) && b.has(i, d))
          .toList();
      if (targets.isEmpty) continue;
      return CoachStep(
        headline: 'Look for a Box/Line Reduction.',
        technique: 'Box/Line Reduction',
        about: 'When a digit in a row or column is limited to one box, '
            'it cannot appear anywhere else in that box.',
        nudge: 'Look at where $d can go in ${unitName(u)}.',
        explanation: 'In ${unitName(u)}, every $d sits inside box ${box + 1} '
            '(${cellList(cells)}). So box ${box + 1} gets its $d from that '
            'line. Remove $d from ${cellList(targets)}.',
        focusCells: line.toSet(),
        patternCells: cells.toSet(),
        patternDigits: {d},
        eliminations: _elim(targets, d),
      );
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// Subsets

String _subsetWord(int n) => n == 2 ? 'Pair' : 'Triple';

CoachStep? _nakedSubset(CoachBoard b, int n) {
  for (var u = 0; u < 27; u++) {
    final unit = kGridUnits[u];
    final open = unit.where((i) {
      final c = b.countAt(i);
      return c >= 2 && c <= n;
    }).toList();
    if (open.length < n) continue;
    for (final combo in _combinations(open, n)) {
      final union = <int>{for (final i in combo) ...b.digitsAt(i)};
      if (union.length != n) continue;
      final elim = <int, Set<int>>{};
      for (final i in unit) {
        if (combo.contains(i)) continue;
        final hit = b.digitsAt(i).where(union.contains).toSet();
        if (hit.isNotEmpty) elim[i] = hit;
      }
      if (elim.isEmpty) continue;
      final word = _subsetWord(n);
      final count = n == 2 ? 'two' : 'three';
      return CoachStep(
        headline: 'Look for a Naked $word.',
        technique: 'Naked $word',
        about: 'When $count cells in a house only hold the same $count '
            'digits, those digits are locked into them.',
        nudge: 'Look at the cells with few candidates in ${unitName(u)}.',
        explanation: '${cellList(combo)} only contain ${digitList(union)}. '
            'Those digits must go into these cells, so remove them from '
            'the rest of ${unitName(u)}: ${cellList(elim.keys)}.',
        focusCells: unit.toSet(),
        patternCells: combo.toSet(),
        patternDigits: union,
        eliminations: elim,
      );
    }
  }
  return null;
}

CoachStep? _hiddenSubset(CoachBoard b, int n) {
  for (var u = 0; u < 27; u++) {
    final unit = kGridUnits[u];
    final positions = <int, List<int>>{};
    for (var d = 1; d <= 9; d++) {
      final cells = b.cellsFor(unit, d);
      if (cells.length >= 2 && cells.length <= n) positions[d] = cells;
    }
    if (positions.length < n) continue;
    for (final combo in _combinations(positions.keys.toList(), n)) {
      final cells = <int>{for (final d in combo) ...positions[d]!};
      if (cells.length != n) continue;
      final elim = <int, Set<int>>{};
      for (final i in cells) {
        final extra = b.digitsAt(i).where((d) => !combo.contains(d)).toSet();
        if (extra.isNotEmpty) elim[i] = extra;
      }
      if (elim.isEmpty) continue;
      final word = _subsetWord(n);
      final count = n == 2 ? 'two' : 'three';
      return CoachStep(
        headline: 'Look for a Hidden $word.',
        technique: 'Hidden $word',
        about: 'When $count digits only fit in the same $count cells of a '
            'house, those cells cannot hold anything else.',
        nudge: 'Look at where each digit can go in ${unitName(u)}.',
        explanation: 'In ${unitName(u)}, ${digitList(combo)} only fit in '
            '${cellList(cells)}. So those cells are reserved for them. '
            'Remove the other candidates from them.',
        focusCells: unit.toSet(),
        patternCells: cells,
        patternDigits: combo.toSet(),
        eliminations: elim,
      );
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// Fish (X-Wing, Swordfish)

CoachStep? _fish(CoachBoard b, int n) {
  for (var d = 1; d <= 9; d++) {
    for (final byRow in [true, false]) {
      final lines = <int, List<int>>{}; // line index -> cross positions
      for (var l = 0; l < 9; l++) {
        final cells = b.cellsFor(byRow ? _rowCells(l) : _colCells(l), d);
        if (cells.length >= 2 && cells.length <= n) {
          lines[l] = cells.map(byRow ? getCol : getRow).toList();
        }
      }
      if (lines.length < n) continue;
      for (final combo in _combinations(lines.keys.toList(), n)) {
        final cover = <int>{for (final l in combo) ...lines[l]!};
        if (cover.length != n) continue;
        final pattern = <int>{
          for (final l in combo)
            for (final x in lines[l]!) byRow ? l * 9 + x : x * 9 + l,
        };
        final targets = <int>[
          for (final x in cover)
            for (final i in byRow ? _colCells(x) : _rowCells(x))
              if (!pattern.contains(i) && b.has(i, d)) i,
        ];
        if (targets.isEmpty) continue;

        final name = n == 2 ? 'X-Wing' : 'Swordfish';
        final baseWord = byRow ? 'rows' : 'columns';
        final coverWord = byRow ? 'columns' : 'rows';
        final bases = (combo.toList()..sort()).map((l) => '${l + 1}');
        final covers = (cover.toList()..sort()).map((x) => '${x + 1}');
        final focus = <int>{
          for (final l in combo) ...(byRow ? _rowCells(l) : _colCells(l)),
        };
        return CoachStep(
          headline: 'Look for an $name.',
          technique: name,
          about: n == 2
              ? 'A digit limited to the same two columns in two rows (or the '
                    'other way round) forms a rectangle. It has to take both '
                    'columns there, so it cannot appear elsewhere in them.'
              : 'Like an X-Wing, but with three rows and three columns.',
          nudge: 'Look at where $d can go in $baseWord ${bases.join(', ')}.',
          explanation: 'In $baseWord ${bases.join(', ')}, $d only fits in '
              '$coverWord ${covers.join(', ')}. Whichever way it resolves, '
              '$d takes each of those $coverWord inside the pattern. '
              'Remove $d from ${cellList(targets)}.',
          focusCells: focus,
          patternCells: pattern,
          patternDigits: {d},
          eliminations: _elim(targets, d),
        );
      }
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// Single-digit patterns

CoachStep? _skyscraper(CoachBoard b) {
  for (var d = 1; d <= 9; d++) {
    for (final byRow in [true, false]) {
      final pairs = <int, List<int>>{};
      for (var l = 0; l < 9; l++) {
        final cells = b.cellsFor(byRow ? _rowCells(l) : _colCells(l), d);
        if (cells.length == 2) pairs[l] = cells;
      }
      final lines = pairs.keys.toList();
      for (var i = 0; i < lines.length; i++) {
        for (var j = i + 1; j < lines.length; j++) {
          final a = pairs[lines[i]]!;
          final c = pairs[lines[j]]!;
          int cross(int cell) => byRow ? getCol(cell) : getRow(cell);
          for (final baseA in a) {
            for (final baseC in c) {
              if (cross(baseA) != cross(baseC)) continue;
              final tipA = a.firstWhere((x) => x != baseA);
              final tipC = c.firstWhere((x) => x != baseC);
              if (cross(tipA) == cross(tipC)) continue; // that's an X-Wing
              final pattern = {baseA, baseC, tipA, tipC};
              final targets = _seeingAll(b, [tipA, tipC], d, pattern);
              if (targets.isEmpty) continue;
              final word = byRow ? 'rows' : 'columns';
              final cw = byRow ? 'column' : 'row';
              return CoachStep(
                headline: 'Look for a Skyscraper.',
                technique: 'Skyscraper',
                about: 'Two rows (or columns) each have a digit in exactly '
                    'two cells, and one end of each lines up. One of the '
                    'two other ends must hold the digit.',
                nudge: 'Look at $d in $word ${lines[i] + 1} and '
                    '${lines[j] + 1}.',
                explanation: 'In $word ${lines[i] + 1} and ${lines[j] + 1}, '
                    '$d has exactly two spots each. ${cellName(baseA)} and '
                    '${cellName(baseC)} share a $cw, so at most one of them '
                    'is $d. That means ${cellName(tipA)} or ${cellName(tipC)} '
                    'is $d. Cells that see both cannot be $d: '
                    '${cellList(targets)}.',
                focusCells: {
                  ...(byRow ? _rowCells(lines[i]) : _colCells(lines[i])),
                  ...(byRow ? _rowCells(lines[j]) : _colCells(lines[j])),
                },
                patternCells: pattern,
                patternDigits: {d},
                eliminations: _elim(targets, d),
              );
            }
          }
        }
      }
    }
  }
  return null;
}

CoachStep? _twoStringKite(CoachBoard b) {
  for (var d = 1; d <= 9; d++) {
    final rowPairs = <int, List<int>>{};
    final colPairs = <int, List<int>>{};
    for (var l = 0; l < 9; l++) {
      final r = b.cellsFor(_rowCells(l), d);
      if (r.length == 2) rowPairs[l] = r;
      final c = b.cellsFor(_colCells(l), d);
      if (c.length == 2) colPairs[l] = c;
    }
    for (final row in rowPairs.entries) {
      for (final col in colPairs.entries) {
        final rc = row.value;
        final cc = col.value;
        if (rc.any(cc.contains)) continue;
        for (final rEnd in rc) {
          for (final cEnd in cc) {
            if (getBox(rEnd) != getBox(cEnd)) continue;
            final tipR = rc.firstWhere((x) => x != rEnd);
            final tipC = cc.firstWhere((x) => x != cEnd);
            if (getBox(tipR) == getBox(rEnd) || getBox(tipC) == getBox(cEnd)) {
              continue;
            }
            final pattern = {rEnd, cEnd, tipR, tipC};
            final targets = _seeingAll(b, [tipR, tipC], d, pattern);
            if (targets.isEmpty) continue;
            final box = getBox(rEnd) + 1;
            return CoachStep(
              headline: 'Look for a Two-String Kite.',
              technique: 'Two-String Kite',
              about: 'A row and a column each have a digit in exactly two '
                  'cells, and they meet in one box. One of the two free '
                  'ends must hold the digit.',
              nudge: 'Look at $d in row ${row.key + 1} and '
                  'column ${col.key + 1}.',
              explanation: 'In row ${row.key + 1}, $d is in ${cellName(rEnd)} '
                  'or ${cellName(tipR)}. In column ${col.key + 1}, $d is in '
                  '${cellName(cEnd)} or ${cellName(tipC)}. ${cellName(rEnd)} '
                  'and ${cellName(cEnd)} share box $box, so at most one of '
                  'them is $d. So ${cellName(tipR)} or ${cellName(tipC)} is '
                  '$d. Cells that see both cannot be $d: '
                  '${cellList(targets)}.',
              focusCells: {..._rowCells(row.key), ..._colCells(col.key)},
              patternCells: pattern,
              patternDigits: {d},
              eliminations: _elim(targets, d),
            );
          }
        }
      }
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// Wings

CoachStep? _xyWing(CoachBoard b) {
  final bivalue = [
    for (var i = 0; i < 81; i++)
      if (b.countAt(i) == 2) i,
  ];
  for (final pivot in bivalue) {
    final pd = b.digitsAt(pivot);
    final x = pd[0];
    final y = pd[1];
    final wings = bivalue.where((w) => w != pivot && _sees(pivot, w));
    for (final w1 in wings) {
      final d1 = b.digitsAt(w1);
      if (!d1.contains(x) || d1.contains(y)) continue;
      final z = d1.firstWhere((v) => v != x);
      for (final w2 in wings) {
        if (w2 == w1) continue;
        final d2 = b.digitsAt(w2);
        if (!(d2.contains(y) && d2.contains(z))) continue;
        final pattern = {pivot, w1, w2};
        final targets = _seeingAll(b, [w1, w2], z, pattern);
        if (targets.isEmpty) continue;
        return CoachStep(
          headline: 'Look for an XY-Wing.',
          technique: 'XY-Wing',
          about: 'A cell with two candidates (the pivot) sees two other '
              'two-candidate cells. Each wing shares one digit with the '
              'pivot and one digit with the other wing.',
          nudge: 'Look at the cells with two candidates around '
              '${cellName(pivot)}.',
          explanation: '${cellName(pivot)} is $x or $y. If it is $x, '
              '${cellName(w1)} becomes $z. If it is $y, ${cellName(w2)} '
              'becomes $z. Either way one wing is $z, so cells that see '
              'both wings cannot be $z: ${cellList(targets)}.',
          focusCells: {...kGridPeerSets[pivot], pivot},
          patternCells: pattern,
          patternDigits: {x, y, z},
          eliminations: _elim(targets, z),
        );
      }
    }
  }
  return null;
}

CoachStep? _xyzWing(CoachBoard b) {
  for (var pivot = 0; pivot < 81; pivot++) {
    if (b.countAt(pivot) != 3) continue;
    final pd = b.digitsAt(pivot).toSet();
    final wings = [
      for (final w in kGridPeers[pivot])
        if (b.countAt(w) == 2 && pd.containsAll(b.digitsAt(w))) w,
    ];
    for (final pair in _combinations(wings, 2)) {
      final w1 = pair[0];
      final w2 = pair[1];
      final a = b.digitsAt(w1).toSet();
      final c = b.digitsAt(w2).toSet();
      final shared = a.intersection(c);
      if (shared.length != 1 || a.union(c).length != 3) continue;
      final z = shared.first;
      final pattern = {pivot, w1, w2};
      final targets = _seeingAll(b, pattern, z, pattern);
      if (targets.isEmpty) continue;
      return CoachStep(
        headline: 'Look for an XYZ-Wing.',
        technique: 'XYZ-Wing',
        about: 'Like an XY-Wing, but the pivot holds all three digits. '
            'Only cells that see the pivot and both wings are affected.',
        nudge: 'Look at the three-candidate cell ${cellName(pivot)} and its '
            'neighbours.',
        explanation: '${cellName(pivot)} holds ${digitList(pd)}, '
            '${cellName(w1)} holds ${digitList(a)}, ${cellName(w2)} holds '
            '${digitList(c)}. One of these three cells must be $z. Cells '
            'that see all three cannot be $z: ${cellList(targets)}.',
        focusCells: {...kGridPeerSets[pivot], pivot},
        patternCells: pattern,
        patternDigits: {z},
        eliminations: _elim(targets, z),
      );
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// Fallback to the existing solver for techniques the coach can't draw yet.

CoachStep? _fallback(CoachBoard b) {
  final grid = b.toGrid();
  final extra = <String, SudokuTechnique>{
    'Simple Coloring': SimpleColoring(),
    'Naked Quad': NakedQuad(),
    'Hidden Quad': HiddenQuad(),
    'Jellyfish': Jellyfish(),
  };
  for (final entry in extra.entries) {
    final hints = entry.value.getHints(grid);
    if (hints.isEmpty) continue;
    final hint = hints.first;
    final name = entry.key;
    if (hint is DirectHint) {
      return CoachStep(
        headline: 'Look for $name.',
        technique: name,
        about: 'An advanced technique. The coach can name it but not '
            'draw it yet.',
        nudge: 'It leads to a digit in ${cellName(hint.cellIndex)}.',
        explanation: '$name places ${hint.value} in '
            '${cellName(hint.cellIndex)}.',
        patternCells: {hint.cellIndex},
        patternDigits: {hint.value},
        placement: (cell: hint.cellIndex, digit: hint.value),
      );
    }
    if (hint is IndirectHint) {
      final digits = hint.valuesToRemove.where((d) => b.has(hint.cellIndex, d));
      if (digits.isEmpty) continue;
      return CoachStep(
        headline: 'Look for $name.',
        technique: name,
        about: 'An advanced technique. The coach can name it but not '
            'draw it yet.',
        nudge: 'It affects ${cellName(hint.cellIndex)}.',
        explanation: '$name removes ${digitList(digits)} from '
            '${cellName(hint.cellIndex)}.',
        patternCells: {hint.cellIndex},
        eliminations: {hint.cellIndex: digits.toSet()},
      );
    }
  }
  return null;
}
