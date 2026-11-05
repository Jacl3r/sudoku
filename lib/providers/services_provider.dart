import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:sudoku/data/hive_boxes.dart';
import 'package:sudoku/data/services/puzzle_generator_service.dart';
import 'package:sudoku/data/services/puzzle_import_service.dart';
import 'package:sudoku/data/services/save_game_service.dart';
import 'package:sudoku/domain/models/difficulty.dart';
import 'package:sudoku/domain/models/game_state.dart';
import 'package:sudoku/domain/models/imported_game.dart';
import 'package:sudoku/domain/services/puzzle_generator_service.dart';

final puzzleGeneratorServiceProvider = Provider<PuzzleGeneratorService>(
  (ref) => const IsolatePuzzleGeneratorService(),
  name: 'puzzleGeneratorServiceProvider',
);

final saveGameServiceProvider = Provider<SaveGameService>(
  (ref) => SaveGameService(),
  name: 'saveGameServiceProvider',
);

final puzzleImportServiceProvider = Provider<PuzzleImportService>(
  (ref) => PuzzleImportService(),
  name: 'puzzleImportServiceProvider',
);

final continueGameProvider =
    NotifierProvider<ContinueGameNotifier, Map<Difficulty, GameState?>>(
      ContinueGameNotifier.new,
      name: 'continueGameProvider',
    );

class ContinueGameNotifier extends Notifier<Map<Difficulty, GameState?>> {
  Box<String> get _box => Hive.box(gameBox);

  @override
  Map<Difficulty, GameState?> build() {
    final sub = _box.watch().listen((event) {
      final keyStr = event.key as String;
      final difficulty = Difficulty.values
          .where((d) => d.name == keyStr)
          .firstOrNull;

      if (difficulty != null) {
        GameState? nextState;

        if (!event.deleted && event.value != null) {
          final map = jsonDecode(event.value as String) as Map<String, dynamic>;
          nextState = GameState.fromJson(map);
        }
        state = {...state, difficulty: nextState};
      }
    });

    ref.onDispose(sub.cancel);
    return {for (final d in Difficulty.values) d: _loadState(d)};
  }

  GameState? _loadState(Difficulty d) {
    final raw = _box.get(d.name);
    if (raw == null) return null;
    return GameState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}

/// Which game was saved last: a difficulty name or an `import:<id>` key.
final lastPlayedProvider = NotifierProvider<LastPlayedNotifier, String?>(
  LastPlayedNotifier.new,
  name: 'lastPlayedProvider',
);

class LastPlayedNotifier extends Notifier<String?> {
  Box<String> get _box => Hive.box(gameBox);

  @override
  String? build() {
    final sub = _box.watch().listen((event) {
      if (event.key != SaveGameService.lastPlayedKey) return;
      state = _read();
    });

    ref.onDispose(sub.cancel);
    return _read();
  }

  String? _read() {
    final key = _box.get(SaveGameService.lastPlayedKey);
    if (key == null) return null;
    if (isImportKey(key)) return key;
    return Difficulty.values.any((d) => d.name == key) ? key : null;
  }
}

/// Imported puzzles, newest first.
final importedGamesProvider =
    NotifierProvider<ImportedGamesNotifier, List<ImportedGame>>(
      ImportedGamesNotifier.new,
      name: 'importedGamesProvider',
    );

class ImportedGamesNotifier extends Notifier<List<ImportedGame>> {
  Box<String> get _box => Hive.box(gameBox);

  @override
  List<ImportedGame> build() {
    final sub = _box.watch().listen((event) {
      final key = event.key as String;
      if (key != SaveGameService.importsKey && !isImportKey(key)) return;
      state = _read();
    });

    ref.onDispose(sub.cancel);
    return _read();
  }

  List<ImportedGame> _read() => ref.read(saveGameServiceProvider).imports();
}

/// A game the home screen can offer to resume.
class ResumableGame {
  const new({required this.state, this.imported});

  final GameState state;
  final ImportedGame? imported;

  bool get isImport => imported != null;

  String get key => imported?.key ?? state.difficulty.name;

  String get label => isImport
      ? 'import · ${state.difficulty.displayName}'
      : state.difficulty.displayName;
}

/// The most recently played save, ready to resume, or null when there is
/// nothing worth resuming.
final resumableGameProvider = Provider<ResumableGame?>((ref) {
  final key = ref.watch(lastPlayedProvider);
  if (key == null) return null;

  if (isImportKey(key)) {
    final id = importIdFromKey(key);
    final match = ref
        .watch(importedGamesProvider)
        .where((game) => game.id == id)
        .firstOrNull;
    if (match == null || !match.state.grid.values.contains(0)) return null;
    return ResumableGame(state: match.state, imported: match);
  }

  final difficulty = Difficulty.values.where((d) => d.name == key).firstOrNull;
  if (difficulty == null) return null;
  final state = ref.watch(continueGameProvider)[difficulty];
  // A full board has nothing left to resume; the save is a leftover from a
  // session that ended before the game screen was disposed.
  if (state == null || !state.grid.values.contains(0)) return null;
  return ResumableGame(state: state);
}, name: 'resumableGameProvider');
