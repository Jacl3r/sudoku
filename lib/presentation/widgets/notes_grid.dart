import 'package:material_ui/material_ui.dart';

TextStyle _noteStyle(
  ColorScheme scheme,
  int digit, {
  required double fontSize,
  required Color color,
  required Set<int> mark,
  required Set<int> strike,
}) {
  if (strike.contains(digit)) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: .w700,
      height: 1,
      color: scheme.error,
      decoration: TextDecoration.lineThrough,
      decorationColor: scheme.error,
    );
  }
  if (mark.contains(digit)) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: .w800,
      height: 1,
      color: scheme.primary,
    );
  }
  return TextStyle(
    fontSize: fontSize,
    fontWeight: .w500,
    height: 1,
    color: color,
  );
}

class NotesGrid extends StatelessWidget {
  const NotesGrid({
    required this.notes,
    required this.cellSize,
    super.key,
    this.hasNoteOfSameDigit = false,
    this.mark = const {},
    this.strike = const {},
  });

  final Set<int> notes;
  final double cellSize;
  final bool hasNoteOfSameDigit;
  final Set<int> mark;
  final Set<int> strike;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final color = hasNoteOfSameDigit ? scheme.surface : scheme.onSurface;
    final fontSize = cellSize * 0.2;
    final digits = notes.toList()..sort();
    final (top, middle, bottom) = _splitRows(digits);

    TextStyle style(int d) => _noteStyle(
      scheme,
      d,
      fontSize: fontSize,
      color: color,
      mark: mark,
      strike: strike,
    );

    return Column(
      mainAxisAlignment: .spaceAround,
      children: [
        _NotesRow(digits: top, style: style),
        _NotesRow(digits: middle, style: style),
        _NotesRow(digits: bottom, style: style),
      ],
    );
  }

  (List<int>, List<int>, List<int>) _splitRows(List<int> digits) {
    final n = digits.length;
    final (topCount, middleCount) = switch (n) {
      <= 2 => (0, 0),
      3 => (0, 1),
      4 => (0, 2),
      5 => (0, 3),
      6 => (0, 4),
      7 => (1, 4),
      _ => (n - 6, 4),
    };

    final top = digits.sublist(0, topCount);
    final middle = digits.sublist(topCount, topCount + middleCount);
    final bottom = digits.sublist(topCount + middleCount);

    return (top, middle, bottom);
  }
}

class _NotesRow extends StatelessWidget {
  const _NotesRow({required this.digits, required this.style});

  final List<int> digits;
  final TextStyle Function(int digit) style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: .min,
      mainAxisAlignment: .center,
      children: [
        for (final digit in digits)
          Padding(
            padding: const .symmetric(horizontal: 1),
            child: Text('$digit', style: style(digit)),
          ),
      ],
    );
  }
}

class FixedNotesGrid extends StatelessWidget {
  const FixedNotesGrid({
    required this.notes,
    required this.cellSize,
    super.key,
    this.hasNoteOfSameDigit = false,
    this.mark = const {},
    this.strike = const {},
  });

  final Set<int> notes;
  final double cellSize;
  final bool hasNoteOfSameDigit;
  final Set<int> mark;
  final Set<int> strike;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) {
      return const SizedBox.shrink();
    }

    final cs = Theme.of(context).colorScheme;
    final color = hasNoteOfSameDigit ? cs.surface : cs.onSurface;
    final fontSize = cellSize * 0.22;

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: .zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
      ),
      itemCount: 9,
      itemBuilder: (context, index) {
        final digit = index + 1;
        final hasDigit = notes.contains(digit);

        return Center(
          child: hasDigit
              ? Text(
                  '$digit',
                  style: _noteStyle(
                    cs,
                    digit,
                    fontSize: fontSize,
                    color: color,
                    mark: mark,
                    strike: strike,
                  ),
                )
              : const SizedBox.shrink(),
        );
      },
    );
  }
}
