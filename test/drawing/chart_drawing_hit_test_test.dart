import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/drawing/drawing.dart';
import 'package:m_k_chart/src/model/model.dart';
import 'package:m_k_chart/src/viewport/viewport.dart';

void main() {
  group('ChartDrawingAnchorProjector', () {
    test('maps time and price anchors to panel-local control points', () {
      final drawing = _drawing(
        kind: ChartDrawingKind.trendLine,
        anchors: [
          ChartDrawingAnchor(epochMilliseconds: 0, price: 100),
          ChartDrawingAnchor(epochMilliseconds: 2000, price: 0),
        ],
      );

      final points = ChartDrawingAnchorProjector.project(
        drawing: drawing,
        xTransform: _xTransform(),
        priceTransform: _priceTransform(),
        localXOffset: 16,
      );

      expect(
        points,
        [
          ChartDrawingControlPoint(
            drawingId: drawing.id,
            anchorIndex: 0,
            localX: 66,
            localY: 0,
          ),
          ChartDrawingControlPoint(
            drawingId: drawing.id,
            anchorIndex: 1,
            localX: 266,
            localY: 100,
          ),
        ],
      );
      expect(
        () => points.add(points.first),
        throwsUnsupportedError,
      );
    });

    test('returns no points for empty data and rejects a non-finite inset', () {
      final drawing = _drawing(
        kind: ChartDrawingKind.horizontalLine,
        anchors: [ChartDrawingAnchor(epochMilliseconds: 0, price: 50)],
      );
      final emptyTransform = ChartXTransform(
        viewport: ChartViewport(),
        data: const _StableData([]),
      );

      expect(
        ChartDrawingAnchorProjector.project(
          drawing: drawing,
          xTransform: emptyTransform,
          priceTransform: _priceTransform(),
        ),
        isEmpty,
      );
      expect(
        () => ChartDrawingAnchorProjector.project(
          drawing: drawing,
          xTransform: _xTransform(),
          priceTransform: _priceTransform(),
          localXOffset: double.nan,
        ),
        throwsArgumentError,
      );
    });
  });

  group('ChartDrawingHitTester', () {
    test('gives the nearest control point precedence over a drawing body', () {
      final drawing = _drawing(
        kind: ChartDrawingKind.horizontalLine,
        anchors: [ChartDrawingAnchor(epochMilliseconds: 0, price: 50)],
      );
      final points = _project(drawing);

      final controlHit = ChartDrawingHitTester.hitTest(
        drawing: drawing,
        controlPoints: points,
        localX: 53,
        localY: 52,
      );
      final bodyHit = ChartDrawingHitTester.hitTest(
        drawing: drawing,
        controlPoints: points,
        localX: 180,
        localY: 54,
        controlPointTolerance: 0,
      );

      expect(controlHit!.kind, ChartDrawingHitKind.controlPoint);
      expect(controlHit.anchorIndex, 0);
      expect(controlHit.distance, closeTo(3.6055, 0.0001));
      expect(bodyHit!.kind, ChartDrawingHitKind.body);
      expect(bodyHit.distance, 4);
    });

    test('uses infinite horizontal and vertical drawing bodies', () {
      final horizontal = _drawing(
        id: 'horizontal',
        kind: ChartDrawingKind.horizontalLine,
        anchors: [ChartDrawingAnchor(epochMilliseconds: 0, price: 50)],
      );
      final vertical = _drawing(
        id: 'vertical',
        kind: ChartDrawingKind.verticalLine,
        anchors: [ChartDrawingAnchor(epochMilliseconds: 1000, price: 50)],
      );

      expect(
        ChartDrawingHitTester.hitTest(
          drawing: horizontal,
          controlPoints: _project(horizontal),
          localX: -500,
          localY: 55,
          controlPointTolerance: 0,
        )!
            .kind,
        ChartDrawingHitKind.body,
      );
      expect(
        ChartDrawingHitTester.hitTest(
          drawing: vertical,
          controlPoints: _project(vertical),
          localX: 154,
          localY: -500,
          controlPointTolerance: 0,
        )!
            .kind,
        ChartDrawingHitKind.body,
      );
    });

    test('distinguishes ray direction and rectangle edges', () {
      final ray = _drawing(
        id: 'ray',
        kind: ChartDrawingKind.ray,
        anchors: [
          ChartDrawingAnchor(epochMilliseconds: 0, price: 50),
          ChartDrawingAnchor(epochMilliseconds: 1000, price: 50),
        ],
      );
      final rectangle = _drawing(
        id: 'rectangle',
        kind: ChartDrawingKind.rectangle,
        anchors: [
          ChartDrawingAnchor(epochMilliseconds: 0, price: 30),
          ChartDrawingAnchor(epochMilliseconds: 2000, price: 70),
        ],
      );

      expect(
        ChartDrawingHitTester.hitTest(
          drawing: ray,
          controlPoints: _project(ray),
          localX: 280,
          localY: 53,
          controlPointTolerance: 0,
        )!
            .kind,
        ChartDrawingHitKind.body,
      );
      expect(
        ChartDrawingHitTester.hitTest(
          drawing: ray,
          controlPoints: _project(ray),
          localX: 30,
          localY: 50,
          controlPointTolerance: 0,
        ),
        isNull,
      );
      expect(
        ChartDrawingHitTester.hitTest(
          drawing: rectangle,
          controlPoints: _project(rectangle),
          localX: 150,
          localY: 27,
          controlPointTolerance: 0,
        )!
            .kind,
        ChartDrawingHitKind.body,
      );
      expect(
        ChartDrawingHitTester.hitTest(
          drawing: rectangle,
          controlPoints: _project(rectangle),
          localX: 275,
          localY: 30,
          controlPointTolerance: 0,
        ),
        isNull,
      );
    });

    test('ignores hidden drawings and rejects an unrelated point set', () {
      final hidden = _drawing(
        id: 'hidden',
        kind: ChartDrawingKind.horizontalLine,
        anchors: [ChartDrawingAnchor(epochMilliseconds: 0, price: 50)],
        style: ChartDrawingStyle(visible: false),
      );
      final shown = _drawing(
        id: 'shown',
        kind: ChartDrawingKind.horizontalLine,
        anchors: [ChartDrawingAnchor(epochMilliseconds: 0, price: 50)],
      );

      expect(
        ChartDrawingHitTester.hitTest(
          drawing: hidden,
          controlPoints: _project(hidden),
          localX: 100,
          localY: 50,
        ),
        isNull,
      );
      expect(
        () => ChartDrawingHitTester.hitTest(
          drawing: shown,
          controlPoints: _project(hidden),
          localX: 100,
          localY: 50,
        ),
        throwsArgumentError,
      );
    });
  });
}

