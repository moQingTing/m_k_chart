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

  const IndicatorSeries._(this.id, this.values);

  final String id;
  final List<double?> values;
}

/// Complete calculation output for one configured indicator instance.
final class IndicatorResult {
  factory IndicatorResult({
    required String instanceId,
    required String definitionId,
    required KlineDataVersion dataVersion,
    required int length,
    required Iterable<IndicatorSeries> series,
  }) {
    if (instanceId.trim().isEmpty || definitionId.trim().isEmpty) {
      throw ArgumentError('Indicator result ids must not be empty.');
    }
    if (length < 0) {
      throw ArgumentError.value(length, 'length', 'Must be non-negative.');
    }
    final immutableSeries = List<IndicatorSeries>.unmodifiable(series);
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
    );
  }

  const IndicatorResult._({
    required this.instanceId,
    required this.definitionId,
    required this.dataVersion,
    required this.length,
    required this.series,
  });

  final String instanceId;
  final String definitionId;
  final KlineDataVersion dataVersion;
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
