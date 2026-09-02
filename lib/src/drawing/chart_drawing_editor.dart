import 'dart:collection';

import '../model/model.dart';
import 'chart_drawing.dart';

enum ChartDrawingOhlcField { open, high, low, close }

final class ChartDrawingOhlcSnap {
  const ChartDrawingOhlcSnap({
    required this.anchor,
    required this.dataIndex,
    required this.field,
  });

  final ChartDrawingAnchor anchor;
  final int dataIndex;
  final ChartDrawingOhlcField field;
}

/// Snaps to the nearest candle time and then to its nearest OHLC price.
abstract final class ChartDrawingOhlcSnapper {
  static ChartDrawingOhlcSnap snap({
    required ChartDrawingAnchor anchor,
    required List<Kline> data,
  }) {
    if (data.isEmpty) throw StateError('Cannot snap without Kline data.');
    var index = 0;
    for (var candidate = 1; candidate < data.length; candidate++) {
      if ((data[candidate].openTime - anchor.epochMilliseconds).abs() <
          (data[index].openTime - anchor.epochMilliseconds).abs()) {
        index = candidate;
      }
    }
    final candle = data[index];
    final values = <(ChartDrawingOhlcField, double)>[
      (ChartDrawingOhlcField.open, candle.open),
      (ChartDrawingOhlcField.high, candle.high),
      (ChartDrawingOhlcField.low, candle.low),
      (ChartDrawingOhlcField.close, candle.close),
    ];
    var nearest = values.first;
    for (final value in values.skip(1)) {
      if ((value.$2 - anchor.price).abs() < (nearest.$2 - anchor.price).abs()) {
        nearest = value;
      }
    }
    return ChartDrawingOhlcSnap(
      anchor: ChartDrawingAnchor(
        epochMilliseconds: candle.openTime,
        price: nearest.$2,
      ),
      dataIndex: index,
      field: nearest.$1,
    );
  }
}

/// Immutable drawing edit state: selection, movement, locking and deletion.
final class ChartDrawingEditor {
  factory ChartDrawingEditor({
    Iterable<ChartDrawing> drawings = const [],
    String? selectedDrawingId,
  }) {
    final values = List<ChartDrawing>.unmodifiable(drawings);
    final byId = <String, ChartDrawing>{
      for (final drawing in values) drawing.id: drawing,
    };
    if (byId.length != values.length) {
      throw ArgumentError('Duplicate drawing ID.');
    }
    if (selectedDrawingId != null && !byId.containsKey(selectedDrawingId)) {
      throw ArgumentError.value(selectedDrawingId, 'selectedDrawingId');
    }
    return ChartDrawingEditor._(
      values,
      UnmodifiableMapView(byId),
      selectedDrawingId,
    );
  }

  const ChartDrawingEditor._(
    this.drawings,
    this.drawingById,
    this.selectedDrawingId,
  );
  final List<ChartDrawing> drawings;
  final Map<String, ChartDrawing> drawingById;
  final String? selectedDrawingId;

  ChartDrawingEditor select(String? id) => ChartDrawingEditor(
        drawings: drawings,
        selectedDrawingId: id,
      );

  ChartDrawingEditor setLocked(String id, bool value) =>
      _replace(id, _get(id).copyWith(isLocked: value));

  ChartDrawingEditor moveDrawing({
    required String id,
    required int timeDeltaMilliseconds,
    required double priceDelta,
  }) {
    if (!priceDelta.isFinite) {
      throw ArgumentError.value(priceDelta, 'priceDelta');
    }
    final drawing = _editable(id);
    return _replace(
      id,
      drawing.copyWith(
        anchors: [
          for (final anchor in drawing.anchors)
            ChartDrawingAnchor(
              epochMilliseconds:
                  anchor.epochMilliseconds + timeDeltaMilliseconds,
              price: anchor.price + priceDelta,
            ),
        ],
      ),
    );
  }

  ChartDrawingEditor moveAnchor({
    required String id,
    required int anchorIndex,
    required ChartDrawingAnchor anchor,
  }) {
    final drawing = _editable(id);
    if (anchorIndex < 0 || anchorIndex >= drawing.anchors.length) {
      throw RangeError.index(anchorIndex, drawing.anchors);
    }
    final anchors = List<ChartDrawingAnchor>.of(drawing.anchors)
      ..[anchorIndex] = anchor;
    return _replace(id, drawing.copyWith(anchors: anchors));
  }

  ChartDrawingEditor snapAnchor({
    required String id,
    required int anchorIndex,
    required List<Kline> data,
  }) {
    final drawing = _editable(id);
    if (anchorIndex < 0 || anchorIndex >= drawing.anchors.length) {
      throw RangeError.index(anchorIndex, drawing.anchors);
    }
    return moveAnchor(
      id: id,
      anchorIndex: anchorIndex,
      anchor: ChartDrawingOhlcSnapper.snap(
        anchor: drawing.anchors[anchorIndex],
        data: data,
      ).anchor,
    );
  }

  ChartDrawingEditor remove(String id) {
    _editable(id);
    return ChartDrawingEditor(
      drawings: drawings.where((item) => item.id != id),
      selectedDrawingId: selectedDrawingId == id ? null : selectedDrawingId,
    );
  }

  ChartDrawing _get(String id) =>
      drawingById[id] ?? (throw ArgumentError.value(id, 'id'));
  ChartDrawing _editable(String id) {
    final drawing = _get(id);
    if (drawing.isLocked) {
      throw StateError('Drawing $id is locked.');
    }
    return drawing;
  }

  ChartDrawingEditor _replace(String id, ChartDrawing replacement) =>
      ChartDrawingEditor(
        drawings: [
          for (final drawing in drawings)
            if (drawing.id == id) replacement else drawing,
        ],
        selectedDrawingId: selectedDrawingId,
      );
}
