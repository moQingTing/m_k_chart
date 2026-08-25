import '../model/model.dart';
import '../viewport/viewport.dart';
import 'chart_interaction_intent.dart';

/// Per-chart, frame-clock-independent inertial navigation.
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
        viewport.maxScrollOffsetItems == 0 ||
        (velocityLocalXPerSecond < 0 && viewport.isAtLatest) ||
        (velocityLocalXPerSecond > 0 && viewport.isAtOldest)) {
      return false;
    }
    _viewport = viewport;
    _velocityItemsPerSecond = velocityLocalXPerSecond / viewport.itemExtent;
    _decelerationItemsPerSecondSquared =
        decelerationLocalXPerSecondSquared / viewport.itemExtent;
    return true;
  }

  /// Advances by a frame delta rather than an absolute wall-clock timestamp.
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
    final distance = direction *
        (speed * appliedSeconds -
            0.5 *
                _decelerationItemsPerSecondSquared *
                appliedSeconds *
                appliedSeconds);
    final next = current.scrollByItems(distance);
    final hitBoundary = next == current ||
        (direction < 0 && next.isAtLatest) ||
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

/// Deterministic viewport navigation commands used by Controller APIs.
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
      scrollOffsetItems: viewport.itemCount - desiredRight,
    );
  }

  /// Preserves the visible candles after older items are prepended.
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
