import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sudoku/providers/game_notifier.dart';

final isBackgroundProvider = NotifierProvider<IsBackgroundNotifier, bool>(
  IsBackgroundNotifier.new,
  name: 'isBackgroundProvider',
);

class IsBackgroundNotifier extends Notifier<bool> with WidgetsBindingObserver {
  @override
  bool build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() => WidgetsBinding.instance.removeObserver(this));
    return false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    this.state = state == .paused || state == .hidden;
  }
}

final pauseTimerProvider = Provider<void>((ref) {
  ref.listen(isBackgroundProvider, (_, isBackground) {
    final notifier = ref.read(gameProvider.notifier);
    if (isBackground) {
      notifier.pauseTimer();
    } else {
      notifier.startTimer();
    }
  });
});
