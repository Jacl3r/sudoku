import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sudoku/presentation/models/board_intent.dart';
import 'package:sudoku/providers/board_notifier.dart';
import 'package:sudoku/providers/game_command.dart';
import 'package:sudoku/providers/game_notifier.dart';

/// The one place a [BoardIntent] turns into a mutation, so the widgets do not
/// each restate which provider an intent belongs to.
void applyBoardIntent(WidgetRef ref, BoardIntent intent) {
  switch (intent) {
    case WriteDigit(:final cell, :final digit, :final inputMode):
      ref
          .read(gameProvider.notifier)
          .apply(EnterDigit(cell: cell, digit: digit, inputMode: inputMode));
    case EraseCell(:final cell):
      ref.read(gameProvider.notifier).apply(EraseEntry(cell));
    case SelectCell(:final cell):
      ref.read(boardProvider.notifier).selectCell(cell);
    case SelectDigit(:final digit):
      ref.read(boardProvider.notifier).selectDigit(digit);
    case ToggleNotesMode():
      ref.read(boardProvider.notifier).toggleInputMode();
    case ClearErrorCell(:final cell):
      ref.read(boardProvider.notifier).removeErrorCell(cell);
  }
}
