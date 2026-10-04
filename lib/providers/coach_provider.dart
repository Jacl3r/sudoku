import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sudoku/domain/coach/coach.dart';
import 'package:sudoku/domain/coach/coach_step.dart';
import 'package:sudoku/domain/models/game_state.dart';
import 'package:sudoku/providers/game_notifier.dart';

/// Stages of a coach hint. Each one reveals a bit more.
enum CoachStage {
  /// Technique name only.
  name,

  /// Where to look.
  area,

  /// The full pattern and what it removes.
  pattern,
}

@immutable
class CoachState {
  const CoachState({
    required this.step,
    required this.stage,
    required this.boardKey,
    this.marks = const {},
  });

  /// Null means: nothing found with the techniques the coach knows.
  final CoachStep? step;
  final CoachStage stage;

  /// Snapshot of digits and notes the step was computed for.
  final String boardKey;

  /// Digits to show inside pattern cells at the pattern stage.
  final Map<int, Set<int>> marks;

  CoachState copyWith({CoachStage? stage}) => CoachState(
    step: step,
    stage: stage ?? this.stage,
    boardKey: boardKey,
    marks: marks,
  );
}

/// Identifies the board content, ignoring the timer.
String coachBoardKey(GameState s) {
  final buffer = StringBuffer(s.grid.values.join());
  for (final n in s.notes) {
    buffer
      ..write('|')
      ..write((n.toList()..sort()).join());
  }
  return buffer.toString();
}

final coachProvider = NotifierProvider.autoDispose<CoachNotifier, CoachState?>(
  CoachNotifier.new,
  name: 'coachProvider',
);

/// The coach state, but only while the board still matches it.
final activeCoachProvider = Provider.autoDispose<CoachState?>((ref) {
  final coach = ref.watch(coachProvider);
  if (coach == null) return null;
  final key = ref.watch(
    gameProvider.select((s) {
      final v = s.value;
      return v == null ? null : coachBoardKey(v);
    }),
  );
  return key == coach.boardKey ? coach : null;
}, name: 'activeCoachProvider');

class CoachNotifier extends Notifier<CoachState?> {
  @override
  CoachState? build() => null;

  void start(GameState game) {
    final step = nextCoachStep(game);
    final marks = <int, Set<int>>{};
    if (step != null) {
      final board = CoachBoard.fromPlayer(game.grid.values, game.notes);
      for (final cell in step.patternCells) {
        if (board.values[cell] != 0) continue;
        final digits = step.patternDigits
            .where((d) => board.has(cell, d))
            .toSet();
        if (digits.isNotEmpty) marks[cell] = digits;
      }
    }
    state = CoachState(
      step: step,
      stage: CoachStage.name,
      boardKey: coachBoardKey(game),
      marks: marks,
    );
  }

  void next() {
    final current = state;
    if (current == null) return;
    final i = current.stage.index;
    if (i >= CoachStage.values.length - 1) return;
    state = current.copyWith(stage: CoachStage.values[i + 1]);
  }

  void close() => state = null;
}

/// How the coach wants a single cell drawn.
enum CoachTint { none, area, pattern, target }

@immutable
class CoachCellView {
  const CoachCellView({
    this.tint = CoachTint.none,
    this.mark = const {},
    this.strike = const {},
  });

  static const empty = CoachCellView();

  final CoachTint tint;

  /// Candidates that are part of the pattern.
  final Set<int> mark;

  /// Candidates the step removes.
  final Set<int> strike;

  bool get isEmpty => tint == CoachTint.none && mark.isEmpty && strike.isEmpty;

  static CoachCellView of(CoachState? coach, int index) {
    final step = coach?.step;
    if (coach == null || step == null) return empty;
    final stage = coach.stage;
    if (stage == CoachStage.name) return empty;

    if (stage == CoachStage.area) {
      return step.focusCells.contains(index)
          ? const CoachCellView(tint: CoachTint.area)
          : empty;
    }

    final strike = step.eliminations[index] ?? const <int>{};
    final placement = step.placement;
    final isTarget =
        strike.isNotEmpty ||
        placement?.cell == index ||
        step.erase == index ||
        step.restoreNotes.contains(index);
    final mark = <int>{
      ...?coach.marks[index],
      if (placement != null && placement.cell == index) placement.digit,
    };
    final tint = isTarget
        ? CoachTint.target
        : step.patternCells.contains(index)
        ? CoachTint.pattern
        : step.focusCells.contains(index)
        ? CoachTint.area
        : CoachTint.none;
    return CoachCellView(tint: tint, mark: mark, strike: strike);
  }
}
