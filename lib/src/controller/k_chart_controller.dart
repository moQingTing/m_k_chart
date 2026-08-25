import 'package:flutter/foundation.dart';

import '../interaction/interaction.dart';
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
    _commit(
      _value.bump(
        changedSlices,
        viewport: viewport,
        layout: layout,
        crosshair: crosshair,
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
