import 'package:flutter/foundation.dart';

import 'k_chart_state.dart';

/// Owns one chart instance's state and notification lifecycle.
///
/// The public package does not export this internal entrypoint yet. Commands
/// added by later phases will use [_commit] so all mutations remain atomic.
final class KChartController extends ChangeNotifier
    implements ValueListenable<KChartState> {
  KChartController({KChartState initialState = const KChartState()})
      : _value = initialState;

  KChartState _value;
  bool _isDisposed = false;

  @override
  KChartState get value => _value;

  bool get isDisposed => _isDisposed;

  /// Internal bridge used until typed chart commands are introduced in P1-04.
  ///
  /// It is deliberately not exported by the package public API. Empty changes
  /// preserve identity and do not notify listeners.
  @internal
  void commitStateChange(Iterable<StateSlice> changedSlices) {
    _ensureActive();
    _commit(_value.bump(changedSlices));
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
