/// Every technique the coach can show: the name it goes by and what one step
/// of it costs.
///
/// The scores follow HoDoKu's defaults. Added up over a whole puzzle they say
/// how much work it is, not only which technique is the hardest one in it.
enum CoachTechnique {
  nakedSingle('Naked Single', 4),
  hiddenSingle('Hidden Single', 14),
  pointingPair('Pointing Pair', 50),
  pointingTriple('Pointing Triple', 50),
  boxLineReduction('Box/Line Reduction', 50),
  nakedPair('Naked Pair', 60),
  hiddenPair('Hidden Pair', 70),
  nakedTriple('Naked Triple', 80),
  hiddenTriple('Hidden Triple', 100),
  nakedQuad('Naked Quad', 120),
  skyscraper('Skyscraper', 130),
  xWing('X-Wing', 140),
  hiddenQuad('Hidden Quad', 150),
  simpleColoring('Simple Coloring', 150),
  swordfish('Swordfish', 150),
  twoStringKite('Two-String Kite', 150),
  jellyfish('Jellyfish', 160),
  xyWing('XY-Wing', 160),
  xyzWing('XYZ-Wing', 180);

  final String label;
  final int score;

  new(this.label, this.score);
}
