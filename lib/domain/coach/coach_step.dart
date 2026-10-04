import 'package:flutter/foundation.dart';

/// One logical step the coach can explain, revealed in stages.
///
/// Stage 1 names the technique, stage 2 points at the area ([focusCells]),
/// stage 3 shows the pattern and what it removes, stage 4 applies it.
@immutable
class CoachStep {
  const CoachStep({
    required this.headline,
    required this.technique,
    required this.about,
    required this.nudge,
    required this.explanation,
    this.focusCells = const {},
    this.patternCells = const {},
    this.patternDigits = const {},
    this.eliminations = const {},
    this.placement,
    this.erase,
    this.restoreNotes = const {},
  });

  /// Stage 1 text, e.g. "Look for a Skyscraper."
  final String headline;

  /// Short technique name, e.g. "Skyscraper".
  final String technique;

  /// What the technique is in general, independent of this board.
  final String about;

  /// Stage 2 text: where to look, without giving the answer away.
  final String nudge;

  /// Stage 3 text: the full reasoning for this board.
  final String explanation;

  /// Houses to tint at stage 2.
  final Set<int> focusCells;

  /// Cells that form the pattern, outlined at stage 3.
  final Set<int> patternCells;

  /// Digits that matter inside the pattern cells.
  final Set<int> patternDigits;

  /// Candidates this step removes: cell -> digits.
  final Map<int, Set<int>> eliminations;

  /// Digit this step places, if any.
  final ({int cell, int digit})? placement;

  /// Cell whose (wrong) value should be erased.
  final int? erase;

  /// Cells whose notes should be reset to all possible candidates.
  final Set<int> restoreNotes;

  bool get isMistake => erase != null || restoreNotes.isNotEmpty;

  /// Every cell that is part of the explanation at stage 3.
  Set<int> get involvedCells => {
    ...patternCells,
    ...eliminations.keys,
    ?placement?.cell,
    ?erase,
    ...restoreNotes,
  };
}

/// Readable cell name, e.g. R3C5.
String cellName(int index) => 'R${index ~/ 9 + 1}C${index % 9 + 1}';

String cellList(Iterable<int> cells) {
  final sorted = cells.toList()..sort();
  return _joinWords(sorted.map(cellName).toList());
}

String digitList(Iterable<int> digits) {
  final sorted = digits.toList()..sort();
  return _joinWords(sorted.map((d) => '$d').toList());
}

String _joinWords(List<String> parts) {
  if (parts.isEmpty) return '';
  if (parts.length == 1) return parts.first;
  return '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
}
