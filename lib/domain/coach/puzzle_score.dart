import 'package:sudoku/domain/models/difficulty.dart';

/// What one coach step costs, by technique name. The numbers follow HoDoKu's
/// defaults, so a puzzle's total says how much work it is, not only which
/// technique is the hardest one in it.
const techniqueScores = <String, int>{
  'Naked Single': 4,
  'Hidden Single': 14,
  'Pointing Pair': 50,
  'Pointing Triple': 50,
  'Box/Line Reduction': 50,
  'Naked Pair': 60,
  'Hidden Pair': 70,
  'Naked Triple': 80,
  'Hidden Triple': 100,
  'Naked Quad': 120,
  'Skyscraper': 130,
  'X-Wing': 140,
  'Hidden Quad': 150,
  'Simple Coloring': 150,
  'Swordfish': 150,
  'Two-String Kite': 150,
  'Jellyfish': 160,
  'XY-Wing': 160,
  'XYZ-Wing': 180,
};

/// Charged for a technique that has no entry in [techniqueScores] yet, so a
/// new detector still counts as work until it gets a score of its own.
const unknownTechniqueScore = 100;

int techniqueScore(String technique) =>
    techniqueScores[technique] ?? unknownTechniqueScore;

/// The range a puzzle's coach score has to fall in.
class ScoreBand {
  const new(this.min, this.max);

  final int min;
  final int max;

  bool contains(int score) => score >= min && score <= max;
}

/// The score a generated puzzle must have for its difficulty, or null when the
/// difficulty has no band.
///
/// The bands come from 150 generated puzzles per difficulty. Easy sits at
/// about 630 by itself. Medium below 780 is a single locked-candidates step on
/// top of singles, and Hard below 1100 is a single advanced step on top of
/// singles, so both floors ask for a little more than that. The ceilings cut
/// the long grind at the top. Expert often cannot be walked at all, so it has
/// no score to judge.
ScoreBand? scoreBandFor(Difficulty difficulty) => switch (difficulty) {
  Difficulty.easy => null,
  Difficulty.medium => const ScoreBand(780, 1000),
  Difficulty.hard => const ScoreBand(1100, 1600),
  Difficulty.expert => null,
};
