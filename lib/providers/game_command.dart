import 'package:sudoku/domain/coach/coach_step.dart';
import 'package:sudoku/presentation/shared/input_method.dart';

/// Everything that can change the running game, one opaque value per user
/// action.
///
/// The notifier takes these through a single entry point, so mutating,
/// publishing, completion bookkeeping and board hygiene happen in one place
/// rather than in every method that happens to touch the engine.
sealed class GameCommand {
  const new();
}

final class EnterDigit extends GameCommand {
  const new({required this.cell, required this.digit, required this.inputMode});

  final int cell;
  final int digit;
  final InputMode inputMode;
}

final class EraseEntry extends GameCommand {
  const new(this.cell);

  final int cell;
}

final class UndoStep extends GameCommand {
  const new();
}

final class RevealHint extends GameCommand {
  const new();
}

final class MarkHintUsed extends GameCommand {
  const new();
}

final class ValidateBoard extends GameCommand {
  const new();
}

final class FillNotes extends GameCommand {
  const new();
}

final class ApplyCoachStep extends GameCommand {
  const new(this.step);

  final CoachStep step;
}

final class RestartGame extends GameCommand {
  const new();
}
