import 'package:flutter/foundation.dart';

import '../interaction/interaction.dart';
import '../model/model.dart';
import 'k_chart_event.dart';
import 'k_chart_state.dart';

/// Owns one chart instance's state and notification lifecycle.
///
/// The public package does not export this internal entrypoint yet. Inputs are
/// reduced through [dispatch] or [dispatchBatch] so mutations remain atomic.
final class KChartController extends ChangeNotifier
    implements ValueListenable<KChartState> {
  KChartController({KChartState initialState = const KChartState()})
      : _value = initialState;

  KChartState _value;
  bool _isDisposed = false;

  @override
  KChartState get value => _value;

  bool get isDisposed => _isDisposed;

  void scrollToLatest() {
    dispatch(
      ChartViewportChanged(ChartViewportNavigator.toLatest(_value.viewport)),
    );
  }

  void scrollToTime({
    required VersionedKlineData data,
    required int epochMilliseconds,
    double alignment = 0.5,
  }) {
    dispatch(
      ChartViewportChanged(
        ChartViewportNavigator.locateTime(
          viewport: _value.viewport,
          data: data,
          epochMilliseconds: epochMilliseconds,
          alignment: alignment,
        ),
      ),
    );
  }

  void preserveViewportAfterPrepend({required int prependedItemCount}) {
    dispatch(
      ChartViewportChanged(
        ChartViewportNavigator.preserveAfterPrepend(
          _value.viewport,
          prependedItemCount: prependedItemCount,
        ),
      ),
    );
  }

  /// Updates the viewport for a realtime append, latest-candle replacement,
  /// or rolling-window refresh.
  void preserveViewportAfterRealtimeDataChange({
    required int nextItemCount,
    required int appendedItemCount,
    bool followLatest = true,
  }) {
    dispatch(
      ChartViewportChanged(
        ChartViewportNavigator.preserveAfterRealtimeDataChange(
          _value.viewport,
          nextItemCount: nextItemCount,
          appendedItemCount: appendedItemCount,
          followLatest: followLatest,
        ),
      ),
    );
  }

  bool requestHistoryIfNeeded({double thresholdItems = 2}) {
    _ensureActive();
    final next = _value.historyPaging.requestIfNeeded(
      _value.viewport,
      thresholdItems: thresholdItems,
    );
    if (identical(next, _value.historyPaging)) {
      return false;
    }
    dispatch(ChartHistoryPagingChanged(next));
    return true;
  }

  void completeHistoryRequest({required bool hasMore}) {
    dispatch(
      ChartHistoryPagingChanged(
        _value.historyPaging.complete(hasMore: hasMore),
      ),
    );
  }

  void failHistoryRequest() {
    dispatch(ChartHistoryPagingChanged(_value.historyPaging.fail()));
  }

  void resetHistoryPaging() {
    dispatch(ChartHistoryPagingChanged(_value.historyPaging.reset()));
  }

  /// Reduces one typed event into one immutable state transaction.
  void dispatch(KChartEvent event) {
    dispatchBatch([event]);
  }

  /// Converts one interaction-layer intent into the owning typed event.
  void dispatchInteraction(ChartInteractionIntent intent) {
    switch (intent) {
      case ChartViewportIntent(:final viewport):
        dispatch(ChartViewportChanged(viewport));
      case ChartCrosshairIntent(:final state):
        dispatch(ChartSelectionChanged(state));
      case ChartHistoryPagingIntent(:final state):
        dispatch(ChartHistoryPagingChanged(state));
    }
  }

  /// Atomically reduces multiple events and publishes at most one notification.
  ///
  /// The batch collects the union of affected state slices. An empty batch
  /// preserves state identity and does not notify listeners.
  void dispatchBatch(Iterable<KChartEvent> events) {
    _ensureActive();
    final changedSlices = <StateSlice>{};
    var viewport = _value.viewport;
    var layout = _value.layout;
    var crosshair = _value.crosshair;
    var historyPaging = _value.historyPaging;
    for (final event in events) {
      if (event case ChartViewportChanged(viewport: final next)) {
        viewport = next;
        continue;
      }
      if (event case ChartLayoutChanged(layout: final next)) {
        layout = next;
        continue;
      }
      if (event case ChartSelectionChanged(crosshair: final next)) {
        crosshair = next;
        continue;
      }
      if (event case ChartHistoryPagingChanged(state: final next)) {
        historyPaging = next;
        continue;
      }
      changedSlices.addAll(event.changedSlices);
    }
    if (layout != null) {
      viewport = layout.applyTo(viewport);
    }
    if (viewport != _value.viewport) {
      changedSlices.add(StateSlice.viewport);
    }
    if (layout != _value.layout) {
      changedSlices.add(StateSlice.layout);
    }
    if (crosshair != _value.crosshair) {
      changedSlices.add(StateSlice.selection);
    }
    if (historyPaging != _value.historyPaging) {
      changedSlices.add(StateSlice.history);
    }
    _commit(
      _value.bump(
        changedSlices,
        viewport: viewport,
        layout: layout,
        crosshair: crosshair,
        historyPaging: historyPaging,
      ),
    );
  }

  void _commit(KChartState next) {
    if (identical(next, _value)) {
      return;
    }

    _value = next;
    notifyListeners();
  }

  void _ensureActive() {
    if (_isDisposed) {
      throw StateError('KChartController has been disposed.');
    }
  }

  @override
  void dispose() {
    if (_isDisposed) {
      return;
    }

    _isDisposed = true;
    super.dispose();
  }
}
