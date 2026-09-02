import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/model/model.dart';
import 'package:m_k_chart/src/render/render.dart';
import 'package:m_k_chart/src/theme/theme.dart';

void main() {
  test('depth projection uses real price distance and shared quantity scale',
      () {
    final snapshot = _snapshot();
    final projection = DepthCurveProjection.fromSnapshot(snapshot);
    final layout = snapshot.layout;

    expect(projection.bids.first.position.dx, layout.bidBounds.right);
    expect(projection.bids.last.position.dx, layout.bidBounds.left);
    expect(projection.asks.first.position.dx, layout.askBounds.left);
    expect(projection.asks.last.position.dx, layout.askBounds.right);
    expect(
      projection.bids.first.position.dy,
      greaterThan(projection.bids.last.position.dy),
    );
    expect(
      projection.asks.first.position.dy,
      greaterThan(projection.asks.last.position.dy),
    );
    expect(() => projection.bids.clear(), throwsUnsupportedError);
  });

  test('single levels stay at the spread-facing edge', () {
    final snapshot = DepthRenderSnapshot<DefaultChartRenderStyle>(
      book: DepthBook(
        bids: [DepthLevel(price: 99, quantity: 2)],
        asks: [DepthLevel(price: 101, quantity: 3)],
      ),
      theme: DefaultChartRenderStyle(),
      layout: DepthChartLayout(size: const Size(300, 180)),
    );
    final projection = DepthCurveProjection.fromSnapshot(snapshot);

    expect(projection.bids.single.position.dx, snapshot.layout.bidBounds.right);
    expect(projection.asks.single.position.dx, snapshot.layout.askBounds.left);
  });

  test('renderer paints bid and ask colors into their own halves', () async {
    final snapshot = _snapshot();
    final bytes = await _paint(snapshot);

    expect(
      _containsColor(
        bytes,
        snapshot.layout.size.width.toInt(),
        snapshot.layout.bidBounds,
        snapshot.theme.upColor,
      ),
      isTrue,
    );
    expect(
      _containsColor(
        bytes,
        snapshot.layout.size.width.toInt(),
        snapshot.layout.askBounds,
        snapshot.theme.downColor,
      ),
      isTrue,
    );
  });

  test('empty depth paints only a stable background and grid', () async {
    final snapshot = DepthRenderSnapshot<DefaultChartRenderStyle>(
      book: DepthBook(bids: const [], asks: const []),
      theme: DefaultChartRenderStyle(),
      layout: DepthChartLayout(size: const Size(300, 180)),
    );

    final bytes = await _paint(snapshot);

    expect(
      _containsColor(
        bytes,
        300,
        snapshot.layout.bidBounds,
        snapshot.theme.upColor,
      ),
      isFalse,
    );
    expect(
      DepthCurveProjection.fromSnapshot(snapshot).bids,
      isEmpty,
    );
  });

  test('layout and snapshot reject impossible geometry or versions', () {
    expect(
      () => DepthChartLayout(size: const Size(10, 10), centerGap: 10),
      throwsArgumentError,
    );
    expect(
      () => DepthRenderSnapshot<DefaultChartRenderStyle>(
        book: DepthBook(bids: const [], asks: const []),
        theme: DefaultChartRenderStyle(),
        layout: DepthChartLayout(size: const Size(300, 180)),
        version: -1,
      ),
      throwsArgumentError,
    );
  });
}

DepthRenderSnapshot<DefaultChartRenderStyle> _snapshot() =>
    DepthRenderSnapshot<DefaultChartRenderStyle>(
      book: DepthBook(
        bids: [
          DepthLevel(price: 99, quantity: 2),
          DepthLevel(price: 97, quantity: 3),
        ],
        asks: [
          DepthLevel(price: 101, quantity: 1),
          DepthLevel(price: 104, quantity: 5),
        ],
      ),
      theme: DefaultChartRenderStyle(
        backgroundColor: const Color(0xff101820),
        gridColor: const Color(0xff283848),
        upColor: const Color(0xff12b981),
        downColor: const Color(0xfff0445e),
      ),
      layout: DepthChartLayout(size: const Size(300, 180)),
    );

Future<ByteData> _paint(
  DepthRenderSnapshot<DefaultChartRenderStyle> snapshot,
) async {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  StandardDepthCurveRenderer.paint(canvas: canvas, snapshot: snapshot);
  final image = await recorder.endRecording().toImage(
        snapshot.layout.size.width.toInt(),
        snapshot.layout.size.height.toInt(),
      );
  final bytes = await image.toByteData(format: ImageByteFormat.rawRgba);
  image.dispose();
  return bytes!;
}

bool _containsColor(
  ByteData bytes,
  int width,
  Rect bounds,
  Color target,
) {
  final red = (target.r * 255).round().clamp(0, 255);
  final green = (target.g * 255).round().clamp(0, 255);
  final blue = (target.b * 255).round().clamp(0, 255);
  for (var y = bounds.top.ceil(); y < bounds.bottom.floor(); y++) {
    for (var x = bounds.left.ceil(); x < bounds.right.floor(); x++) {
      final offset = (y * width + x) * 4;
      if ((bytes.getUint8(offset) - red).abs() <= 80 &&
          (bytes.getUint8(offset + 1) - green).abs() <= 80 &&
          (bytes.getUint8(offset + 2) - blue).abs() <= 80 &&
          bytes.getUint8(offset + 3) >= 240) {
        return true;
      }
    }
  }
  return false;
}
