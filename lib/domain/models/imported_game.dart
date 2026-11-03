import 'package:sudoku/domain/models/game_state.dart';

/// Saved imports live under their own keys, so they can never replace a game
/// saved for a difficulty.
const importKeyPrefix = 'import:';

String importKey(String id) => '$importKeyPrefix$id';

bool isImportKey(String key) => key.startsWith(importKeyPrefix);

String importIdFromKey(String key) => key.substring(importKeyPrefix.length);

/// One imported puzzle, kept independently of the difficulty slots.
class ImportedGame {
  const ImportedGame({
    required this.id,
    required this.state,
    required this.savedAt,
  });

  final String id;
  final GameState state;
  final DateTime savedAt;

  String get key => importKey(id);
}

/// Index entry: enough to list and order the library without decoding every
/// saved board.
class ImportIndexEntry {
  const ImportIndexEntry({required this.id, required this.savedAt});

  factory ImportIndexEntry.fromJson(Map<String, dynamic> json) =>
      ImportIndexEntry(
        id: json['id'] as String,
        savedAt: DateTime.fromMillisecondsSinceEpoch(json['savedAt'] as int),
      );

  final String id;
  final DateTime savedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'savedAt': savedAt.millisecondsSinceEpoch,
  };
}
