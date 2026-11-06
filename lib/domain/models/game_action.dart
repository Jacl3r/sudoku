import 'package:sudoku/domain/models/game_state.dart';

/// Everything a step changed, expressed the same way whatever the step was:
/// cells going back to a value, notes coming back (per cell, or the whole
/// board), and the elimination ledger as it was before.
///
/// One restore, so the five actions stop re-implementing clone-grid /
/// copy-notes / restore-ledger / trim-history, and one equality, so they stop
/// re-deriving set comparison four times.
final class UndoStep {
  const new({
    this.values = const {},
    this.notes = const {},
    this.allNotes,
    this.eliminations,
  });

  /// Cells to put back, by index. A value of 0 clears the cell.
  final Map<int, int> values;

  /// Per-cell notes to put back, for a step that touched a few cells.
  final Map<int, Set<int>> notes;

  /// The whole notes list, for a step that rewrote it (auto notes, coach move).
  final List<Set<int>>? allNotes;

  /// The ledger before the step. Null leaves the current ledger alone.
  final List<Set<int>>? eliminations;

  GameState restore(GameState state) {
    final grid = state.grid.clone();
    for (final entry in values.entries) {
      grid.setValue(entry.key, entry.value);
    }

    final restoredNotes = switch (allNotes) {
      final all? => [for (final cell in all) Set<int>.from(cell)],
      null => [
        for (var i = 0; i < state.notes.length; i++)
          Set<int>.from(notes[i] ?? state.notes[i]),
      ],
    };

    final ledger = eliminations;
    return state.copyWith(
      grid: grid,
      notes: restoredNotes,
      coachEliminations: ledger == null
          ? state.coachEliminations
          : _expandedLedger(ledger),
      history: state.history.isEmpty
          ? state.history
          : state.history.sublist(0, state.history.length - 1),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UndoStep &&
          _valuesEqual(values, other.values) &&
          _notesEqual(notes, other.notes) &&
          _optionalListEqual(allNotes, other.allNotes) &&
          _optionalListEqual(eliminations, other.eliminations);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(
      values.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    _notesHash(notes),
    allNotes == null ? null : _ledgerHash(allNotes!),
    eliminations == null ? null : _ledgerHash(eliminations!),
  );
}

/// One undo step. Actions are persisted with [GameState.toJson] so that undo
/// survives closing the app; [GameAction.fromJson] rebuilds them.
sealed class GameAction {
  const new();

  Map<String, dynamic> toJson();

  /// What this action changed. The one thing subclasses must say.
  UndoStep get step;

  GameState undo(GameState state) => step.restore(state);

  factory fromJson(Map<String, dynamic> json) => switch (json['type']) {
    'digit' => DigitAction(
      cellIndex: json['cellIndex'] as int,
      previousValue: json['previousValue'] as int,
      newValue: json['newValue'] as int,
      previousNotes: _notesFromJson(json['previousNotes']),
      previousCoachEliminations: _ledgerFromJson(json['eliminations']),
    ),
    'pencil' => PencilAction(
      cellIndex: json['cellIndex'] as int,
      previousNotes: Set<int>.from(json['previousNotes'] as List),
      newNotes: Set<int>.from(json['newNotes'] as List),
      previousValue: json['previousValue'] as int,
      previousCoachEliminations: _ledgerFromJson(json['eliminations']),
    ),
    'erase' => EraseAction(
      cellIndex: json['cellIndex'] as int,
      previousValue: json['previousValue'] as int,
      previousNotes: Set<int>.from(json['previousNotes'] as List),
      previousCoachEliminations: _ledgerFromJson(json['eliminations']),
    ),
    'autoNotes' => AutoNotesAction(
      previousNotes: _noteListFromJson(json['previousNotes']),
    ),
    'coachNotes' => CoachNotesAction(
      previousNotes: _noteListFromJson(json['previousNotes']),
      previousCoachEliminations: _ledgerFromJson(json['eliminations']),
    ),
    final type => throw FormatException('Unknown game action "$type"'),
  };
}

class DigitAction extends GameAction {
  const new({
    required this.cellIndex,
    required this.previousValue,
    required this.previousNotes,
    required this.newValue,
    this.previousCoachEliminations = const [],
  });

  final int cellIndex;

  final int previousValue;

  final Map<int, Set<int>> previousNotes;

  final int newValue;

  final List<Set<int>> previousCoachEliminations;

  @override
  UndoStep get step => UndoStep(
    values: {cellIndex: previousValue},
    notes: previousNotes,
    eliminations: previousCoachEliminations,
  );

  @override
  Map<String, dynamic> toJson() => {
    'type': 'digit',
    'cellIndex': cellIndex,
    'previousValue': previousValue,
    'newValue': newValue,
    'previousNotes': _notesToJson(previousNotes),
    'eliminations': ?_ledgerToJson(previousCoachEliminations),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DigitAction && newValue == other.newValue && step == other.step;

  @override
  int get hashCode => Object.hash(newValue, step);
}

class PencilAction extends GameAction {
  const new({
    required this.cellIndex,
    required this.previousNotes,
    required this.newNotes,
    required this.previousValue,
    this.previousCoachEliminations = const [],
  });

  final int cellIndex;

  final Set<int> previousNotes;

  final Set<int> newNotes;

  final int previousValue;

  final List<Set<int>> previousCoachEliminations;

  @override
  UndoStep get step => UndoStep(
    values: {cellIndex: previousValue},
    notes: {cellIndex: previousNotes},
    eliminations: previousCoachEliminations,
  );

  @override
  Map<String, dynamic> toJson() => {
    'type': 'pencil',
    'cellIndex': cellIndex,
    'previousValue': previousValue,
    'previousNotes': _sorted(previousNotes),
    'newNotes': _sorted(newNotes),
    'eliminations': ?_ledgerToJson(previousCoachEliminations),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PencilAction &&
          _setEqual(newNotes, other.newNotes) &&
          step == other.step;

  @override
  int get hashCode => Object.hash(_setHash(newNotes), step);
}

class EraseAction extends GameAction {
  const new({
    required this.cellIndex,
    required this.previousValue,
    required this.previousNotes,
    this.previousCoachEliminations = const [],
  });

  final int cellIndex;

  final int previousValue;

  final Set<int> previousNotes;

  final List<Set<int>> previousCoachEliminations;

  @override
  UndoStep get step => UndoStep(
    values: {cellIndex: previousValue},
    notes: {cellIndex: previousNotes},
    eliminations: previousCoachEliminations,
  );

  @override
  Map<String, dynamic> toJson() => {
    'type': 'erase',
    'cellIndex': cellIndex,
    'previousValue': previousValue,
    'previousNotes': _sorted(previousNotes),
    'eliminations': ?_ledgerToJson(previousCoachEliminations),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is EraseAction && step == other.step;

  @override
  int get hashCode => step.hashCode;
}

class AutoNotesAction extends GameAction {
  const new({required this.previousNotes});

  final List<Set<int>> previousNotes;

  @override
  UndoStep get step => UndoStep(allNotes: previousNotes);

  @override
  Map<String, dynamic> toJson() => {
    'type': 'autoNotes',
    'previousNotes': _noteListToJson(previousNotes),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AutoNotesAction && step == other.step;

  @override
  int get hashCode => step.hashCode;
}

/// One undo step for a coach move that changes candidates in several cells.
class CoachNotesAction extends GameAction {
  const new({
    required this.previousNotes,
    required this.previousCoachEliminations,
  });

  final List<Set<int>> previousNotes;

  final List<Set<int>> previousCoachEliminations;

  @override
  UndoStep get step => UndoStep(
    allNotes: previousNotes,
    eliminations: previousCoachEliminations,
  );

  @override
  Map<String, dynamic> toJson() => {
    'type': 'coachNotes',
    'previousNotes': _noteListToJson(previousNotes),
    'eliminations': ?_ledgerToJson(previousCoachEliminations),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is CoachNotesAction && step == other.step;

  @override
  int get hashCode => step.hashCode;
}

/// A saved ledger can be short or missing (an older save). Restoring fills the
/// rest with empty cells rather than crashing.
List<Set<int>> _expandedLedger(List<Set<int>> source) =>
    List<Set<int>>.generate(
      81,
      (i) => i < source.length ? Set<int>.from(source[i]) : <int>{},
    );

List<int> _sorted(Set<int> digits) => digits.toList()..sort();

Map<String, dynamic> _notesToJson(Map<int, Set<int>> notes) => {
  for (final entry in notes.entries) '${entry.key}': _sorted(entry.value),
};

Map<int, Set<int>> _notesFromJson(Object? raw) => {
  for (final entry in (raw as Map).entries)
    int.parse(entry.key as String): Set<int>.from(entry.value as List),
};

List<List<int>> _noteListToJson(List<Set<int>> notes) => [
  for (final cell in notes) _sorted(cell),
];

List<Set<int>> _noteListFromJson(Object? raw) => [
  for (final cell in raw as List) Set<int>.from(cell as List),
];

/// Empty snapshots are the common case. Leaving them out keeps the save small,
/// and the engine already reads a short ledger as all-empty.
List<List<int>>? _ledgerToJson(List<Set<int>> ledger) {
  if (ledger.every((cell) => cell.isEmpty)) return null;
  return _noteListToJson(ledger);
}

List<Set<int>> _ledgerFromJson(Object? raw) =>
    raw == null ? const [] : _noteListFromJson(raw);

bool _setEqual(Set<int> a, Set<int> b) =>
    a.length == b.length && a.containsAll(b);

bool _valuesEqual(Map<int, int> a, Map<int, int> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}

bool _notesEqual(Map<int, Set<int>> a, Map<int, Set<int>> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    final other = b[entry.key];
    if (other == null || !_setEqual(entry.value, other)) return false;
  }
  return true;
}

bool _optionalListEqual(List<Set<int>>? a, List<Set<int>>? b) {
  if (a == null || b == null) return a == b;
  return _ledgerEqual(a, b);
}

bool _ledgerEqual(List<Set<int>> a, List<Set<int>> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!_setEqual(a[i], b[i])) return false;
  }
  return true;
}

int _setHash(Set<int> digits) => Object.hashAllUnordered(digits);

int _notesHash(Map<int, Set<int>> notes) => Object.hashAllUnordered(
  notes.entries.map((entry) => Object.hash(entry.key, _setHash(entry.value))),
);

int _ledgerHash(List<Set<int>> ledger) => Object.hashAll(ledger.map(_setHash));
