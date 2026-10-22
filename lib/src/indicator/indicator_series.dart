import 'dart:collection';

import '../model/model.dart';

/// Values for one renderer-described output. `null` means insufficient input.
final class IndicatorSeries {
  factory IndicatorSeries({
    required String id,
    required Iterable<double?> values,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty.');
    }
    final immutableValues = List<double?>.unmodifiable(values);
    for (var index = 0; index < immutableValues.length; index++) {
      final value = immutableValues[index];
      if (value != null && !value.isFinite) {
        throw ArgumentError.value(
          value,
          'values[$index]',
          'Must be finite or null.',
        );
      }
    }
    return IndicatorSeries._(id, immutableValues);
  }

  /// Internal ownership-transfer constructor used by incremental algorithms.
  ///
  /// The caller must not retain or mutate [values] after this call.
  factory IndicatorSeries.takeOwnership({
    required String id,
    required List<double?> values,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty.');
    }
    if (values is IndicatorValueBuffer) {
      values.validateUpdates();
      return IndicatorSeries._(id, values.freeze());
    }
    _validateSeries(id, values);
    return IndicatorSeries._(id, UnmodifiableListView(values));
  }

  const IndicatorSeries._(this.id, this.values);

  final String id;
  final List<double?> values;
}

/// Copy-on-write buffer used to build an incremental series result.
///
/// Unchanged values share the previous immutable storage. Small tail updates
/// remain sparse and are periodically flattened to cap lookup overhead.
final class IndicatorValueBuffer extends ListBase<double?> {
  IndicatorValueBuffer.from(List<double?> previous, int length)
      : _previous = previous,
        _length = length {
    if (length < 0) {
      throw ArgumentError.value(length, 'length');
    }
  }

  static const _flattenThreshold = 512;

  final List<double?> _previous;
  final int _length;
  final Map<int, double?> _updates = {};

  @override
  int get length => _length;

  @override
  set length(int value) => throw UnsupportedError('Fixed-length buffer.');

  @override
  double? operator [](int index) {
    RangeError.checkValidIndex(index, this);
    if (_updates.containsKey(index)) {
      return _updates[index];
    }
    return index < _previous.length ? _previous[index] : null;
  }

  @override
  void operator []=(int index, double? value) {
    RangeError.checkValidIndex(index, this);
    _updates[index] = value;
  }

  void validateUpdates() {
    for (final entry in _updates.entries) {
      final value = entry.value;
      if (value != null && !value.isFinite) {
        throw ArgumentError.value(
          value,
          'values[${entry.key}]',
          'Must be finite or null.',
        );
      }
    }
  }

  List<double?> freeze() {
    final previous = _previous;
    if (previous is _PersistentIndicatorValues) {
      if (previous.overrides.length + _updates.length <= _flattenThreshold) {
        final overrides = Map<int, double?>.of(previous.overrides)
          ..addAll(_updates);
        overrides.removeWhere((index, _) => index >= _length);
        return _PersistentIndicatorValues(
          previous.base,
          Map.unmodifiable(overrides),
          _length,
        );
      }
      return _materialize(previous);
    }
    if (_updates.length <= _flattenThreshold) {
      return _PersistentIndicatorValues(
        previous,
        Map.unmodifiable(_updates),
        _length,
      );
    }
    return _materialize(previous);
  }

  List<double?> _materialize(List<double?> previous) {
    final materialized = List<double?>.generate(
      _length,
      (index) => _updates.containsKey(index)
          ? _updates[index]
          : index < previous.length
              ? previous[index]
              : null,
      growable: false,
    );
    return UnmodifiableListView(materialized);
  }
}

final class _PersistentIndicatorValues extends ListBase<double?> {
  _PersistentIndicatorValues(this.base, this.overrides, this._length);

  final List<double?> base;
  final Map<int, double?> overrides;
  final int _length;

  @override
  int get length => _length;

  @override
  set length(int value) => throw UnsupportedError('Immutable values.');

  @override
  double? operator [](int index) {
    RangeError.checkValidIndex(index, this);
    if (overrides.containsKey(index)) {
      return overrides[index];
    }
    return index < base.length ? base[index] : null;
  }

  @override
  void operator []=(int index, double? value) =>
      throw UnsupportedError('Immutable values.');
}

void _validateSeries(String id, List<double?> values) {
  if (id.trim().isEmpty) {
    throw ArgumentError.value(id, 'id', 'Must not be empty.');
  }
  for (var index = 0; index < values.length; index++) {
    final value = values[index];
    if (value != null && !value.isFinite) {
      throw ArgumentError.value(
        value,
        'values[$index]',
        'Must be finite or null.',
      );
    }
  }
}

/// Renderer-invisible immutable values needed to continue recursive formulas.
final class IndicatorComputationState {
  factory IndicatorComputationState({
    required int length,
    required Iterable<IndicatorSeries> series,
  }) {
    final immutableSeries = List<IndicatorSeries>.unmodifiable(series);
    final ids = <String>{};
    for (final item in immutableSeries) {
      if (!ids.add(item.id)) {
        throw ArgumentError.value(item.id, 'series', 'Duplicate state id.');
      }
      if (item.values.length != length) {
        throw ArgumentError(
          'State ${item.id} has ${item.values.length} values; expected $length.',
        );
      }
    }
    return IndicatorComputationState._(length, immutableSeries);
  }

  const IndicatorComputationState._(this.length, this.series);

  final int length;
  final List<IndicatorSeries> series;

  IndicatorSeries? seriesById(String id) {
    for (final item in series) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }
}

/// Complete calculation output for one configured indicator instance.
final class IndicatorResult {
  factory IndicatorResult({
    required String instanceId,
    required String definitionId,
    required KlineDataVersion dataVersion,
    required int length,
    required Iterable<IndicatorSeries> series,
    IndicatorComputationState? computationState,
  }) {
    if (instanceId.trim().isEmpty || definitionId.trim().isEmpty) {
      throw ArgumentError('Indicator result ids must not be empty.');
    }
    if (length < 0) {
      throw ArgumentError.value(length, 'length', 'Must be non-negative.');
    }
    final immutableSeries = List<IndicatorSeries>.unmodifiable(series);
    if (computationState != null && computationState.length != length) {
      throw ArgumentError(
        'Computation state length does not match indicator result length.',
      );
    }
    final ids = <String>{};
    for (final item in immutableSeries) {
      if (!ids.add(item.id)) {
        throw ArgumentError.value(item.id, 'series', 'Duplicate series id.');
      }
      if (item.values.length != length) {
        throw ArgumentError(
          'Series ${item.id} has ${item.values.length} values; expected $length.',
        );
      }
    }
    return IndicatorResult._(
      instanceId: instanceId,
      definitionId: definitionId,
      dataVersion: dataVersion,
      length: length,
      series: immutableSeries,
      computationState: computationState,
    );
  }

  const IndicatorResult._({
    required this.instanceId,
    required this.definitionId,
    required this.dataVersion,
    required this.length,
    required this.series,
    required this.computationState,
  });

  final String instanceId;
  final String definitionId;
  final KlineDataVersion dataVersion;
  final int length;
  final List<IndicatorSeries> series;

  /// Private algorithm continuation data. Renderers must ignore this state.
  final IndicatorComputationState? computationState;

  IndicatorSeries? seriesById(String id) {
    for (final item in series) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }
}
