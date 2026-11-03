sealed class GameAction {
  const GameAction();
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
}

class AutoNotesAction extends GameAction {
  const AutoNotesAction({required this.previousNotes});

  final List<Set<int>> previousNotes;
}

/// One undo step for a coach move that changes candidates in several cells.
class CoachNotesAction extends GameAction {
  const CoachNotesAction({
    required this.previousNotes,
    required this.previousCoachEliminations,
  });

  final List<Set<int>> previousNotes;

  final List<Set<int>> previousCoachEliminations;
}
