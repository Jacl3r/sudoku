import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sudoku/domain/models/game_state.dart';
import 'package:sudoku/presentation/models/board_intent.dart';
import 'package:sudoku/presentation/shared/board_intent_actions.dart';
import 'package:sudoku/presentation/shared/utils.dart';
import 'package:sudoku/presentation/widgets/action_row.dart';
import 'package:sudoku/presentation/widgets/coach_bar.dart';
import 'package:sudoku/presentation/widgets/digit_pad.dart';
import 'package:sudoku/presentation/widgets/export_sheet.dart';
import 'package:sudoku/presentation/widgets/game_layout.dart';
import 'package:sudoku/presentation/widgets/grid_widget.dart';
import 'package:sudoku/presentation/widgets/solved_overlay.dart';
import 'package:sudoku/presentation/widgets/theme_selector.dart';
import 'package:sudoku/providers/board_notifier.dart';
import 'package:sudoku/providers/coach_provider.dart';
import 'package:sudoku/providers/game_notifier.dart';
import 'package:sudoku/providers/services_provider.dart';
import 'package:sudoku/providers/settings_provider.dart';
import 'package:sudoku/providers/stats_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class GameScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameAsync = ref.watch(gameProvider);
    final gameNotifier = ref.watch(gameProvider.notifier);
    final showTimer = ref.watch(settingsProvider.select((s) => s.showTimer));
    final game = gameAsync.value;

    final board = ref.watch(boardProvider);
    final boardNotifier = ref.read(boardProvider.notifier);

    return Scaffold(
      body: SafeArea(
        child: Stack(
          fit: .expand,
          children: [
            gameAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (game) {
                if (game == null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: .center,
                      children: [
                        const Text('No active game'),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text('Start New Game'),
                        ),
                      ],
                    ),
                  );
                }

                return Focus(
                  autofocus: true,
                  onKeyEvent: (node, event) {
                    if (event is! KeyDownEvent) return .ignored;
                    final key = event.logicalKey;

                    // Leave modifier combinations to the host, except undo.
                    final modifier =
                        HardwareKeyboard.instance.isMetaPressed ||
                        HardwareKeyboard.instance.isControlPressed;
                    if (modifier) {
                      if (key == LogicalKeyboardKey.keyZ &&
                          !game.puzzleComplete) {
                        gameNotifier.undo();
                        return .handled;
                      }
                      return .ignored;
                    }

                    // Board inputs resolve in one place; anything else falls
                    // through to the app actions below.
                    final intent = intentForKey(
                      key: key,
                      board: board,
                      puzzleComplete: game.puzzleComplete,
                    );
                    if (intent != null) {
                      applyBoardIntent(ref, intent);
                      return .handled;
                    }

                    // Navigation stays live, every action below goes quiet once
                    // the puzzle is solved.
                    if (game.puzzleComplete) return .ignored;

                    switch (key) {
                      case .keyU:
                        gameNotifier.undo();
                        return .handled;
                      case .keyH:
                        showHintSheet(context, ref, gameNotifier);
                        return .handled;
                      case .keyR:
                        confirmReset(context, gameNotifier, boardNotifier);
                        return .handled;
                      case .keyE:
                        showExportSheet(context, game);
                        return .handled;
                      default:
                    }

                    return .ignored;
                  },
                  child: _GameBody(state: game),
                );
              },
            ),
            Align(
              alignment: .topCenter,
              child: Padding(
                padding: const .all(6),
                child: Row(
                  mainAxisAlignment: .spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.chevron_left),
                    ),
                    if (showTimer && game != null && !game.puzzleComplete)
                      Text(
                        formatTime(game.elapsed),
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    Row(
                      mainAxisSize: .min,
                      children: [
                        if (game != null)
                          IconButton(
                            tooltip: shortcutHint('Export', 'E'),
                            onPressed: () {
                              final current = ref.read(gameProvider).value;
                              if (current != null) {
                                showExportSheet(context, current);
                              }
                            },
                            icon: const Icon(Icons.ios_share_rounded),
                          ),
                        const ThemeSelector(),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameBody extends ConsumerStatefulWidget {
  const new({required this.state});
  final GameState state;

  @override
  ConsumerState<_GameBody> createState() => _GameBodyState();
}

class _GameBodyState extends ConsumerState<_GameBody>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == .paused || state == .detached || state == .hidden) {
      final current = ref.read(gameProvider).value;
      if (current != null) {
        final key = ref.read(activeSaveKeyProvider) ?? current.difficulty.name;
        ref.read(saveGameServiceProvider).save(current, key: key);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(isFinishedProvider, (_, next) {
      if (next) {
        final record = ref.read(lastCompletionRecordProvider);
        if (record != null) {
          showSolvedOverlay(context, ref, record);
        }
        ref.read(boardProvider.notifier).reset();
        ref.read(coachProvider.notifier).close();
      }
    });

    final coachActive = ref.watch(activeCoachProvider) != null;
    final isPortrait = MediaQuery.orientationOf(context) == .portrait;

    final grid = GridWidget(
      gameState: widget.state,
      reservedHeight: coachActive && isPortrait
          ? coachBarHeight(context) + 16
          : 0,
    );
    const action = ActionRow();
    final digits = DigitPad(state: widget.state);

    return GameLayout(
      grid: grid,
      digitPad: digits,
      actionRow: action,
      coachBar: coachActive ? const CoachBar() : null,
    );
  }
}
