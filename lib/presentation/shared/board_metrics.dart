import 'package:material_ui/material_ui.dart';

/// The size of the board, worked out in one place from the space it has.
///
/// Every caller used to re-derive this from its own constants: the game screen
/// through `GridWidget`, the settings preview from the window width. Keeping the
/// budget, the clamps and the landscape fallback here means the two agree by
/// construction rather than by coincidence.
final class BoardMetrics {
  const new({required this.gridSize});

  final double gridSize;

  /// Vertical space the app bar and the controls below the board need.
  static const double chromeBudget = 220;

  /// Space the board and the screen edges share.
  static const double gutter = 16;

  /// Used when the screen has no app bar to measure.
  static const double appBarFallback = 56;

  /// Below this height in landscape, the width is the better guide.
  static const double landscapeFloor = 200;

  static const double minGridSize = 140;
  static const double maxGridSize = 520;

  factory of(BuildContext context, {double reservedHeight = 0}) => compute(
    size: MediaQuery.sizeOf(context),
    portrait: MediaQuery.orientationOf(context) == .portrait,
    appBarHeight: Scaffold.of(context).appBarMaxHeight ?? appBarFallback,
    reservedHeight: reservedHeight,
  );

  /// Width only, for a surface that draws the board without the game chrome.
  factory byWidth(BuildContext context) =>
      compute(size: MediaQuery.sizeOf(context), portrait: false);

  /// The rule itself, free of context so it can be tested.
  static BoardMetrics compute({
    required Size size,
    required bool portrait,
    double appBarHeight = appBarFallback,
    double reservedHeight = 0,
  }) {
    final availableHeight =
        size.height - appBarHeight - chromeBudget - reservedHeight;
    // In portrait the column has to fit whatever height is left, so a short
    // screen shrinks the board instead of taking the full width and pushing the
    // controls off the bottom. Landscape keeps the width fallback.
    final widthBound = size.width - gutter;
    final maxGrid = portrait
        ? availableHeight.clamp(minGridSize, widthBound)
        : availableHeight > landscapeFloor
        ? availableHeight
        : widthBound;
    return BoardMetrics(gridSize: maxGrid.clamp(0.0, maxGridSize));
  }
}
