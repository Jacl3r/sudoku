import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sudoku/domain/engine/game_engine.dart';
import 'package:sudoku/domain/models/difficulty.dart';
import 'package:sudoku/domain/models/game_state.dart';
import 'package:sudoku/domain/models/imported_game.dart';
import 'package:sudoku/domain/models/stat_record.dart';
import 'package:sudoku/providers/board_notifier.dart';
import 'package:sudoku/providers/difficulty_provider.dart';
import 'package:sudoku/providers/game_command.dart';
import 'package:sudoku/providers/services_provider.dart';
import 'package:sudoku/providers/settings_provider.dart';
import 'package:sudoku/providers/stats_provider.dart';

final gameProvider =
    AsyncNotifierProvider.autoDispose<GameNotifier, GameState?>(
      GameNotifier.new,
      name: 'gameProvider',
    );

final isFinishedProvider = Provider.autoDispose((ref) {
  final puzzleComplete = ref.watch(
    gameProvider.select((s) => s.value?.puzzleComplete),
  );
  return puzzleComplete == true;
}, name: 'isFinishedProvider');

const kTick = Duration(seconds: 1);

/// Where the running game is saved: a difficulty name or an `import:<id>` key.
/// Whoever opens the game screen sets it; it is cleared when the screen goes.
final activeSaveKeyProvider = NotifierProvider<ActiveSaveKeyNotifier, String?>(
  ActiveSaveKeyNotifier.new,
  name: 'activeSaveKeyProvider',
);

class ActiveSaveKeyNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? key) => state = key;
}

class GameNotifier extends AsyncNotifier<GameState?> {
  GameEngine? _gameEngine;
  Timer? _timer;
  bool _disposed = false;

  @override
  Future<GameState?> build() async {
    final saveGameService = ref.read(saveGameServiceProvider);
    final difficulty = ref.read(difficultyProvider);

    var key = ref.read(activeSaveKeyProvider) ?? difficulty.name;
    var saved = saveGameService.loadKey(key);
    // An import whose state vanished falls back to a fresh difficulty game
    // rather than resurrecting the import key.
    if (saved == null && isImportKey(key)) {
      key = difficulty.name;
      saved = saveGameService.loadKey(key);
    }

    ref.onDispose(() {
      _disposed = true;
      _timer?.cancel();
      final engine = _gameEngine;
      if (engine != null) {
        final current = engine.currentState;
        if (current.puzzleComplete) {
          unawaited(saveGameService.deleteKey(key));
        } else {
          unawaited(saveGameService.save(current, key: key));
        }
      }
    });

    final initialState = saved ?? await _generateNew(difficulty);

    _gameEngine = GameEngine(initialState);
    startTimer();
    return _gameEngine?.currentState;
  }

  Future<GameState> _generateNew(Difficulty difficulty) async {
    final puzzle = await ref
        .read(puzzleGeneratorServiceProvider)
        .generate(difficulty);
    return GameState.newGame(puzzle: puzzle, difficulty: difficulty);
  }

  void startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(kTick, (_) {
      if (_disposed) return;
      _gameEngine?.tick(kTick);
      state = AsyncData(_gameEngine?.currentState);
    });
  }

  void pauseTimer() {
    _timer?.cancel();
  }

  /// The one way to change the game. Every call mutates the engine, publishes
  /// the new state, and bookkeeps completion in the same place.
  void apply(GameCommand command) {
    final engine = _gameEngine;
    if (engine == null) return;

    switch (command) {
      case EnterDigit(:final cell, :final digit, :final inputMode):
        if (inputMode == .number) {
          engine.inputDigit(
            cell,
            digit,
            autoRemoveNotes: ref.read(settingsProvider).autoRemoveNotes,
          );
        } else {
          engine.toggleNote(cell, digit);
        }
      case EraseEntry(:final cell):
        engine.erase(cell);
      case UndoStep():
        engine.undo();
      case RevealHint():
        engine.revealHint(
          autoRemoveNotes: ref.read(settingsProvider).autoRemoveNotes,
        );
      case MarkHintUsed():
        engine.markHintUsed();
      case ValidateBoard():
        ref.read(boardProvider.notifier).setErrorCells(engine.findErrors());
      case FillNotes():
        engine.autoFillNotes();
      case ApplyCoachStep(:final step):
        engine.applyCoachStep(
          step,
          autoRemoveNotes: ref.read(settingsProvider).autoRemoveNotes,
        );
        // A fresh deduction replaces whatever the last validation flagged.
        ref.read(boardProvider.notifier).setErrorCells({});
      case RestartGame():
        engine.restart();
        ref.read(boardProvider.notifier).reset();
    }

    _publish();
  }

  void _publish() {
    final engine = _gameEngine;
    if (engine == null) return;
    final wasComplete = state.value?.puzzleComplete ?? false;
    final next = engine.currentState;
    state = AsyncData(next);
    if (!wasComplete && next.puzzleComplete) _onPuzzleComplete();
  }

  void _onPuzzleComplete() {
    _timer?.cancel();
    final completed = _gameEngine?.currentState;
    if (completed != null) {
      final record = StatRecord.fromGameState(completed);
      ref.read(lastCompletionRecordProvider.notifier).state = record;
      ref.read(statsNotifierProvider.notifier).add(record);
    }
  }
}
