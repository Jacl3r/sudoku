import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sudoku/domain/models/difficulty.dart';
import 'package:sudoku/presentation/screens/game_screen.dart';
import 'package:sudoku/presentation/screens/imported_puzzles_screen.dart';
import 'package:sudoku/presentation/screens/settings_screen.dart';
import 'package:sudoku/presentation/screens/stats_screen.dart';
import 'package:sudoku/presentation/shared/utils.dart';
import 'package:sudoku/presentation/widgets/theme_onboarding_sheet.dart';
import 'package:sudoku/providers/difficulty_provider.dart';
import 'package:sudoku/providers/game_notifier.dart';
import 'package:sudoku/providers/home_page_provider.dart';
import 'package:sudoku/providers/services_provider.dart';
import 'package:sudoku/providers/theme_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowThemeSheet());
  }

  void _maybeShowThemeSheet() {
    if (!mounted) return;
    if (ref.read(themeOnboardingSeenProvider)) return;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const ThemeOnboardingSheet(),
    ).whenComplete(() {
      if (!mounted) return;
      ref.read(themeOnboardingSeenProvider.notifier).markSeen();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final continueGameMap = ref.watch(continueGameProvider);
    final imports = ref.watch(importedGamesProvider);
    final resumable = ref.watch(resumableGameProvider);
    final page = ref.watch(homePageProvider);

    final onImportedPage = page >= Difficulty.values.length;
    final pageDifficulty = onImportedPage ? null : Difficulty.values[page];
    final hasSave =
        pageDifficulty != null && continueGameMap[pageDifficulty] != null;

    void openGame(String key, Difficulty difficulty) {
      ref.read(difficultyProvider.notifier).set(difficulty);
      ref.read(activeSaveKeyProvider.notifier).set(key);
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const GameScreen()),
      );
    }

    Future<void> newGame(Difficulty difficulty) async {
      await ref.read(saveGameServiceProvider).delete(difficulty);
      openGame(difficulty.name, difficulty);
    }

    void openImports() {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const ImportedPuzzlesScreen()),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Stack(
          fit: .expand,
          children: [
            Center(
              child: Padding(
                padding: const .all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisAlignment: .center,
                    children: [
                      DecoratedBox(
                        decoration: const BoxDecoration(
                          borderRadius: .all(.circular(6)),
                        ),
                        child: Image.asset(
                          'assets/icons/icon.png',
                          width: 160,
                          height: 160,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      SizedBox(height: resumable == null ? 32 : 20),
                      if (resumable != null) ...[
                        SizedBox(
                          width: double.infinity,
                          child: _ResumeCard(
                            game: resumable,
                            onTap: () => openGame(
                              resumable.key,
                              resumable.state.difficulty,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      const _DifficultyCarousel(),
                      const SizedBox(height: 12),
                      if (onImportedPage)
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: openImports,
                            child: Text(
                              imports.isEmpty
                                  ? 'Import a puzzle'
                                  : 'Open library',
                            ),
                          ),
                        )
                      else if (hasSave) ...[
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () => openGame(
                              pageDifficulty.name,
                              pageDifficulty,
                            ),
                            child: const Text('Continue'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => newGame(pageDifficulty),
                            child: const Text('New game'),
                          ),
                        ),
                      ] else
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () => newGame(pageDifficulty!),
                            child: const Text('New game'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Align(
              alignment: .topRight,
              child: Row(
                mainAxisSize: .min,
                children: [
                  IconButton(
                    tooltip: 'Stats',
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const StatsScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.bar_chart_outlined),
                  ),
                  IconButton(
                    tooltip: 'Settings',
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.settings_outlined),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Five swipeable pages — the four difficulties and the import library — with
/// chevrons and pips, both kept in step with [homePageProvider].
class _DifficultyCarousel extends ConsumerStatefulWidget {
  const _DifficultyCarousel();

  @override
  ConsumerState<_DifficultyCarousel> createState() =>
      _DifficultyCarouselState();
}

class _DifficultyCarouselState extends ConsumerState<_DifficultyCarousel> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: ref.read(homePageProvider));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(homePageProvider);
    final imports = ref.watch(importedGamesProvider);
    final scheme = Theme.of(context).colorScheme;
    final pageCount = Difficulty.values.length + 1;

    // Keep the pager in step when the page changes without a swipe, for example
    // when resuming a game sets the difficulty.
    ref.listen(homePageProvider, (_, next) {
      if (_controller.hasClients && _controller.page?.round() != next) {
        _goTo(next);
      }
    });

    return Column(
      mainAxisSize: .min,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Previous',
              onPressed: page > 0 ? () => _goTo(page - 1) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: SizedBox(
                height: 92,
                child: PageView.builder(
                  controller: _controller,
                  itemCount: pageCount,
                  onPageChanged: (index) =>
                      ref.read(homePageProvider.notifier).select(index),
                  itemBuilder: (context, index) => _PageLabel(
                    title: index < Difficulty.values.length
                        ? Difficulty.values[index].displayName
                        : 'Imported',
                    subtitle: index < Difficulty.values.length
                        ? null
                        : _importCountLabel(imports.length),
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Next',
              onPressed: page < pageCount - 1
                  ? () => _goTo(page + 1)
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: .center,
          spacing: 6,
          children: [
            for (var i = 0; i < pageCount; i++)
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == page ? scheme.primary : scheme.outlineVariant,
                ),
              ),
          ],
        ),
      ],
    );
  }

  static String _importCountLabel(int count) => switch (count) {
    0 => 'No imported puzzles',
    1 => '1 puzzle',
    _ => '$count puzzles',
  };
}

class _PageLabel extends StatelessWidget {
  const _PageLabel({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: .min,
        spacing: 2,
        children: [
          Text(title, style: theme.textTheme.headlineSmall),
          if (subtitle != null)
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

/// One tap back into the game saved most recently.
class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.game, required this.onTap});

  final ResumableGame game;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final filled = game.state.grid.values.where((v) => v != 0).length;

    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        alignment: .centerLeft,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      ),
      child: Column(
        crossAxisAlignment: .start,
        mainAxisSize: .min,
        spacing: 2,
        children: [
          Text(
            'Continue ${game.label}',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: .bold),
          ),
          Text(
            '${formatTime(game.state.elapsed)} · $filled of 81',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
