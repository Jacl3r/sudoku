import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:sudoku/data/hive_boxes.dart';
import 'package:sudoku/providers/theme_provider.dart';

void main() {
  test('the first-run flag is written once and read back', () async {
    final dir = await Directory.systemTemp.createTemp('sudoku_theme_test');
    Hive.init(dir.path);
    await Hive.openBox<String>(settingsBox);

    final first = ProviderContainer();
    expect(first.read(themeOnboardingSeenProvider), isFalse);

    await first.read(themeOnboardingSeenProvider.notifier).markSeen();
    expect(first.read(themeOnboardingSeenProvider), isTrue);

    // A fresh container, as after a restart.
    final second = ProviderContainer();
    expect(second.read(themeOnboardingSeenProvider), isTrue);

    first.dispose();
    second.dispose();
    await Hive.close();
    await dir.delete(recursive: true);
  });
}
