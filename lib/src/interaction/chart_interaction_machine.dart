import '../viewport/viewport.dart';
import 'chart_interaction_intent.dart';

enum ChartInteractionMode {
  idle,
  panning,
  scaling,
  crosshair,
}

/// Per-chart state machine that converts accepted gesture callbacks to intents.
///
/// Gesture recognizers remain responsible for Gesture Arena participation.
/// Conflicting begin calls are rejected and never preempt an active mode.
final class ChartInteractionMachine {
  ChartInteractionMode _mode = ChartInteractionMode.idle;
  ChartViewport? _currentViewport;
  ChartViewport? _scaleStartViewport;
  double? _scaleAnchorDataPosition;

  ChartInteractionMode get mode => _mode;
  bool get isIdle => _mode == ChartInteractionMode.idle;

  bool beginPan(ChartViewport viewport) {
    if (!isIdle) {
      return false;
    }
    _mode = ChartInteractionMode.panning;
    _currentViewport = viewport;
    return true;
  }

  ChartViewportIntent? updatePan(double deltaLocalX) {
    _requireFinite(deltaLocalX, 'deltaLocalX');
    if (_mode != ChartInteractionMode.panning) {
      return null;
    }
    final current = _currentViewport!;
    final next = current.scrollByItems(deltaLocalX / current.itemExtent);
    _currentViewport = next;
    return next == current ? null : ChartViewportIntent(next);
  }

  bool endPan() => _finish(ChartInteractionMode.panning);

  bool cancelPan() => _finish(ChartInteractionMode.panning);

  bool beginScale({
    required ChartViewport viewport,
    required double focalLocalX,
  }) {
    _requireFinite(focalLocalX, 'focalLocalX');
    if (!isIdle) {
      return false;
    }
    _mode = ChartInteractionMode.scaling;
    _currentViewport = viewport;
    _scaleStartViewport = viewport;
    _scaleAnchorDataPosition =
        viewport.visibleLeftDataPosition + focalLocalX / viewport.itemExtent;
    return true;
  }

  ChartViewportIntent? updateScale({
    required double scale,
    required double focalLocalX,
  }) {
    _requireFinite(scale, 'scale');
    _requireFinite(focalLocalX, 'focalLocalX');
    if (scale <= 0) {
      throw ArgumentError.value(scale, 'scale', 'Must be positive.');
    }
    if (_mode != ChartInteractionMode.scaling) {
      return null;
    }

    final start = _scaleStartViewport!;
    final nextExtent = start.itemExtent * scale;
    final extentAdjusted = start.zoomTo(nextExtent);
    final anchor = _scaleAnchorDataPosition!;
    final desiredLeft = anchor - focalLocalX / extentAdjusted.itemExtent;
    final desiredRight =
        desiredLeft + extentAdjusted.width / extentAdjusted.itemExtent;
    final desiredScroll = extentAdjusted.itemCount +
        extentAdjusted.trailingPaddingItems -
        desiredRight;
    final next = extentAdjusted.copyWith(scrollOffsetItems: desiredScroll);
    final current = _currentViewport!;
    _currentViewport = next;
    return next == current ? null : ChartViewportIntent(next);
  }

  bool endScale() => _finish(ChartInteractionMode.scaling);

  bool cancelScale() => _finish(ChartInteractionMode.scaling);

  ChartCrosshairIntent? beginCrosshair({
    required double localX,
    required double localY,
  }) {
    _validatePoint(localX, localY);
    if (!isIdle) {
      return null;
    }
    _mode = ChartInteractionMode.crosshair;
    return ChartCrosshairIntent.show(localX: localX, localY: localY);
  }

  ChartCrosshairIntent? updateCrosshair({
    required double localX,
    required double localY,
  }) {
    _validatePoint(localX, localY);
    if (_mode != ChartInteractionMode.crosshair) {
      return null;
    }
    return ChartCrosshairIntent.show(localX: localX, localY: localY);
  }

  ChartCrosshairIntent? endCrosshair() {
    if (!_finish(ChartInteractionMode.crosshair)) {
      return null;
    }
    return const ChartCrosshairIntent.hide();
  }

  ChartCrosshairIntent? cancelCrosshair() => endCrosshair();

  /// Cancels the active winner. Arena rejection must never start another mode.
  ChartInteractionIntent? cancelActive() {
    if (_mode == ChartInteractionMode.crosshair) {
      return endCrosshair();
    }
    if (isIdle) {
      return null;
    }
    _reset();
    return null;
  }

  bool _finish(ChartInteractionMode expected) {
    if (_mode != expected) {
      return false;
    }
    _reset();
    return true;
  }

  void _reset() {
    _mode = ChartInteractionMode.idle;
    _currentViewport = null;
    _scaleStartViewport = null;
    _scaleAnchorDataPosition = null;
  }
}

void _validatePoint(double localX, double localY) {
  _requireFinite(localX, 'localX');
  _requireFinite(localY, 'localY');
}

void _requireFinite(double value, String name) {
  if (!value.isFinite) {
    throw ArgumentError.value(value, name, 'Must be finite.');
  }
}
