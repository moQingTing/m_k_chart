import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/drawing/drawing.dart';
import 'package:m_k_chart/src/render/render.dart';

void main() {
  test('renders every P7-03 base drawing family into the chart bounds',
      () async {
    for (final drawing in _baseDrawings()) {
      final recorder = PictureRecorder();
      final picture = recorder.endRecording;
      final canvas = Canvas(recorder);
      ChartDrawingRenderer.paint(
        canvas: canvas,
        drawing: drawing,
        controlPoints: _pointsFor(drawing),
        bounds: const Rect.fromLTWH(0, 0, 200, 100),
        color: const Color(0xff8a70d6),
        formatPrice: (value) => value.toStringAsFixed(2),
        textFontSize: 14,
      );
      final image = await picture().toImage(200, 100);
      final bytes = await image.toByteData(format: ImageByteFormat.rawRgba);

      expect(
        _hasVisiblePixel(bytes!),
        isTrue,
        reason: '${drawing.kind.name} should paint visible pixels.',
      );
      image.dispose();
    }
  });

  test('accepts dashed styles and rejects an incomplete projected point set',
      () {
    final drawing = ChartDrawing(
      id: 'dashed',
      kind: ChartDrawingKind.trendLine,
      anchors: [
        ChartDrawingAnchor(epochMilliseconds: 1, price: 1),
        ChartDrawingAnchor(epochMilliseconds: 2, price: 2),
      ],
      style: ChartDrawingStyle(dashPattern: [4, 3]),
    );
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);

    expect(
      () => ChartDrawingRenderer.paint(
        canvas: canvas,
        drawing: drawing,
        controlPoints: const [],
        bounds: const Rect.fromLTWH(0, 0, 200, 100),
        color: const Color(0xff8a70d6),
        formatPrice: _formatPrice,
      ),
      throwsArgumentError,
    );
    recorder.endRecording().dispose();
  });
}

Iterable<ChartDrawing> _baseDrawings() sync* {
  for (final kind in ChartDrawingKind.values) {
    final anchors = switch (kind) {
      ChartDrawingKind.horizontalLine ||
      ChartDrawingKind.verticalLine ||
      ChartDrawingKind.text ||
      ChartDrawingKind.priceMarker =>
        [ChartDrawingAnchor(epochMilliseconds: 1, price: 1)],
      ChartDrawingKind.parallelChannel => [
          ChartDrawingAnchor(epochMilliseconds: 1, price: 1),
          ChartDrawingAnchor(epochMilliseconds: 2, price: 2),
          ChartDrawingAnchor(epochMilliseconds: 3, price: 3),
        ],
      _ => [
          ChartDrawingAnchor(epochMilliseconds: 1, price: 1),
          ChartDrawingAnchor(epochMilliseconds: 2, price: 2),
        ],
    };
    yield ChartDrawing(
      id: kind.name,
      kind: kind,
      anchors: anchors,
      text: kind == ChartDrawingKind.text ? '注释' : null,
    );
  }
}

List<ChartDrawingControlPoint> _pointsFor(ChartDrawing drawing) => [
      for (var index = 0; index < drawing.anchors.length; index++)
        ChartDrawingControlPoint(
          drawingId: drawing.id,
          anchorIndex: index,
          localX: 20 + index * 80,
          localY: 20 + index * 30,
        ),
    ];

bool _hasVisiblePixel(ByteData bytes) {
  for (var index = 3; index < bytes.lengthInBytes; index += 4) {
    if (bytes.getUint8(index) != 0) return true;
  }
  return false;
}

String _formatPrice(double value) => value.toStringAsFixed(2);