ChartDrawing _drawing({
  String id = 'drawing',
  required ChartDrawingKind kind,
  required List<ChartDrawingAnchor> anchors,
  ChartDrawingStyle? style,
}) =>
    ChartDrawing(id: id, kind: kind, anchors: anchors, style: style);

List<ChartDrawingControlPoint> _project(ChartDrawing drawing) =>
    ChartDrawingAnchorProjector.project(
      drawing: drawing,
      xTransform: _xTransform(),
      priceTransform: _priceTransform(),
    );

ChartXTransform _xTransform() => ChartXTransform(
      viewport: ChartViewport(
        itemCount: 3,
        width: 300,
        itemExtent: 100,
        maxItemExtent: 100,
      ),
      data: _StableData([
        _kline(0),
        _kline(1000),
        _kline(2000),
      ]),
    );

ChartPriceTransform _priceTransform() => ChartPriceTransform(
      minPrice: 0,
      maxPrice: 100,
      top: 0,
      bottom: 100,
    );

Kline _kline(int openTime) => Kline(
      symbol: 'BTCUSDT',
      interval: KlineInterval.oneMinute,
      openTime: openTime,
      closeTime: openTime + 999,
      open: 50,
      high: 60,
      low: 40,
      close: 50,
      baseVolume: 10,
      quoteVolume: 500,
      tradeCount: 1,
      isClosed: true,
    );

final class _StableData implements VersionedKlineData {
  const _StableData(this.data);

  @override
  final List<Kline> data;

  @override
  KlineDataVersion get version => KlineDataVersion.zero;
}
