import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sudoku/domain/models/difficulty.dart';
import 'package:sudoku/providers/difficulty_provider.dart';

/// The page the home carousel is on: a difficulty index, or
/// `Difficulty.values.length` for the Imported page.
final homePageProvider = NotifierProvider<HomePageNotifier, int>(
  HomePageNotifier.new,
  name: 'homePageProvider',
);

class HomePageNotifier extends Notifier<int> {
  @override
  int build() => ref.watch(difficultyProvider).index;

  void select(int page) {
    if (page < Difficulty.values.length) {
      ref.read(difficultyProvider.notifier).set(Difficulty.values[page]);
    }
    // Also set it explicitly: selecting the current difficulty again would not
    // rebuild this provider, and the Imported page has no difficulty to write.
    state = page;
  }
}
