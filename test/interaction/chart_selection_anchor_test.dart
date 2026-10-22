import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/data/data.dart';
import 'package:m_k_chart/src/interaction/interaction.dart';
import 'package:m_k_chart/src/model/model.dart';

import '../support/v2_kline_fixture.dart';

void main() {
  final candles = buildV2KlineFixture(5);
  final selected = candles[2];
  final anchor = ChartSelectionAnchor(
    candle: selected,
    panelId: 'secondary-vol',
    price: 1200,
  );
  int? resolve(
    List<Kline> data, [
    List<String> panels = const ['secondary-vol'],
  ]) =>
      anchor.resolveIndex(data, panelIds: panels);

  test('replacement and append preserve identity rather than candle values',
      () {
    final replaced = [...candles];
    replaced[2] = selected.copyWith(close: selected.high, baseVolume: 2000);
    expect(resolve(replaced), 2);
    expect(resolve([...replaced, ...buildV2KlineFixture(1, startIndex: 5)]), 2);
    expect(anchor.price, 1200);
  });

  test('prepend and rolling-window trim resolve the new index', () {
    final window = buildV2KlineFixture(4, startIndex: 1);
    expect(resolve(window), 1);
    expect(resolve([...candles.take(1), ...window]), 2);
    expect(resolve(buildV2KlineFixture(3, startIndex: 3)), isNull);
    expect(resolve([]), isNull);
  });

  test('same timestamp in another series must not inherit selection', () {
    Kline other({
      String? symbol,
      KlineInterval? interval,
      KlinePriceSource? priceSource,
    }) =>
        Kline(
          symbol: symbol ?? selected.symbol,
          interval: interval ?? selected.interval,
          priceSource: priceSource ?? selected.priceSource,
          openTime: selected.openTime,
          closeTime: selected.closeTime,
          open: selected.open,
          high: selected.high,
          low: selected.low,
          close: selected.close,
          baseVolume: selected.baseVolume,
          quoteVolume: selected.quoteVolume,
          tradeCount: selected.tradeCount,
          isClosed: selected.isClosed,
        );
    expect(resolve([other(symbol: 'ETHUSDT')]), isNull);
    expect(resolve([other(interval: KlineInterval.oneDay)]), isNull);
    expect(resolve([other(priceSource: KlinePriceSource.mark)]), isNull);
  });

  test('panel reorder preserves selection but deletion and merge invalidate it',
      () {
    expect(resolve(candles, ['main', 'secondary-macd', 'secondary-vol']), 2);
    expect(resolve(candles, ['main', 'secondary-vol', 'secondary-macd']), 2);
    expect(resolve(candles, ['main', 'secondary-macd']), isNull);
    expect(resolve(candles, ['main', 'secondary-overlay']), isNull);
    expect(resolve(candles, []), isNull);
  });

  test('verified snapshots resolve by time while external lists stay general',
      () {
    final store = KlineStore()..replace(candles);
    expect(
      anchor.resolveIndexInSnapshot(
        store.snapshot,
        panelIds: const ['main', 'secondary-vol'],
      ),
      2,
    );
    store.replace(buildV2KlineFixture(3, startIndex: 3));
    expect(
      anchor.resolveIndexInSnapshot(
        store.snapshot,
        panelIds: const ['secondary-vol'],
      ),
      isNull,
    );
    expect(resolve([candles[3], selected, candles[0]]), 1);
  });

  test('selection anchors reject malformed coordinates', () {
    expect(
      () => ChartSelectionAnchor(candle: selected, panelId: '', price: 1),
      throwsArgumentError,
    );
    expect(
      () => ChartSelectionAnchor(
        candle: selected,
        panelId: 'main',
        price: double.nan,
      ),
      throwsArgumentError,
    );
  });
}
