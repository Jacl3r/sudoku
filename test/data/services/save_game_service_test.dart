import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:sudoku/data/hive_boxes.dart';
import 'package:sudoku/data/services/save_game_service.dart';
import 'package:sudoku/domain/coach/coach_step.dart';
import 'package:sudoku/domain/engine/game_engine.dart';
import 'package:sudoku/domain/models/difficulty.dart';
import 'package:sudoku/domain/models/game_assists.dart';
import 'package:sudoku/domain/models/game_state.dart';
import 'package:sudoku/domain/models/imported_game.dart';
import 'package:sudoku/domain/models/puzzle.dart';
import 'package:sudoku/providers/difficulty_provider.dart';
import 'package:sudoku/providers/services_provider.dart';

import '../../helpers/sudoku_grids.dart';

void main() {
  late Directory dir;
  late Box<String> game;
  late Box<String> settings;

  final puzzle = Puzzle(
    given: TestGrids.simplePuzzle(),
    solution: TestGrids.simpleSolution(),
  );

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('sudoku_save_test');
    Hive.init(dir.path);
    game = await Hive.openBox<String>(gameBox);
    settings = await Hive.openBox<String>(settingsBox);
  });

  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  setUp(() async {
    await game.clear();
    await settings.clear();
  });

  test('saves survive a round trip and track the last played game', () async {
    final service = SaveGameService();

    await service.save(
      GameState.newGame(puzzle: puzzle, difficulty: Difficulty.expert),
    );
    expect(game.get(SaveGameService.lastPlayedKey), 'expert');
    expect(service.load(Difficulty.expert), isNotNull);

    // Everything the player had survives the round trip.
    final notes = List<Set<int>>.generate(81, (_) => <int>{})..[3] = {1, 2};
    final eliminations = List<Set<int>>.generate(81, (_) => <int>{})..[4] = {5};
    await service.save(
      GameState.newGame(puzzle: puzzle, difficulty: Difficulty.expert).copyWith(
        elapsed: const Duration(minutes: 12),
        notes: notes,
        coachEliminations: eliminations,
        assists: const GameAssists(hints: true),
      ),
    );
    final loaded = service.load(Difficulty.expert)!;
    expect(loaded.elapsed, const Duration(minutes: 12));
    expect(loaded.notes[3], {1, 2});
    expect(loaded.coachEliminationsAt(4), {5});
    expect(loaded.assists.hints, isTrue);

    // Deleting something else leaves the marker alone.
    await service.delete(Difficulty.easy);
    expect(game.get(SaveGameService.lastPlayedKey), 'expert');

    await service.delete(Difficulty.expert);
    expect(game.get(SaveGameService.lastPlayedKey), isNull);
    expect(service.load(Difficulty.expert), isNull);
  });

  test('imports are stored apart from difficulty saves', () async {
    final service = SaveGameService();

    final first = GameState.newGame(
      puzzle: puzzle,
      difficulty: Difficulty.hard,
    ).copyWith(elapsed: const Duration(minutes: 1));
    final second = GameState.newGame(
      puzzle: puzzle,
      difficulty: Difficulty.expert,
    ).copyWith(elapsed: const Duration(minutes: 2));

    final one = await service.saveImport(first);
    final two = await service.saveImport(second);

    // Imports never take a difficulty slot.
    expect(service.load(Difficulty.hard), isNull);
    expect(service.load(Difficulty.expert), isNull);

    final library = service.imports();
    expect(library.length, 2);
    expect(library.first.id, two.id, reason: 'newest first');
    expect(library.last.id, one.id);
    expect(
      service.loadImport(one.id)!.state.elapsed,
      const Duration(minutes: 1),
    );

    // Saving an import updates the marker and the index timestamp.
    expect(game.get(SaveGameService.lastPlayedKey), importKey(two.id));

    await service.deleteImport(two.id);
    expect(service.imports().length, 1);
    expect(service.loadImport(two.id), isNull);
    expect(
      game.get(SaveGameService.lastPlayedKey),
      isNull,
      reason: 'deleting the active import clears the marker',
    );
  });

  test('undo survives a save round trip', () async {
    final service = SaveGameService();
    final engine =
        GameEngine(
            GameState.newGame(puzzle: puzzle, difficulty: Difficulty.expert),
          )
          ..inputDigit(2, 4)
          ..toggleNote(3, 7)
          ..inputDigit(10, 1);

    await service.save(engine.currentState);

    final restored = GameEngine(service.load(Difficulty.expert)!);
    expect(restored.canUndo, isTrue);
    expect(restored.currentState.history.length, 3);

    restored.undo();
    expect(restored.currentState.grid.valueAt(10), 0);
    restored.undo();
    expect(restored.currentState.notes[3], isEmpty);
    restored.undo();
    expect(restored.currentState.grid.valueAt(2), 0);
    expect(restored.canUndo, isFalse);
  });

  test('a coach step undoes as one step after a reload', () async {
    final service = SaveGameService();
    const step = CoachStep(
      headline: 'Look for a Skyscraper.',
      technique: 'Skyscraper',
      about: 'about',
      nudge: 'nudge',
      explanation: 'explanation',
      eliminations: {
        2: {5},
      },
    );
    final engine =
        GameEngine(
            GameState.newGame(puzzle: puzzle, difficulty: Difficulty.expert),
          )
          ..toggleNote(2, 5)
          ..applyCoachStep(step);

    expect(engine.currentState.notes[2], isEmpty);
    expect(engine.currentState.coachEliminationsAt(2), {5});

    await service.save(engine.currentState);
    final restored = GameEngine(service.load(Difficulty.expert)!)..undo();

    expect(restored.currentState.notes[2], {5});
    expect(restored.currentState.coachEliminationsAt(2), isEmpty);
    expect(restored.currentState.history.length, 1);
  });

  test('the meta key is not mistaken for a difficulty', () async {
    await SaveGameService().save(
      GameState.newGame(puzzle: puzzle, difficulty: Difficulty.expert),
    );

    final container = ProviderContainer();
    final games = container.read(continueGameProvider);

    expect(games.length, Difficulty.values.length);
    expect(games[Difficulty.expert], isNotNull);
    expect(container.read(lastPlayedProvider), 'expert');
    expect(
      container.read(resumableGameProvider)?.state.difficulty,
      Difficulty.expert,
    );

    container.dispose();
  });

  test('the difficulty selection survives a restart', () async {
    final first = ProviderContainer();
    expect(first.read(difficultyProvider), Difficulty.easy);

    first.read(difficultyProvider.notifier).set(Difficulty.expert);

    final second = ProviderContainer();
    expect(second.read(difficultyProvider), Difficulty.expert);

    first.dispose();
    second.dispose();
  });
}
