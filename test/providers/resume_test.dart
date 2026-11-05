import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/domain/models/difficulty.dart';
import 'package:sudoku/domain/models/game_state.dart';
import 'package:sudoku/domain/models/imported_game.dart';
import 'package:sudoku/domain/models/puzzle.dart';
import 'package:sudoku/providers/services_provider.dart';

import '../helpers/sudoku_grids.dart';

class _FakeLastPlayed extends LastPlayedNotifier {
  new(this._value);

  final String? _value;

  @override
  String? build() => _value;
}

class _FakeContinueGames extends ContinueGameNotifier {
  new(this._value);

  final Map<Difficulty, GameState?> _value;

  @override
  Map<Difficulty, GameState?> build() => _value;
}

class _FakeImports extends ImportedGamesNotifier {
  new(this._value);

  final List<ImportedGame> _value;

  @override
  List<ImportedGame> build() => _value;
}

void main() {
  final puzzle = Puzzle(
    given: TestGrids.simplePuzzle(),
    solution: TestGrids.simpleSolution(),
  );

  GameState game(Difficulty difficulty, {Duration elapsed = Duration.zero}) =>
      GameState.newGame(
        puzzle: puzzle,
        difficulty: difficulty,
      ).copyWith(elapsed: elapsed);

  GameState completed(Difficulty difficulty) =>
      game(difficulty)
          .copyWith(grid: puzzle.solution.clone(), puzzleComplete: true);

  ImportedGame imported(GameState state, {String id = '1'}) =>
      ImportedGame(id: id, state: state, savedAt: DateTime(2026, 11, 3));

  ProviderContainer container({
    required String? lastPlayed,
    required Map<Difficulty, GameState?> games,
    List<ImportedGame> imports = const [],
  }) => ProviderContainer(
    overrides: [
      lastPlayedProvider.overrideWith(() => _FakeLastPlayed(lastPlayed)),
      continueGameProvider.overrideWith(() => _FakeContinueGames(games)),
      importedGamesProvider.overrideWith(() => _FakeImports(imports)),
    ],
  );

  Map<Difficulty, GameState?> only(Difficulty difficulty, GameState? state) => {
    for (final d in Difficulty.values) d: d == difficulty ? state : null,
  };

  group('resumableGameProvider', () {
    test('returns the most recently played difficulty save', () {
      final containerUnderTest = container(
        lastPlayed: 'expert',
        games: only(
          Difficulty.expert,
          game(Difficulty.expert, elapsed: const Duration(minutes: 12)),
        ),
      );

      final result = containerUnderTest.read(resumableGameProvider);
      expect(result, isNotNull);
      expect(result!.isImport, isFalse);
      expect(result.state.difficulty, Difficulty.expert);
      expect(result.state.elapsed, const Duration(minutes: 12));
      expect(result.label, 'Expert');
      expect(result.key, 'expert');
      containerUnderTest.dispose();
    });

    test('returns null when nothing was played', () {
      final containerUnderTest = container(
        lastPlayed: null,
        games: only(Difficulty.easy, null),
      );
      expect(containerUnderTest.read(resumableGameProvider), isNull);
      containerUnderTest.dispose();
    });

    test('returns null when the last save is gone', () {
      final containerUnderTest = container(
        lastPlayed: 'expert',
        games: only(Difficulty.easy, null),
      );
      expect(containerUnderTest.read(resumableGameProvider), isNull);
      containerUnderTest.dispose();
    });

    test('returns null when the last board is complete', () {
      final containerUnderTest = container(
        lastPlayed: 'expert',
        games: only(Difficulty.expert, completed(Difficulty.expert)),
      );
      expect(containerUnderTest.read(resumableGameProvider), isNull);
      containerUnderTest.dispose();
    });

    test('resolves an imported game under its own key', () {
      final containerUnderTest = container(
        lastPlayed: 'import:1',
        games: only(Difficulty.easy, null),
        imports: [
          imported(game(Difficulty.hard, elapsed: const Duration(minutes: 3))),
        ],
      );

      final result = containerUnderTest.read(resumableGameProvider);
      expect(result, isNotNull);
      expect(result!.isImport, isTrue);
      expect(result.key, 'import:1');
      expect(result.label, 'import · Hard');
      expect(result.state.elapsed, const Duration(minutes: 3));
      containerUnderTest.dispose();
    });

    test('returns null when the import is gone', () {
      final containerUnderTest = container(
        lastPlayed: 'import:1',
        games: only(Difficulty.easy, null),
      );
      expect(containerUnderTest.read(resumableGameProvider), isNull);
      containerUnderTest.dispose();
    });

    test('returns null when the imported board is complete', () {
      final containerUnderTest = container(
        lastPlayed: 'import:1',
        games: only(Difficulty.easy, null),
        imports: [imported(completed(Difficulty.hard))],
      );
      expect(containerUnderTest.read(resumableGameProvider), isNull);
      containerUnderTest.dispose();
    });
  });
}
