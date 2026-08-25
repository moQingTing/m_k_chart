import '../viewport/viewport.dart';

sealed class ChartInteractionIntent {
  const ChartInteractionIntent();
}

/// Immutable crosshair payload stored in the selection state slice.
final class ChartCrosshairState {
  const ChartCrosshairState.visible({
    required this.localX,
    required this.localY,
  }) : isVisible = true;

  const ChartCrosshairState.hidden()
      : isVisible = false,
        localX = 0,
        localY = 0;

  final bool isVisible;
  final double localX;
  final double localY;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChartCrosshairState &&
          isVisible == other.isVisible &&
          localX == other.localX &&
          localY == other.localY;

  @override
  int get hashCode => Object.hash(isVisible, localX, localY);
}

/// Requests one immutable Viewport replacement.
final class ChartViewportIntent extends ChartInteractionIntent {
  const ChartViewportIntent(this.viewport);

  final ChartViewport viewport;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChartViewportIntent && viewport == other.viewport;

  @override
  int get hashCode => viewport.hashCode;
}

/// Shows, moves, or hides a crosshair in chart-local coordinates.
final class ChartCrosshairIntent extends ChartInteractionIntent {
  const ChartCrosshairIntent.show({
    required this.localX,
    required this.localY,
  }) : isActive = true;

  const ChartCrosshairIntent.hide()
      : isActive = false,
        localX = 0,
        localY = 0;

  final bool isActive;
  final double localX;
  final double localY;

  ChartCrosshairState get state => isActive
      ? ChartCrosshairState.visible(localX: localX, localY: localY)
      : const ChartCrosshairState.hidden();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChartCrosshairIntent &&
          isActive == other.isActive &&
          localX == other.localX &&
          localY == other.localY;

  @override
  int get hashCode => Object.hash(isActive, localX, localY);
}
