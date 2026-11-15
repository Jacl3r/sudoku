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
