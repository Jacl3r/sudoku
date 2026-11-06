import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/presentation/models/board_intent.dart';
import 'package:sudoku/presentation/models/board_state.dart';
import 'package:sudoku/presentation/shared/input_method.dart';

void main() {
  const idle = BoardState();
  const cellSelected = BoardState(selectedCell: 40);
  const digitSelected = BoardState(selectedDigit: 7);
  const bothSelected = BoardState(selectedCell: 40, selectedDigit: 7);
  const notesMode = BoardState(selectedCell: 40, inputMode: .pencil);

  group('cell tap', () {
    test('writes the selected digit in the current mode', () {
      final intent = intentForCellTap(cell: 40, board: bothSelected);
      expect(intent, isA<WriteDigit>());
      final write = intent as WriteDigit;
      expect(write.cell, 40);
      expect(write.digit, 7);
      expect(write.inputMode, InputMode.number);
    });

    test('respects notes mode', () {
      const board = BoardState(
        selectedCell: 1,
        selectedDigit: 3,
        inputMode: .pencil,
      );
      final write = intentForCellTap(cell: 9, board: board) as WriteDigit;
      expect(write.inputMode, InputMode.pencil);
    });

    test('selects the cell when no digit is selected', () {
      expect(
        intentForCellTap(cell: 12, board: idle),
        isA<SelectCell>().having((i) => i.cell, 'cell', 12),
      );
      expect(
        intentForCellTap(cell: 12, board: cellSelected),
        isA<SelectCell>(),
      );
    });
  });

  group('digit tap', () {
    test('writes into the selected cell', () {
      final write = intentForDigitTap(
        digit: 4,
        board: cellSelected,
        puzzleComplete: false,
      ) as WriteDigit;
      expect(write.cell, 40);
      expect(write.digit, 4);
    });

    test('selects the digit when no cell is selected', () {
      expect(
        intentForDigitTap(digit: 4, board: idle, puzzleComplete: false),
        isA<SelectDigit>().having((i) => i.digit, 'digit', 4),
      );
    });

    test('does nothing on a solved board', () {
      expect(
        intentForDigitTap(digit: 4, board: cellSelected, puzzleComplete: true),
        isNull,
      );
    });
  });

  group('erase', () {
    test('acts on the selected cell', () {
      expect(
        intentForErase(board: cellSelected, puzzleComplete: false),
        isA<EraseCell>().having((i) => i.cell, 'cell', 40),
      );
    });

    test('does nothing without a cell or on a solved board', () {
      expect(
        intentForErase(board: digitSelected, puzzleComplete: false),
        isNull,
      );
      expect(intentForErase(board: cellSelected, puzzleComplete: true), isNull);
    });
  });

  group('keys', () {
    test('arrows move the selection and stop at the edge', () {
      expect(
        intentForKey(
          key: LogicalKeyboardKey.arrowRight,
          board: cellSelected,
          puzzleComplete: false,
        ),
        isA<SelectCell>().having((i) => i.cell, 'cell', 41),
      );
      expect(
        intentForKey(
          key: LogicalKeyboardKey.arrowLeft,
          board: const BoardState(selectedCell: 36),
          puzzleComplete: false,
        ),
        isA<SelectCell>().having((i) => i.cell, 'cell', 36),
      );
    });

    test('arrows still work on a solved board', () {
      expect(
        intentForKey(
          key: LogicalKeyboardKey.arrowDown,
          board: cellSelected,
          puzzleComplete: true,
        ),
        isA<SelectCell>().having((i) => i.cell, 'cell', 49),
      );
    });

    test('digits and erase go quiet on a solved board', () {
      expect(
        intentForKey(
          key: LogicalKeyboardKey.digit4,
          board: cellSelected,
          puzzleComplete: true,
        ),
        isNull,
      );
      expect(
        intentForKey(
          key: LogicalKeyboardKey.backspace,
          board: cellSelected,
          puzzleComplete: true,
        ),
        isNull,
      );
    });

    test('digit, erase and notes keys map to the same intents as taps', () {
      expect(
        intentForKey(
          key: LogicalKeyboardKey.digit4,
          board: cellSelected,
          puzzleComplete: false,
        ),
        isA<WriteDigit>(),
      );
      expect(
        intentForKey(
          key: LogicalKeyboardKey.keyX,
          board: cellSelected,
          puzzleComplete: false,
        ),
        isA<EraseCell>(),
      );
      expect(
        intentForKey(
          key: LogicalKeyboardKey.keyN,
          board: notesMode,
          puzzleComplete: false,
        ),
        isA<ToggleNotesMode>(),
      );
    });

    test('app actions are not board inputs', () {
      for (final key in [
        LogicalKeyboardKey.keyU,
        LogicalKeyboardKey.keyH,
        LogicalKeyboardKey.keyR,
        LogicalKeyboardKey.keyE,
      ]) {
        expect(
          intentForKey(key: key, board: cellSelected, puzzleComplete: false),
          isNull,
          reason: '$key belongs to the screen, not the board',
        );
      }
    });
  });
}
