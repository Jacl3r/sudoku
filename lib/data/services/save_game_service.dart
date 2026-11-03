import 'dart:convert';

import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:sudoku/data/hive_boxes.dart';
import 'package:sudoku/domain/models/difficulty.dart';
import 'package:sudoku/domain/models/game_state.dart';
import 'package:sudoku/domain/models/imported_game.dart';

class SaveGameService {
  SaveGameService() : _box = Hive.box(gameBox);

  /// Box key naming the game saved most recently: a difficulty name or an
  /// `import:<id>` key.
  static const lastPlayedKey = '__lastPlayed';

  /// Box key holding the import index as JSON.
  static const importsKey = '__imports';

  final Box<String> _box;

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
    await _box.put(lastPlayedKey, target);
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
    if (_box.get(lastPlayedKey) == key) {
      await _box.delete(lastPlayedKey);
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
    final raw = _box.get(importsKey);
    if (raw == null) return [];
    return [
      for (final entry in jsonDecode(raw) as List)
        ImportIndexEntry.fromJson(Map<String, dynamic>.from(entry as Map)),
    ];
  }

  Future<void> _writeIndex(List<ImportIndexEntry> entries) => _box.put(
    importsKey,
    jsonEncode([for (final entry in entries) entry.toJson()]),
  );
}
