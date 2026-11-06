import 'package:flutter/services.dart';
import 'package:sudoku/presentation/models/board_state.dart';
import 'package:sudoku/presentation/shared/input_method.dart';

/// What an interaction means for the board, however it arrived: a tap on a
/// cell, a tap on a digit, or a key.
///
/// Resolving is pure, so the rules can be tested without mounting a widget;
/// applying is the thin adapter in `shared/board_intent_actions.dart`.
sealed class BoardIntent {
  const new();
}

/// Write a digit into a cell, in the current input mode.
final class WriteDigit extends BoardIntent {
  const new({required this.cell, required this.digit, required this.inputMode});

  final int cell;
  final int digit;
  final InputMode inputMode;
}

final class EraseCell extends BoardIntent {
  const new(this.cell);

  final int cell;
}

/// Move the selection to a cell, which also clears a selected digit.
final class SelectCell extends BoardIntent {
  const new(this.cell);

  final int cell;
}

final class SelectDigit extends BoardIntent {
  const new(this.digit);

  final int digit;
}

final class ToggleNotesMode extends BoardIntent {
  const new();
}

/// A tapped cell that is marked wrong drops that mark first.
final class ClearErrorCell extends BoardIntent {
  const new(this.cell);

  final int cell;
}

/// A cell tap writes the selected digit, or selects the cell when no digit is
/// selected.
BoardIntent intentForCellTap({required int cell, required BoardState board}) {
  final digit = board.selectedDigit;
  if (digit == null) return SelectCell(cell);
  return WriteDigit(cell: cell, digit: digit, inputMode: board.inputMode);
}

/// A digit tap writes into the selected cell, or selects the digit when no cell
/// is selected.
BoardIntent? intentForDigitTap({
  required int digit,
  required BoardState board,
  required bool puzzleComplete,
}) {
  if (puzzleComplete) return null;
  final cell = board.selectedCell;
  if (cell == null) return SelectDigit(digit);
  return WriteDigit(cell: cell, digit: digit, inputMode: board.inputMode);
}

/// Erasing acts on the selected cell and does nothing without one.
BoardIntent? intentForErase({
  required BoardState board,
  required bool puzzleComplete,
}) {
  if (puzzleComplete) return null;
  final cell = board.selectedCell;
  return cell == null ? null : EraseCell(cell);
}

/// What a key means. Null means the key is not a board input, so the caller
/// keeps whatever it does with it.
///
/// Navigation stays live on a solved board; every other input goes quiet.
BoardIntent? intentForKey({
  required LogicalKeyboardKey key,
  required BoardState board,
  required bool puzzleComplete,
}) {
  final current = board.selectedCell ?? 0;
  switch (key) {
    case .arrowLeft || .keyA:
      return SelectCell(current % 9 > 0 ? current - 1 : current);
    case .arrowRight || .keyD:
      return SelectCell(current % 9 < 8 ? current + 1 : current);
    case .arrowUp || .keyW:
      return SelectCell(current >= 9 ? current - 9 : current);
    case .arrowDown || .keyS:
      return SelectCell(current <= 71 ? current + 9 : current);
    default:
  }

  if (puzzleComplete) return null;

  switch (key) {
    case .backspace || .delete || .keyX:
      return intentForErase(board: board, puzzleComplete: puzzleComplete);
    case .keyN || .keyP:
      return const ToggleNotesMode();
    default:
  }

  if (key.keyLabel.length != 1) return null;
  final digit = int.tryParse(key.keyLabel);
  if (digit == null || digit < 1 || digit > 9) return null;
  return intentForDigitTap(
    digit: digit,
    board: board,
    puzzleComplete: puzzleComplete,
  );
}
