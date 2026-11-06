import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sudoku/presentation/shared/board_metrics.dart';

void main() {
  group('BoardMetrics', () {
    test('a tall portrait phone is bounded by its width', () {
      final metrics = BoardMetrics.compute(
        size: const Size(390, 844),
        portrait: true,
      );
      // 390 - 16 is tighter than the 568 of height left, so width wins.
      expect(metrics.gridSize, 374);
    });

    test('a short portrait screen shrinks instead of overflowing', () {
      final metrics = BoardMetrics.compute(
        size: const Size(360, 640),
        portrait: true,
      );
      // 640 - 56 - 220 = 364 of height left, but 360 - 16 = 344 of width is
      // tighter, so the board shrinks to the width.
      expect(metrics.gridSize, 344);
    });

    test('reserving room for the coach bar shrinks the board', () {
      // A wide window whose height stays under the 520 cap, so the reserved
      // space is felt in full.
      final plain = BoardMetrics.compute(
        size: const Size(800, 760),
        portrait: true,
      );
      final reserved = BoardMetrics.compute(
        size: const Size(800, 760),
        portrait: true,
        reservedHeight: 148,
      );
      expect(plain.gridSize - reserved.gridSize, 148);
    });

    test('portrait never goes below the minimum', () {
      final metrics = BoardMetrics.compute(
        size: const Size(360, 300),
        portrait: true,
      );
      expect(metrics.gridSize, BoardMetrics.minGridSize);
    });

    test('landscape falls back to the width on a short screen', () {
      final metrics = BoardMetrics.compute(
        size: const Size(800, 360),
        portrait: false,
      );
      // Only 84 of height: too short to guide, so the width is used and then
      // capped at the maximum.
      expect(metrics.gridSize, BoardMetrics.maxGridSize);
    });

    test('landscape uses the height when there is room', () {
      final metrics = BoardMetrics.compute(
        size: const Size(800, 700),
        portrait: false,
      );
      expect(metrics.gridSize, 424);
    });

    test('the width bound applies below the maximum', () {
      final metrics = BoardMetrics.compute(
        size: const Size(320, 844),
        portrait: true,
      );
      expect(metrics.gridSize, 304);
    });
  });
}
