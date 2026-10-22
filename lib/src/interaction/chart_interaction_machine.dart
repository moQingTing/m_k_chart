import '../viewport/viewport.dart';
import 'chart_interaction_intent.dart';

enum ChartInteractionMode {
  idle,
  panning,
  scaling,
  crosshair,
}

/// 将已获手势竞技场认可的回调转换为意图的单图表状态机。
///
/// 手势识别器仍负责参与 Flutter Gesture Arena；冲突的开始调用会被拒绝，绝不抢占当前模式。
/// 宿主只需将返回的意图归约进状态，无需在 Widget 中复制拖动、缩放和十字线的状态机逻辑。
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
    return next == current
        ? null
        : ChartViewportIntent(next, source: ChartViewportChangeSource.pan);
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
    // 记录手指下的“数据坐标”而非像素，缩放后可让焦点仍指向同一根 K 线。
    _scaleAnchorDataPosition =
        viewport.visibleLeftDataPosition + focalLocalX / viewport.itemExtent;
    return true;
  }

  ChartViewportIntent? updateScale({
    required double scale,
    required double focalLocalX,
    ChartViewportChangeSource source = ChartViewportChangeSource.scale,
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
    // 根据新的槽位宽度反推左边缘，随后由 Viewport 统一夹取滚动边界。
    final desiredLeft = anchor - focalLocalX / extentAdjusted.itemExtent;
    final desiredRight =
        desiredLeft + extentAdjusted.width / extentAdjusted.itemExtent;
    final desiredScroll = extentAdjusted.itemCount +
        extentAdjusted.trailingPaddingItems -
        desiredRight;
    final next = extentAdjusted.copyWith(scrollOffsetItems: desiredScroll);
    final current = _currentViewport!;
    _currentViewport = next;
    return next == current ? null : ChartViewportIntent(next, source: source);
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

  /// 取消当前获胜者；竞技场拒绝不能启动其他模式。
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
