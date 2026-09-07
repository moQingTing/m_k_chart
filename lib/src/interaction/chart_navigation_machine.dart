import '../model/model.dart';
import '../viewport/viewport.dart';
import 'chart_interaction_intent.dart';

/// 单图表、与帧时钟无关的惯性导航器。
///
/// 宿主传入两帧间的 [Duration]，便可在不同刷新率下获得一致的阻尼效果；返回 null 表示本帧
/// 无需发布新的视口状态。
final class ChartNavigationMachine {
  ChartNavigationMachine({
    this.decelerationLocalXPerSecondSquared = 2400,
    this.minimumVelocityLocalXPerSecond = 40,
  }) {
    _requirePositiveFinite(
      decelerationLocalXPerSecondSquared,
      'decelerationLocalXPerSecondSquared',
    );
    _requireNonNegativeFinite(
      minimumVelocityLocalXPerSecond,
      'minimumVelocityLocalXPerSecond',
    );
  }

  final double decelerationLocalXPerSecondSquared;
  final double minimumVelocityLocalXPerSecond;

  ChartViewport? _viewport;
  double _velocityItemsPerSecond = 0;
  double _decelerationItemsPerSecondSquared = 0;

  bool get isInertiaActive => _viewport != null;

  bool startInertia({
    required ChartViewport viewport,
    required double velocityLocalXPerSecond,
  }) {
    _requireFinite(velocityLocalXPerSecond, 'velocityLocalXPerSecond');
    cancelInertia();
    if (velocityLocalXPerSecond.abs() < minimumVelocityLocalXPerSecond ||
        (viewport.maxScrollOffsetItems == 0 &&
            viewport.minScrollOffsetItems == 0) ||
        (velocityLocalXPerSecond < 0 && viewport.isAtFutureLimit) ||
        (velocityLocalXPerSecond > 0 && viewport.isAtOldest)) {
      return false;
    }
    _viewport = viewport;
    _velocityItemsPerSecond = velocityLocalXPerSecond / viewport.itemExtent;
    _decelerationItemsPerSecondSquared =
        decelerationLocalXPerSecondSquared / viewport.itemExtent;
    return true;
  }

  /// 按帧间隔推进，而不是依赖绝对墙上时间。
  ChartViewportIntent? advanceInertia(Duration elapsed) {
    if (elapsed.isNegative) {
      throw ArgumentError.value(elapsed, 'elapsed', 'Must not be negative.');
    }
    final current = _viewport;
    if (current == null || elapsed == Duration.zero) {
      return null;
    }
    final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final speed = _velocityItemsPerSecond.abs();
    final direction = _velocityItemsPerSecond.sign;
    final timeUntilStop = speed / _decelerationItemsPerSecondSquared;
    final appliedSeconds = seconds < timeUntilStop ? seconds : timeUntilStop;
    // 使用匀减速位移公式；单位已在 startInertia 时转为“槽位/秒”。
    final distance = direction *
        (speed * appliedSeconds -
            0.5 *
                _decelerationItemsPerSecondSquared *
                appliedSeconds *
                appliedSeconds);
    final next = current.scrollByItems(distance);
    final hitBoundary = next == current ||
        (direction < 0 && next.isAtFutureLimit) ||
        (direction > 0 && next.isAtOldest);
    final stopped = appliedSeconds >= timeUntilStop;
    if (hitBoundary || stopped) {
      cancelInertia();
    } else {
      _viewport = next;
      _velocityItemsPerSecond -=
          direction * _decelerationItemsPerSecondSquared * appliedSeconds;
    }
    return next == current ? null : ChartViewportIntent(next);
  }

  void cancelInertia() {
    _viewport = null;
    _velocityItemsPerSecond = 0;
    _decelerationItemsPerSecondSquared = 0;
  }
}

/// Controller API 使用的确定性视口导航命令。
abstract final class ChartViewportNavigator {
  static ChartViewport toLatest(ChartViewport viewport) =>
      viewport.copyWith(scrollOffsetItems: 0);

  static ChartViewport locateTime({
    required ChartViewport viewport,
    required VersionedKlineData data,
    required int epochMilliseconds,
    double alignment = 0.5,
  }) {
    _requireFinite(alignment, 'alignment');
    if (alignment < 0 || alignment > 1) {
      throw ArgumentError.value(alignment, 'alignment', 'Must be within 0..1.');
    }
    final position = ChartXTransform(
      viewport: viewport,
      data: data,
    ).timeToDataPosition(epochMilliseconds);
    final desiredLeft = position - viewport.visibleItemCapacity * alignment;
    final desiredRight = desiredLeft + viewport.visibleItemCapacity;
    return viewport.copyWith(
      scrollOffsetItems:
          viewport.itemCount + viewport.trailingPaddingItems - desiredRight,
    );
  }

  /// 向左追加更早数据后保持当前可见 K 线不跳动。
  static ChartViewport preserveAfterPrepend(
    ChartViewport viewport, {
    required int prependedItemCount,
  }) {
    if (prependedItemCount < 0) {
      throw ArgumentError.value(
        prependedItemCount,
        'prependedItemCount',
        'Must not be negative.',
      );
    }
    return viewport.copyWith(
      itemCount: viewport.itemCount + prependedItemCount,
    );
  }

  /// 应用实时数据窗口变化，同时避免已可见的 K 线意外移动。
  ///
  /// [appendedItemCount] 为旧最新 K 线之后增加的槽位数，也覆盖“删除旧数据同时追加新数据”的
  /// 滚动窗口。视口跟随最新数据时，追加后继续跟随；用户查看历史或已展示未来留白时，则将
  /// 滚动偏移增加该数量，以保持既有 K 线中心的局部 X 坐标不变。
  static ChartViewport preserveAfterRealtimeDataChange(
    ChartViewport viewport, {
    required int nextItemCount,
    required int appendedItemCount,
    bool followLatest = true,
  }) {
    if (nextItemCount < 0) {
      throw ArgumentError.value(
        nextItemCount,
        'nextItemCount',
        'Must not be negative.',
      );
    }
    if (appendedItemCount < 0) {
      throw ArgumentError.value(
        appendedItemCount,
        'appendedItemCount',
        'Must not be negative.',
      );
    }
    final shouldFollowLatest =
        followLatest && viewport.isAtLatest && appendedItemCount > 0;
    return viewport.copyWith(
      itemCount: nextItemCount,
      scrollOffsetItems: shouldFollowLatest
          ? 0
          : viewport.scrollOffsetItems + appendedItemCount,
    );
  }
}

void _requireFinite(double value, String name) {
  if (!value.isFinite) {
    throw ArgumentError.value(value, name, 'Must be finite.');
  }
}

void _requirePositiveFinite(double value, String name) {
  if (!value.isFinite || value <= 0) {
    throw ArgumentError.value(value, name, 'Must be finite and positive.');
  }
}

void _requireNonNegativeFinite(double value, String name) {
  if (!value.isFinite || value < 0) {
    throw ArgumentError.value(
      value,
      name,
      'Must be finite and non-negative.',
    );
  }
}
