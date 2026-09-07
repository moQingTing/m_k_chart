import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/model/model.dart';
import 'package:m_k_chart/src/viewport/viewport.dart';

void main() {
  test('x coordinates round-trip across deterministic viewport matrix', () {
    final data = _irregularData(256);
    var checked = 0;

    for (final width in <double>[240, 320, 430, 600]) {
      for (final extent in <double>[4, 8, 16, 40]) {
        final base = ChartViewport(
          itemCount: data.data.length,
          width: width,
          itemExtent: extent,
          minItemExtent: 2,
          maxItemExtent: 48,
        );
        for (final scroll in <double>[
          0,
          base.maxScrollOffsetItems * 0.17,
          base.maxScrollOffsetItems * 0.53,
          base.maxScrollOffsetItems,
        ]) {
          final transform = ChartXTransform(
            viewport: base.copyWith(scrollOffsetItems: scroll),
            data: data,
          );
          for (final position in <double>[
            -2,
            0.5,
            1,
            17.125,
            127.75,
            255.5,
            258,
          ]) {
            final localX = transform.dataPositionToLocalX(position);
            expect(
              transform.localXToDataPosition(localX),
              closeTo(position, 1e-10),
              reason: 'width=$width extent=$extent scroll=$scroll',
            );
            checked++;
          }
        }
      }
    }

    expect(checked, 448);
  });

  test('irregular timeline round-trips through local coordinates within 1ms',
      () {
    final data = _irregularData(256);
    final times = <int>[
      data.data.first.openTime,
      data.data[1].openTime - 1,
      data.data[17].openTime + 137,
      (data.data[63].openTime + data.data[64].openTime) ~/ 2,
      data.data[127].openTime,
      data.data.last.openTime,
    ];
    var checked = 0;

    for (final width in <double>[240, 430, 600]) {
      for (final extent in <double>[4, 11.5, 40]) {
        final viewport = ChartViewport(
          itemCount: data.data.length,
          width: width,
          itemExtent: extent,
          minItemExtent: 2,
          maxItemExtent: 48,
          scrollOffsetItems: 37.25,
        );
        final transform = ChartXTransform(viewport: viewport, data: data);
        for (final time in times) {
          expect(
            transform.localXToTime(transform.timeToLocalX(time)),
            closeTo(time, 1),
            reason: 'width=$width extent=$extent time=$time',
          );
          checked++;
        }
      }
    }

    expect(checked, 54);
  });

  test('price coordinates round-trip across panel and range matrix', () {
    var checked = 0;
    for (final panel in <(double, double)>[
      (0, 180),
      (12.5, 312.5),
      (340, 560),
    ]) {
      for (final range in <(double, double)>[
        (0.00001, 0.00009),
        (100, 200),
        (63000, 65000),
      ]) {
        final transform = ChartPriceTransform(
          minPrice: range.$1,
          maxPrice: range.$2,
          top: panel.$1,
          bottom: panel.$2,
        );
        final span = range.$2 - range.$1;
        for (final ratio in <double>[-0.25, 0, 0.125, 0.5, 1, 1.25]) {
          final price = range.$1 + span * ratio;
          expect(
            transform.localYToPrice(transform.priceToLocalY(price)),
            closeTo(price, span * 1e-10),
            reason: 'panel=$panel range=$range ratio=$ratio',
          );
          checked++;
        }
      }
    }

    expect(checked, 54);
  });
}

_StableData _irregularData(int count) {
  const base = 1704067200000;
  var openTime = base;
  final data = <Kline>[];
  for (var index = 0; index < count; index++) {
    if (index > 0) {
      openTime += <int>[60000, 60000, 120000, 180000, 300000][index % 5];
    }
    data.add(
      Kline(
        symbol: 'BTCUSDT',
        interval: KlineInterval.oneMinute,
        openTime: openTime,
        closeTime: openTime + 59999,
        open: 100 + index.toDouble(),
        high: 102 + index.toDouble(),
        low: 99 + index.toDouble(),
        close: 101 + index.toDouble(),
        baseVolume: 10,
        quoteVolume: 1010,
        tradeCount: 20,
        isClosed: true,
      ),
    );
  }
  return _StableData(data);
}

final class _StableData implements VersionedKlineData {
  const _StableData(this.data);

  @override
  final List<Kline> data;

  @override
  KlineDataVersion get version => KlineDataVersion.zero;
}
