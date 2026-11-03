import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:sudoku/data/hive_boxes.dart';
import 'package:sudoku/domain/models/difficulty.dart';

final difficultyProvider = NotifierProvider(
  DifficultyProvider.new,
  name: 'difficultyProvider',
);

class DifficultyProvider extends Notifier<Difficulty> {
  static const _key = 'difficulty_key';

  Box<String> get _box => Hive.box(settingsBox);

  @override
  Difficulty build() {
    final stored = _box.get(_key);
    return Difficulty.values.where((d) => d.name == stored).firstOrNull ??
        .easy;
  }

  void set(Difficulty difficulty) {
    state = difficulty;
    unawaited(_box.put(_key, difficulty.name));
  }
}
