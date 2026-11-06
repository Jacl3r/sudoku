import 'package:sudoku/data/services/save_game_service.dart';
import 'package:sudoku/domain/models/difficulty.dart';
import 'package:sudoku/domain/models/game_state.dart';
import 'package:sudoku/domain/models/imported_game.dart';
import 'package:sudoku/domain/models/stat_record.dart';
import 'package:sudoku/providers/difficulty_provider.dart';

class FakeSaveGameService implements SaveGameService {
  final Map<String, GameState> _store = {};
  final Map<String, DateTime> _importDates = {};
  final List<Difficulty> deletedDifficulties = [];
  int saveCalls = 0;
  int deleteCalls = 0;

  String? _lastPlayed;

  @override
  String? get lastPlayed => _lastPlayed;

  @override
  bool isLastPlayedKey(Object? key) => false;

  @override
  bool isLibraryKey(Object? key) => false;

  @override
  Future<void> save(GameState state, {String? key}) async {
    saveCalls++;
    final target = key ?? state.difficulty.name;
    _store[target] = state;
    _lastPlayed = target;
    if (isImportKey(target)) _importDates[target] = DateTime.now();
  }

  @override
  GameState? load(Difficulty difficulty) => _store[difficulty.name];

  @override
  GameState? loadKey(String key) => _store[key];

  @override
  Future<void> delete(Difficulty difficulty) async {
    deleteCalls++;
    deletedDifficulties.add(difficulty);
    _store.remove(difficulty.name);
  }

  @override
  Future<void> deleteKey(String key) async {
    _store.remove(key);
    _importDates.remove(key);
  }

  @override
  Future<ImportedGame> saveImport(GameState state) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    await save(state, key: importKey(id));
    return ImportedGame(id: id, state: state, savedAt: DateTime.now());
  }

  @override
  ImportedGame? loadImport(String id) {
    final key = importKey(id);
    final state = _store[key];
    if (state == null) return null;
    return ImportedGame(
      id: id,
      state: state,
      savedAt: _importDates[key] ?? DateTime.now(),
    );
  }

  @override
  Future<void> deleteImport(String id) => deleteKey(importKey(id));

  @override
  List<ImportedGame> imports() {
    final entries = [
      for (final entry in _store.entries)
        if (isImportKey(entry.key))
          ImportedGame(
            id: importIdFromKey(entry.key),
            state: entry.value,
            savedAt: _importDates[entry.key] ?? DateTime.now(),
          ),
    ]..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return entries;
  }

  GameState? savedFor(Difficulty difficulty) => _store[difficulty.name];
}

class FakeStatsService {
  final Map<Difficulty, List<StatRecord>> _store = {};
  int saveCalls = 0;

  List<StatRecord> getAll(Difficulty difficulty) =>
      List<StatRecord>.from(_store[difficulty] ?? const []);

  Future<void> save(StatRecord record) async {
    saveCalls++;
    (_store[record.difficulty] ??= <StatRecord>[]).add(record);
  }

  Future<void> reset() async => _store.clear();

  Map<Difficulty, List<StatRecord>> get seed => Map.unmodifiable(_store);
}

class FakeDifficultyNotifier extends DifficultyProvider {
  new(this._difficulty);
  final Difficulty _difficulty;

  @override
  Difficulty build() => _difficulty;

  @override
  void set(Difficulty difficulty) => state = difficulty;
}
