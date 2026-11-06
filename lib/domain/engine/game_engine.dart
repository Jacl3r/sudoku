import 'package:sudoku/domain/coach/coach_step.dart';
import 'package:sudoku/domain/engine/candidates.dart';
import 'package:sudoku/domain/engine/game_utils.dart';
import 'package:sudoku/domain/engine/grid_utils.dart';
import 'package:sudoku/domain/models/game_action.dart';
import 'package:sudoku/domain/models/game_state.dart';

class GameEngine {
  new(this._initialState) {
    _state = _initialState;
  }

  final GameState _initialState;
  late GameState _state;

  GameState get currentState => _state;

  bool get canUndo => _state.history.isNotEmpty;

  void tick(Duration duration) {
    _state = _state.copyWith(elapsed: _state.elapsed + duration);
  }

  void inputDigit(int cellIndex, int digit, {bool autoRemoveNotes = false}) {
    if (isGiven(_state, cellIndex)) return;

    final currentValue = getValue(_state, cellIndex);
    if (currentValue == digit) {
      erase(cellIndex);
      return;
    }

    if (digit == 0) {
      erase(cellIndex);
      return;
    }

    final previousNotes = <int, Set<int>>{};
    previousNotes[cellIndex] = Set<int>.from(_state.notes[cellIndex]);

    final newNotes = List<Set<int>>.from(_state.notes.map(Set<int>.from));

    for (final peerIndex in peersOf(cellIndex)) {
      previousNotes[peerIndex] = Set<int>.from(_state.notes[peerIndex]);
      if (autoRemoveNotes) {
        newNotes[peerIndex].remove(digit);
      }
    }

    newNotes[cellIndex].clear();

    final action = DigitAction(
      cellIndex: cellIndex,
      previousValue: currentValue,
      newValue: digit,
      previousNotes: previousNotes,
      previousCoachEliminations: _eliminations(),
    );

    final grid = _state.grid.clone()..setValue(cellIndex, digit);
    _state = _state.copyWith(
      grid: grid,
      notes: newNotes,
      // Replacing a digit widens the candidate set of its peers, so recorded
      // deductions may no longer hold.
      coachEliminations: currentValue == 0
          ? null
          : List<Set<int>>.generate(81, (_) => {}),
      history: [..._state.history, action],
    );

    if (isSolved(_state)) {
      _state = _state.copyWith(puzzleComplete: true);
    }
  }

  void toggleNote(int cellIndex, int digit) {
    if (isGiven(_state, cellIndex)) return;

    final previousValue = getValue(_state, cellIndex);
    final grid = _state.grid.clone()..clearValue(cellIndex);

    final current = Set<int>.from(_state.notes[cellIndex]);
    final updated = current.contains(digit)
        ? (current..remove(digit))
        : (current..add(digit));

    final action = PencilAction(
      cellIndex: cellIndex,
      previousNotes: Set<int>.from(_state.notes[cellIndex]),
      newNotes: Set<int>.from(updated),
      previousValue: previousValue,
      previousCoachEliminations: _eliminations(),
    );

    final newNotes = List<Set<int>>.from(_state.notes.map(Set<int>.from));
    newNotes[cellIndex] = updated;

    _state = _state.copyWith(
      grid: grid,
      notes: newNotes,
      // Turning a digit into a note removes it from the grid.
      coachEliminations: previousValue == 0
          ? null
          : List<Set<int>>.generate(81, (_) => {}),
      history: [..._state.history, action],
    );
  }

  void erase(int cellIndex) {
    if (isGiven(_state, cellIndex)) return;

    final previousValue = getValue(_state, cellIndex);
    final previousNotes = Set<int>.from(_state.notes[cellIndex]);
    if (previousValue == 0 && previousNotes.isEmpty) return;

    final action = EraseAction(
      cellIndex: cellIndex,
      previousValue: previousValue,
      previousNotes: previousNotes,
      previousCoachEliminations: _eliminations(),
    );

    final grid = _state.grid.clone()..clearValue(cellIndex);
    final newNotes = List<Set<int>>.from(_state.notes.map(Set<int>.from));
    newNotes[cellIndex] = {};

    _state = _state.copyWith(
      grid: grid,
      notes: newNotes,
      // Removing a digit widens the candidate set, so deductions recorded against
      // the old one can no longer be trusted.
      coachEliminations: previousValue == 0
          ? null
          : List<Set<int>>.generate(81, (_) => {}),
      history: [..._state.history, action],
    );
  }

