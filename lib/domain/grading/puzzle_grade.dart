import 'package:sudoku/domain/coach/coach_walk.dart';
import 'package:sudoku/domain/engine/solver.dart';
import 'package:sudoku/domain/engine/techniques/techniques.dart';
import 'package:sudoku/domain/models/difficulty.dart';
import 'package:sudoku/domain/models/puzzle.dart';
import 'package:sudoku/domain/models/solver_result.dart';

/// Grades a puzzle. This is the one place that knows what makes a puzzle Easy,
/// Medium, Hard or Expert, so the generator and the import cannot disagree.
PuzzleGrade gradePuzzle(Puzzle puzzle) => PuzzleGrade._(puzzle);

/// How hard a puzzle is.
///
/// The solver runs when the grade is made. The coach only walks the puzzle
/// when a question needs it, because most puzzles the generator digs fail on
/// the solver's verdict alone.
class PuzzleGrade {
  new _(this._puzzle) : _solved = solveLogically(_puzzle.given);

  final Puzzle _puzzle;
  final SolverResult _solved;

  late final CoachWalk _walk = walkWithCoach(_puzzle);

  /// How many singles are open before the first move. A puzzle with few of
  /// them starts slowly.
  late final int _openingSingles =
      NakedSingle().getHints(_puzzle.given).length +
      HiddenSingle().getHints(_puzzle.given).length;

  /// What the app calls this puzzle: the level of the hardest technique the
  /// solver needed. A puzzle the solver could not finish without guessing is
  /// Expert, whatever it managed before it got stuck.
  Difficulty get difficulty => _solved.bruteForceUsed
      ? Difficulty.expert
      : _solved.highestDifficultyLevel;

  /// Whether the coach can walk the puzzle from the givens to the end.
  bool get coachable => _walk.finished;

  /// The work in the coach's walk, or null when the coach cannot finish it.
  int? get score => _walk.finished ? _walk.score : null;

  /// Whether this puzzle is a good one to hand out as [target]: the right
  /// level, an opening that suits it, and below Expert a walk the coach can
  /// finish with a score inside the band for that level.
  bool fits(Difficulty target) {
    if (!fitsLoosely(target)) return false;
    if (target == Difficulty.expert) return true;
    return _walk.finished && _scoreFits(target, _walk.score);
  }

  /// The original app's rule alone: the right level and opening, without
  /// asking the coach. The generator falls back to this when [fits] keeps
  /// failing, so a gap in the coach cannot make it search forever.
  bool fitsLoosely(Difficulty target) {
    if (_solved.bruteForceUsed) return target == Difficulty.expert;

    final level = _solved.highestDifficultyLevel;
    return switch (target) {
      Difficulty.easy => level == Difficulty.easy,
      Difficulty.medium => level == Difficulty.medium,
      Difficulty.hard => level == Difficulty.hard && _openingSingles <= 3,
      Difficulty.expert =>
        (level == Difficulty.expert || level == Difficulty.hard) &&
            _openingSingles <= 2,
    };
  }
}

/// The score band for each level.
///
/// The bands come from 150 generated puzzles per level. Easy sits at about
/// 630 by itself. Medium below 780 is a single locked-candidates step on top
/// of singles, and Hard below 1100 is a single advanced step on top of
/// singles, so both floors ask for a little more than that. The ceilings cut
/// the long grind at the top. Expert is not held to a score, because the coach
/// often cannot walk it at all.
bool _scoreFits(Difficulty target, int score) => switch (target) {
  Difficulty.easy => true,
  Difficulty.medium => score >= 780 && score <= 1000,
  Difficulty.hard => score >= 1100 && score <= 1600,
  Difficulty.expert => true,
};
