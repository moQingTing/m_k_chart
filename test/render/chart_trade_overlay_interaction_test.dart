import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/model/model.dart';
import 'package:m_k_chart/src/render/chart_layer_geometry.dart';
import 'package:m_k_chart/src/render/render.dart';
import 'package:m_k_chart/src/viewport/viewport.dart';

import '../support/v2_kline_fixture.dart';

void main() {
  test('price line hit uses projected price and ignores hidden lines', () {
    final fixture = _fixture(
      priceLines: [
        ChartPriceLine(id: 'hidden', price: 1000, visible: false),
        ChartPriceLine(
          id: 'entry',
          price: 1001,
          side: ChartOverlaySide.buy,
        ),
      ],
    );
    final position = Offset(120, fixture.priceY(1001) + 4);

    final hit = ChartTradeOverlayHitTester.hitTest(
      snapshot: fixture.snapshot,
      localPosition: position,
      tolerance: 5.1,
    );

    expect(hit?.id, 'entry');
    expect(hit?.kind, ChartTradeOverlayKind.priceLine);
    expect(hit?.side, ChartOverlaySide.buy);
    expect(hit?.distance, closeTo(4, 0.001));
  });

  test('value markers only hit inside the configured right edge strip', () {
    final fixture = _fixture(
      valueMarkers: [
        ChartValueMarker(id: 'stop', price: 1001, text: '止损'),
      ],
    );
    final y = fixture.priceY(1001);

    expect(
      ChartTradeOverlayHitTester.hitTest(
        snapshot: fixture.snapshot,
        localPosition: Offset(100, y),
      ),
      isNull,
    );
    expect(
      ChartTradeOverlayHitTester.hitTest(
        snapshot: fixture.snapshot,
        localPosition: Offset(fixture.layout.mainPanel.bounds.right - 2, y),
      )?.kind,
      ChartTradeOverlayKind.valueMarker,
    );
  });

  test('event hit combines its projected time and price coordinates', () {
    final time = buildV2KlineFixture(6)[2].openTime;
    final fixture = _fixture(
      eventOverlays: [
        ChartEventOverlay(
          id: 'fill',
          epochMilliseconds: time,
          price: 1001,
          side: ChartOverlaySide.sell,
        ),
      ],
    );
    final position = Offset(fixture.timeX(time) + 3, fixture.priceY(1001) + 4);

    final hit = ChartTradeOverlayHitTester.hitTest(
      snapshot: fixture.snapshot,
      localPosition: position,
      tolerance: 5.1,
    );

    expect(hit?.id, 'fill');
    expect(hit?.epochMilliseconds, time);
    expect(hit?.distance, closeTo(5, 0.001));
  });

  test('hit and interaction payloads enforce event and action contracts', () {
    final hit = ChartTradeOverlayHit(
      id: 'entry',
      kind: ChartTradeOverlayKind.priceLine,
      side: ChartOverlaySide.buy,
      price: 1001,
      distance: 0,
    );
    final drag = ChartTradeOverlayInteraction(
      hit: hit,
      type: ChartTradeOverlayInteractionType.dragUpdate,
      price: 1002,
    );
    final action = ChartTradeOverlayInteraction(
      hit: hit,
      type: ChartTradeOverlayInteractionType.action,
      actionId: 'cancel',
    );

    expect(drag.price, 1002);
    expect(action.actionId, 'cancel');
    expect(
      () => ChartTradeOverlayHit(
        id: 'event',
        kind: ChartTradeOverlayKind.event,
        side: ChartOverlaySide.neutral,
        price: 1,
        distance: 0,
      ),
      throwsArgumentError,
    );
    expect(
      () => ChartTradeOverlayInteraction(
        hit: hit,
        type: ChartTradeOverlayInteractionType.action,
      ),
      throwsArgumentError,
    );
    expect(
      () => ChartTradeOverlayInteraction(
        hit: hit,
        type: ChartTradeOverlayInteractionType.tap,
        actionId: 'cancel',
      ),
      throwsArgumentError,
    );
  });

  test('hit tester validates coordinates and configurable dimensions', () {
    final fixture = _fixture();

    expect(
      () => ChartTradeOverlayHitTester.hitTest(
        snapshot: fixture.snapshot,
        localPosition: const Offset(double.nan, 0),
      ),
      throwsArgumentError,
    );
    expect(
      () => ChartTradeOverlayHitTester.hitTest(
        snapshot: fixture.snapshot,
        localPosition: Offset.zero,
        tolerance: -1,
      ),
      throwsArgumentError,
    );
  });
}

_Fixture _fixture({
  Iterable<ChartPriceLine> priceLines = const [],
  Iterable<ChartEventOverlay> eventOverlays = const [],
  Iterable<ChartValueMarker> valueMarkers = const [],
}) {
  final data = _StableData(UnmodifiableListView(buildV2KlineFixture(6)));
  final layout = ChartLayoutModel(width: 300, height: 240);
  final viewport = ChartViewport(
    itemCount: data.data.length,
    width: layout.drawingBounds.width,
    itemExtent: 40,
  );
  final snapshot = RenderSnapshot<_Theme>(
    data: data,
    viewport: viewport,
    layout: layout,
    theme: const _Theme(),
    versions: const RenderSnapshotVersions(),
    priceLines: priceLines,
    eventOverlays: eventOverlays,
    valueMarkers: valueMarkers,
  );
  return _Fixture(snapshot, layout);
}

final class _Fixture {
  const _Fixture(this.snapshot, this.layout);

  final RenderSnapshot<_Theme> snapshot;
  final ChartLayoutModel layout;

  double priceY(double price) => ChartLayerGeometry.rangeFor(snapshot, 'main')
      .transform(layout.mainPanel.bounds)
      .priceToLocalY(price);

  double timeX(int time) => ChartXTransform(
        viewport: snapshot.viewport,
        data: snapshot.data,
      ).timeToLocalX(time);
}

final class _StableData implements VersionedKlineData {
  const _StableData(this.data);

  @override
  final List<Kline> data;

  @override
  KlineDataVersion get version => KlineDataVersion.zero;
}

final class _Theme {
  const _Theme();
}
