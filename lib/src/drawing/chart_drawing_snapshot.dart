import '../model/kline.dart' show Kline, KlinePriceSource;
import '../model/kline_series.dart';
import 'chart_drawing.dart';
import 'chart_drawing_timeline_restorer.dart';

/// Versioned host-storage value for a group of chart drawings.
///
/// [sourceId] is a stable host-defined data-provider identity (for example,
/// `binance-spot`). Symbol, source and price type isolate drawings. Interval is
/// retained as origin metadata but may differ during restore so time/price
/// anchors can be reused on another timeframe.
final class ChartDrawingSnapshot {
  factory ChartDrawingSnapshot({
    required KlineSeries series,
    required String sourceId,
    required Iterable<ChartDrawing> drawings,
  }) {
    if (sourceId.trim().isEmpty) {
      throw ArgumentError.value(sourceId, 'sourceId', 'Must not be empty.');
    }
    final values = List<ChartDrawing>.unmodifiable(drawings);
    final ids = <String>{};
    for (final drawing in values) {
      if (!ids.add(drawing.id)) {
        throw ArgumentError('Duplicate drawing ID: ${drawing.id}');
      }
    }
    return ChartDrawingSnapshot._(
      symbol: series.symbol,
      intervalCode: series.interval.code,
      priceSource: series.priceSource.name,
      sourceId: sourceId,
      drawings: values,
    );
  }

  const ChartDrawingSnapshot._({
    required this.symbol,
    required this.intervalCode,
    required this.priceSource,
    required this.sourceId,
    required this.drawings,
  });

  static const schemaVersion = 1;

  final String symbol;
  final String intervalCode;
  final String priceSource;
  final String sourceId;
  final List<ChartDrawing> drawings;

  Map<String, Object?> toJson() => {
        'schemaVersion': schemaVersion,
        'scope': {
          'sourceId': sourceId,
          'symbol': symbol,
          'intervalCode': intervalCode,
          'priceSource': priceSource,
        },
        'drawings': drawings.map((drawing) => drawing.toJson()).toList(),
      };

  factory ChartDrawingSnapshot.fromJson(Map<String, Object?> json) {
    final version = _snapshotInt(json['schemaVersion'], 'schemaVersion');
    if (version > schemaVersion) {
      throw UnsupportedError('Drawing snapshot schema $version is newer.');
    }
    if (version != schemaVersion) {
      throw FormatException('Unsupported drawing snapshot schema $version.');
    }
    final scope = _snapshotMap(json['scope'], 'scope');
    final priceSource = _snapshotString(
      scope['priceSource'],
      'scope.priceSource',
    );
    if (!KlinePriceSource.values.any((source) => source.name == priceSource)) {
      throw FormatException('Unknown price source: $priceSource');
    }
    final rawDrawings = json['drawings'];
    if (rawDrawings is! List) {
      throw const FormatException('drawings must be a list.');
    }
    final drawings = <ChartDrawing>[];
    for (var index = 0; index < rawDrawings.length; index++) {
      drawings.add(
        ChartDrawing.fromJson(
          _snapshotMap(rawDrawings[index], 'drawings[$index]'),
        ),
      );
    }
    return ChartDrawingSnapshot._(
      sourceId: _snapshotString(scope['sourceId'], 'scope.sourceId'),
      symbol: _snapshotString(scope['symbol'], 'scope.symbol'),
      intervalCode:
          _snapshotString(scope['intervalCode'], 'scope.intervalCode'),
      priceSource: priceSource,
      drawings: List.unmodifiable(drawings),
    )._validate();
  }

  /// Restores onto a matching provider/symbol/price type.
  ///
  /// A different interval is permitted: anchors remain absolute UTC time and
  /// price. Use [ChartDrawingOutOfRangePolicy.clampToTimeline] only when the
  /// host explicitly wants off-window anchors moved to the loaded boundaries.
  ChartDrawingSnapshot restoreFor({
    required KlineSeries series,
    required String sourceId,
    required List<Kline> data,
    ChartDrawingOutOfRangePolicy outOfRangePolicy =
        ChartDrawingOutOfRangePolicy.preserve,
  }) {
    if (this.sourceId != sourceId ||
        symbol != series.symbol ||
        priceSource != series.priceSource.name) {
      throw StateError(
        'Drawing snapshot scope does not match the target series/provider.',
      );
    }
    _validateTargetData(series, data);
    return ChartDrawingSnapshot(
      series: series,
      sourceId: sourceId,
      drawings: [
        for (final drawing in drawings)
          ChartDrawingTimelineRestorer.restore(
            drawing: drawing,
            data: data,
            policy: outOfRangePolicy,
          ),
      ],
    );
  }

  ChartDrawingSnapshot _validate() {
    if (sourceId.trim().isEmpty ||
        symbol.trim().isEmpty ||
        intervalCode.trim().isEmpty ||
        priceSource.trim().isEmpty) {
      throw const FormatException(
        'Drawing snapshot scope fields are required.',
      );
    }
    final ids = <String>{};
    for (final drawing in drawings) {
      if (!ids.add(drawing.id)) {
        throw FormatException('Duplicate drawing ID: ${drawing.id}');
      }
    }
    return this;
  }
}

void _validateTargetData(KlineSeries series, List<Kline> data) {
  for (var index = 0; index < data.length; index++) {
    final candle = data[index];
    if (!series.contains(candle)) {
      throw ArgumentError.value(
        candle,
        'data[$index]',
        'Must belong to the target snapshot series.',
      );
    }
    if (index > 0 && candle.openTime <= data[index - 1].openTime) {
      throw ArgumentError.value(
        data,
        'data',
        'Must be strictly ordered by openTime.',
      );
    }
  }
}

Map<String, Object?> _snapshotMap(Object? value, String field) {
  if (value is! Map) throw FormatException('$field must be an object.');
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw FormatException('$field keys must be strings.');
    }
    result[entry.key as String] = entry.value;
  }
  return result;
}

String _snapshotString(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field must be a non-empty string.');
  }
  return value;
}

int _snapshotInt(Object? value, String field) {
  if (value is! int) throw FormatException('$field must be an integer.');
  return value;
}
