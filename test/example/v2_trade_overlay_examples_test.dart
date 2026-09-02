import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The example composer is intentionally outside the stable package API.
// ignore: avoid_relative_lib_imports
import '../../example/lib/v2_trade_overlay_examples.dart';
import '../support/v2_kline_fixture.dart';

void main() {
  test('trade examples compose five stable SDK-free price lines', () {
    final candles = buildV2KlineFixture(6);
    final result = buildDemoTradeOverlays(candles);
    final lowest = candles.map((item) => item.low).reduce(
          (left, right) => left < right ? left : right,
        );
    final highest = candles.map((item) => item.high).reduce(
          (left, right) => left > right ? left : right,
        );

    expect(
      result.priceLines.map((line) => line.id),
      [
        'demo-position-long-average',
        'demo-position-long-liquidation',
        'demo-order-buy-limit',
        'demo-order-long-take-profit',
        'demo-order-long-stop-loss',
      ],
    );
    expect(
      result.priceLines.map((line) => line.label),
      ['多仓均价', '强平价', '买入挂单', '止盈', '止损'],
    );
    expect(
      result.priceLines.every(
        (line) => line.price >= lowest && line.price <= highest,
      ),
      isTrue,
    );
    expect(
      () => result.priceLines.add(result.priceLines.first),
      throwsUnsupportedError,
    );
  });

  test('trade examples produce an immutable empty set without candles', () {
    final result = buildDemoTradeOverlays(const []);

    expect(result.priceLines, isEmpty);
    expect(() => result.priceLines.clear(), throwsUnsupportedError);
  });

  test('trade example composer has no exchange client dependency', () {
    final source = File(
      '${Directory.current.path}/example/lib/v2_trade_overlay_examples.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('okx_market_data_client')));
    expect(source, isNot(contains('binance')));
    expect(source, isNot(contains('http')));
  });
}
