import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/drawing/chart_drawing.dart';

void main() {
  test('round-trips anchored drawings with semantic style JSON', () {
    final drawing = ChartDrawing(
      id: 'trend-1',
      kind: ChartDrawingKind.trendLine,
      anchors: [
        ChartDrawingAnchor(epochMilliseconds: 1700000000000, price: 100),
        ChartDrawingAnchor(epochMilliseconds: 1700000060000, price: 105),
      ],
      style: ChartDrawingStyle(
        colorKey: 'drawing.yellow',
        strokeWidth: 1.5,
        dashPattern: [4, 2],
      ),
    );

    final decoded = jsonDecode(jsonEncode(drawing.toJson())) as Map;
    final restored = ChartDrawing.fromJson(Map<String, Object?>.from(decoded));

    expect(restored, drawing);
    expect(
      () => restored.anchors.add(
        ChartDrawingAnchor(epochMilliseconds: 1700000120000, price: 110),
      ),
      throwsUnsupportedError,
    );
  });

  test('migrates the pre-versioned type and points shape', () {
    final drawing = ChartDrawing.fromJson({
      'id': 'legacy-line',
      'type': 'horizontalLine',
      'points': [
        {'time': 1700000000000, 'price': 101.5},
      ],
      'color': 'legacy.purple',
      'width': 2,
    });

    expect(drawing.kind, ChartDrawingKind.horizontalLine);
    expect(drawing.style.colorKey, 'legacy.purple');
    expect(drawing.style.strokeWidth, 2);
  });

  test('rejects malformed anchors, unknown kinds, and future schema', () {
    expect(
      () => ChartDrawing.fromJson({
        'schemaVersion': ChartDrawing.schemaVersion + 1,
      }),
      throwsUnsupportedError,
    );
    expect(
      () => ChartDrawing.fromJson({
        'schemaVersion': 1,
        'id': 'bad',
        'kind': 'unknown',
        'anchors': [],
      }),
      throwsFormatException,
    );
    expect(
      () => ChartDrawing(
        id: 'text',
        kind: ChartDrawingKind.text,
        anchors: [
          ChartDrawingAnchor(epochMilliseconds: 1700000000000, price: 1),
        ],
      ),
      throwsArgumentError,
    );
  });

  test('keeps every tool family and optional locked field compatible', () {
    for (final kind in ChartDrawingKind.values) {
      final anchorCount = kind == ChartDrawingKind.parallelChannel
          ? 3
          : (kind == ChartDrawingKind.horizontalLine ||
                  kind == ChartDrawingKind.verticalLine ||
                  kind == ChartDrawingKind.text ||
                  kind == ChartDrawingKind.priceMarker)
              ? 1
              : 2;
      final drawing = ChartDrawing(
        id: kind.name,
        kind: kind,
        anchors: [
          for (var index = 0; index < anchorCount; index++)
            ChartDrawingAnchor(
                epochMilliseconds: 1700000000000 + index,
                price: index.toDouble()),
        ],
        text: kind == ChartDrawingKind.text ? '文本' : null,
        isLocked: true,
      );
      expect(ChartDrawing.fromJson(drawing.toJson()), drawing);
    }
    final unlocked = ChartDrawing.fromJson({
      'schemaVersion': 1,
      'id': 'old-v1',
      'kind': 'horizontalLine',
      'anchors': [
        {'time': 1, 'price': 1}
      ],
    });
    expect(unlocked.isLocked, isFalse);
  });
}
