import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sudoku/providers/coach_provider.dart';
import 'package:sudoku/providers/game_notifier.dart';

/// Height the coach bar takes, so the grid can make room for it.
const double kCoachBarHeight = 132;

/// Small panel under the grid that reveals a hint step by step.
class CoachBar extends ConsumerWidget {
  const CoachBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coach = ref.watch(activeCoachProvider);
    if (coach == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final notifier = ref.read(coachProvider.notifier);
    final game = ref.read(gameProvider.notifier);
    final step = coach.step;

    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    final String title;
    final String body;
    String? detail;
    Widget? action;

    if (step == null) {
      title = 'No step found';
      body =
          'Nothing the coach knows works here. This position needs '
          'something like chains.';
      action = FilledButton(
        onPressed: () {
          notifier.close();
          game.hint();
        },
        child: const Text('Reveal a cell'),
      );
    } else {
      title = step.technique;
      switch (coach.stage) {
        case CoachStage.name:
          body = step.headline;
          detail = step.about;
          action = FilledButton(
            onPressed: notifier.next,
            child: const Text('Where?'),
          );
        case CoachStage.area:
          body = step.nudge;
          action = FilledButton(
            onPressed: () {
              game.markHintUsed();
              notifier.next();
            },
            child: const Text('How?'),
          );
        case CoachStage.pattern:
          body = step.explanation;
          action = FilledButton(
            onPressed: () {
              notifier.close();
              game.applyCoachStep(step);
            },
            child: const Text('Apply'),
          );
      }
    }

    return Padding(
      padding: const .symmetric(horizontal: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 520,
          minHeight: kCoachBarHeight,
          maxHeight: kCoachBarHeight,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: .circular(6),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 8),
            child: Column(
              crossAxisAlignment: .start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: .bold,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    _StageDots(stage: step == null ? null : coach.stage),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Close',
                      onPressed: notifier.close,
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
                Expanded(
                  child: Padding(
                    padding: const .only(right: 8),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: .start,
                        spacing: 4,
                        children: [
                          Text(body, style: theme.textTheme.bodyMedium),
                          if (detail != null) Text(detail, style: muted),
                        ],
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const .only(top: 4, right: 4),
                    child: action,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StageDots extends StatelessWidget {
  const _StageDots({required this.stage});

  final CoachStage? stage;

  @override
  Widget build(BuildContext context) {
    final current = stage;
    if (current == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: .min,
      spacing: 4,
      children: [
        for (final s in CoachStage.values)
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: s.index <= current.index
                  ? scheme.primary
                  : scheme.outlineVariant,
            ),
          ),
      ],
    );
  }
}
