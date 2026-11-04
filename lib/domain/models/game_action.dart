/// One undo step. Actions are persisted with [GameState.toJson] so that undo
/// survives closing the app; [GameAction.fromJson] rebuilds them.
sealed class GameAction {
  const GameAction();

  Map<String, dynamic> toJson();

  factory GameAction.fromJson(Map<String, dynamic> json) =>
      switch (json['type']) {
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
  const DigitAction({
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
      other is DigitAction &&
          cellIndex == other.cellIndex &&
          previousValue == other.previousValue &&
          newValue == other.newValue &&
          _notesEqual(previousNotes, other.previousNotes) &&
          _ledgerEqual(
            previousCoachEliminations,
            other.previousCoachEliminations,
          );

  @override
  int get hashCode => Object.hash(
    cellIndex,
    previousValue,
    newValue,
    _notesHash(previousNotes),
    _ledgerHash(previousCoachEliminations),
  );
}

class PencilAction extends GameAction {
  const PencilAction({
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
          cellIndex == other.cellIndex &&
          previousValue == other.previousValue &&
          _setEqual(previousNotes, other.previousNotes) &&
          _setEqual(newNotes, other.newNotes) &&
          _ledgerEqual(
            previousCoachEliminations,
            other.previousCoachEliminations,
          );

  @override
  int get hashCode => Object.hash(
    cellIndex,
    previousValue,
    _setHash(previousNotes),
    _setHash(newNotes),
    _ledgerHash(previousCoachEliminations),
  );
}

class EraseAction extends GameAction {
  const EraseAction({
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
  Map<String, dynamic> toJson() => {
    'type': 'erase',
    'cellIndex': cellIndex,
    'previousValue': previousValue,
    'previousNotes': _sorted(previousNotes),
    'eliminations': ?_ledgerToJson(previousCoachEliminations),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EraseAction &&
          cellIndex == other.cellIndex &&
          previousValue == other.previousValue &&
          _setEqual(previousNotes, other.previousNotes) &&
          _ledgerEqual(
            previousCoachEliminations,
            other.previousCoachEliminations,
          );

  @override
  int get hashCode => Object.hash(
    cellIndex,
    previousValue,
    _setHash(previousNotes),
    _ledgerHash(previousCoachEliminations),
  );
}

class AutoNotesAction extends GameAction {
  const AutoNotesAction({required this.previousNotes});

  final List<Set<int>> previousNotes;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'autoNotes',
    'previousNotes': _noteListToJson(previousNotes),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AutoNotesAction &&
          _ledgerEqual(previousNotes, other.previousNotes);

  @override
  int get hashCode => _ledgerHash(previousNotes);
}

/// One undo step for a coach move that changes candidates in several cells.
class CoachNotesAction extends GameAction {
  const CoachNotesAction({
    required this.previousNotes,
    required this.previousCoachEliminations,
  });

  final List<Set<int>> previousNotes;

  final List<Set<int>> previousCoachEliminations;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'coachNotes',
    'previousNotes': _noteListToJson(previousNotes),
    'eliminations': ?_ledgerToJson(previousCoachEliminations),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoachNotesAction &&
          _ledgerEqual(previousNotes, other.previousNotes) &&
          _ledgerEqual(
            previousCoachEliminations,
            other.previousCoachEliminations,
          );

  @override
  int get hashCode => Object.hash(
    _ledgerHash(previousNotes),
    _ledgerHash(previousCoachEliminations),
  );
}

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

bool _notesEqual(Map<int, Set<int>> a, Map<int, Set<int>> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    final other = b[entry.key];
    if (other == null || !_setEqual(entry.value, other)) return false;
  }
  return true;
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

int _ledgerHash(List<Set<int>> ledger) =>
    Object.hashAll(ledger.map(_setHash));