  void undo() {
    if (!canUndo) return;
    _state = _state.history.last.undo(_state);
  }

  void revealHint({bool autoRemoveNotes = false}) {
    final result = firstEmptyOrWrong(
      _state.grid.values,
      _state.puzzle.solution.values,
    );
    if (result == null) return;

    _state = _state.copyWith(assists: _state.assists.copyWith(hints: true));
    inputDigit(result.index, result.correct, autoRemoveNotes: autoRemoveNotes);
  }

  void markHintUsed() {
    _state = _state.copyWith(assists: _state.assists.copyWith(hints: true));
  }

  /// Applies a coach step. Note changes are undone in one go.
  void applyCoachStep(CoachStep step, {bool autoRemoveNotes = false}) {
    markHintUsed();
    final eraseCell = step.erase;
    if (eraseCell != null) {
      erase(eraseCell);
      return;
    }
    final placement = step.placement;
    if (placement != null) {
      if (getValue(_state, placement.cell) != placement.digit) {
        inputDigit(
          placement.cell,
          placement.digit,
          autoRemoveNotes: autoRemoveNotes,
        );
      }
      return;
    }

    final values = _state.grid.values;
    final prevNotes = List<Set<int>>.from(_state.notes.map(Set<int>.from));
    final prevEliminations = _eliminations();
    final newNotes = List<Set<int>>.from(_state.notes.map(Set<int>.from));
    final newEliminations = _eliminations();

    for (final i in step.restoreNotes) {
      newNotes[i] = possibleCandidates(values, i);
      newEliminations[i] = {};
    }

    step.eliminations.forEach((i, digits) {
      if (values[i] != 0) return;
      newEliminations[i].addAll(digits);
      // Never invent notes: only cells the player already wrote in change.
      if (newNotes[i].isNotEmpty) newNotes[i].removeAll(digits);
    });

    if (_sameNotes(newNotes, _state.notes) &&
        _sameNotes(newEliminations, prevEliminations)) {
      return;
    }

    _state = _state.copyWith(
      notes: newNotes,
      coachEliminations: newEliminations,
      history: [
        ..._state.history,
        CoachNotesAction(
          previousNotes: prevNotes,
          previousCoachEliminations: prevEliminations,
        ),
      ],
    );
  }

  List<Set<int>> _eliminations() => List<Set<int>>.generate(
    81,
    (i) => Set<int>.from(_state.coachEliminationsAt(i)),
  );

  static bool _sameNotes(List<Set<int>> a, List<Set<int>> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].length != b[i].length) return false;
      if (!a[i].containsAll(b[i])) return false;
    }
    return true;
  }

  Set<int> findErrors() {
    _state = _state.copyWith(
      assists: _state.assists.copyWith(validation: true),
    );
    final errors = <int>{};
    for (var i = 0; i < 81; i++) {
      if (_state.grid.valueAt(i) != 0 &&
          _state.grid.valueAt(i) != _state.puzzle.solution.valueAt(i)) {
        errors.add(i);
      }
    }
    return errors;
  }

  void autoFillNotes() {
    final prevNotes = List<Set<int>>.from(_state.notes.map(Set<int>.from));

    final newNotes = List<Set<int>>.generate(81, (i) {
      if (_state.grid.valueAt(i) != 0 || _state.puzzle.isGivenAt(i)) {
        return <int>{};
      }

      final used = <int>{};
      for (final peer in peersOf(i)) {
        final v = _state.grid.valueAt(peer);
        if (v != 0) used.add(v);
      }

      return {1, 2, 3, 4, 5, 6, 7, 8, 9}..removeAll(used);
    });
    _state = _state.copyWith(assists: _state.assists.copyWith(autoNotes: true));
    final action = AutoNotesAction(previousNotes: prevNotes);
    _state = _state.copyWith(
      notes: newNotes,
      history: [..._state.history, action],
    );
  }

  void restart() {
    _state = _initialState.copyWith(elapsed: _state.elapsed);
  }
}
