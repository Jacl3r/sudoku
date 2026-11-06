import 'dart:convert';

import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:sudoku/data/hive_boxes.dart';
import 'package:sudoku/domain/models/difficulty.dart';
import 'package:sudoku/domain/models/game_state.dart';
import 'package:sudoku/domain/models/imported_game.dart';

class SaveGameService {
  new() : _box = Hive.box(gameBox);

  /// Box key naming the game saved most recently: a difficulty name or an
  /// `import:<id>` key.
  static const _lastPlayedKey = '__lastPlayed';

  /// Box key holding the import index as JSON.
  static const _importsKey = '__imports';

  final Box<String> _box;

  /// The save a resume would open, or null when the marker names something we
  /// no longer understand (an old import, a renamed difficulty).
  String? get lastPlayed {
    final key = _box.get(_lastPlayedKey);
    if (key == null) return null;
    if (isImportKey(key)) return key;
    return Difficulty.values.any((d) => d.name == key) ? key : null;
  }

  /// Whether a box change with [key] can move [_lastPlayedKey].
  bool isLastPlayedKey(Object? key) => key == _lastPlayedKey;

  /// Whether a box change with [key] can change the import library.
  bool isLibraryKey(Object? key) =>
      key == _importsKey || (key is String && isImportKey(key));

  Future<void> save(GameState state, {String? key}) async {
    final target = key ?? state.difficulty.name;
    await _box.put(target, jsonEncode(state));
    if (isImportKey(target)) {
      final id = importIdFromKey(target);
      final index = _readIndex()
        ..removeWhere((entry) => entry.id == id)
        ..insert(0, ImportIndexEntry(id: id, savedAt: DateTime.now()));
      await _writeIndex(index);
    }
    await _box.put(_lastPlayedKey, target);
  }

  GameState? load(Difficulty difficulty) => loadKey(difficulty.name);

  GameState? loadKey(String key) {
    final raw = _box.get(key);
    if (raw == null) return null;
    return GameState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> delete(Difficulty difficulty) => deleteKey(difficulty.name);

  Future<void> deleteKey(String key) async {
    await _box.delete(key);
    if (isImportKey(key)) {
      await _writeIndex(
        _readIndex()..removeWhere((entry) => entry.id == importIdFromKey(key)),
      );
    }
    if (_box.get(_lastPlayedKey) == key) {
      await _box.delete(_lastPlayedKey);
    }
  }

  /// Stores a puzzle in the import library and returns it.
  Future<ImportedGame> saveImport(GameState state) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    await save(state, key: importKey(id));
    return ImportedGame(id: id, state: state, savedAt: DateTime.now());
  }

  ImportedGame? loadImport(String id) {
    final state = loadKey(importKey(id));
    if (state == null) return null;
    final entry = _readIndex().where((e) => e.id == id).firstOrNull;
    return ImportedGame(
      id: id,
      state: state,
      savedAt: entry?.savedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Future<void> deleteImport(String id) => deleteKey(importKey(id));

  /// The library, newest first.
  List<ImportedGame> imports() => [
    for (final entry in _readIndex())
      if (loadKey(importKey(entry.id)) case final state?)
        ImportedGame(id: entry.id, state: state, savedAt: entry.savedAt),
  ];

  List<ImportIndexEntry> _readIndex() {
    final raw = _box.get(_importsKey);
    if (raw == null) return [];
    return [
      for (final entry in jsonDecode(raw) as List)
        ImportIndexEntry.fromJson(Map<String, dynamic>.from(entry as Map)),
    ];
  }

  Future<void> _writeIndex(List<ImportIndexEntry> entries) => _box.put(
    _importsKey,
    jsonEncode([for (final entry in entries) entry.toJson()]),
  );
}
