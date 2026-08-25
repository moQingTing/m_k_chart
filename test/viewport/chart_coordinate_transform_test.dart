import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/model/model.dart';
import 'package:m_k_chart/src/viewport/viewport.dart';

void main() {
  group('ChartXTransform data/local coordinates', () {
    test('maps slot boundaries and centers in chart-local coordinates', () {
      final data = _data([0, 60000, 180000, 240000]);
      final viewport = ChartViewport(
        itemCount: 4,
        width: 16,
        itemExtent: 8,
        scrollOffsetItems: 0.5,
      );
      final transform = ChartXTransform(viewport: viewport, data: data);

      expect(viewport.visibleLeftDataPosition, 1.5);
      expect(viewport.visibleRightDataPosition, 3.5);
      expect(transform.dataPositionToLocalX(1.5), 0);
      expect(transform.dataPositionToLocalX(3.5), 16);
      expect(transform.indexToLocalX(1), 0);
      expect(transform.indexToLocalX(3), 16);
    });

    test('round-trips continuous data positions across zoom and scroll', () {
      final data = _data(List.generate(20, (index) => index * 60000));
      final transform = ChartXTransform(
        viewport: ChartViewport(
          itemCount: 20,
          width: 137,
          itemExtent: 11.5,
          scrollOffsetItems: 3.25,
        ),
        data: data,
      );

      for (final position in [-2.0, 0.5, 7.125, 16.75, 22.0]) {
        final localX = transform.dataPositionToLocalX(position);
        expect(
          transform.localXToDataPosition(localX),
          closeTo(position, 1e-12),
        );
      }
    });

    test('selects the containing slot and clamps outside data', () {
      final data = _data([0, 60000, 120000, 180000]);
      final transform = ChartXTransform(
        viewport: ChartViewport(itemCount: 4, width: 32, itemExtent: 8),
        data: data,
      );

      expect(transform.localXToNearestIndex(-100), 0);
      expect(transform.localXToNearestIndex(7.99), 0);
      expect(transform.localXToNearestIndex(8), 1);
      expect(transform.localXToNearestIndex(100), 3);
      expect(() => transform.indexToLocalX(4), throwsRangeError);
    });
  });

  group('ChartXTransform time coordinates', () {
    test('maps exact opens and interpolates real gaps with binary lookup', () {
      const base = 1704067200000;
      final data = _data([base, base + 60000, base + 180000]);
      final transform = ChartXTransform(
        viewport: ChartViewport(itemCount: 3, width: 24, itemExtent: 8),
        data: data,
      );

      expect(transform.timeToDataPosition(base), 0.5);
      expect(transform.timeToDataPosition(base + 60000), 1.5);
      expect(transform.timeToDataPosition(base + 120000), 2);
      expect(transform.timeToDataPosition(base + 180000), 2.5);
      expect(transform.dataPositionToTime(2), base + 120000);
    });

    test('round-trips time through chart-local X within one millisecond', () {
      const base = 1704067200000;
      final data = _data([base, base + 60000, base + 180000, base + 240000]);
      final transform = ChartXTransform(
        viewport: ChartViewport(
          itemCount: 4,
          width: 25,
          itemExtent: 9.5,
          scrollOffsetItems: 0.75,
        ),
        data: data,
      );

      for (final time in [
        base,
        base + 30000,
        base + 120000,
        base + 210000,
        base + 240000,
      ]) {
        final localX = transform.timeToLocalX(time);
        expect(transform.localXToTime(localX), closeTo(time, 1));
      }
    });

    test('clamps timeline endpoints and rejects empty or unordered data', () {
      const base = 1704067200000;
      final data = _data([base, base + 60000]);
      final transform = ChartXTransform(
        viewport: ChartViewport(itemCount: 2, width: 16, itemExtent: 8),
        data: data,
      );

      expect(transform.timeToDataPosition(base - 1), 0.5);
      expect(transform.timeToDataPosition(base + 120000), 1.5);
      expect(transform.dataPositionToTime(-10), base);
      expect(transform.dataPositionToTime(10), base + 60000);

      final empty = _StableData(const []);
      final emptyTransform = ChartXTransform(
        viewport: ChartViewport(),
        data: empty,
      );
      expect(() => emptyTransform.timeToDataPosition(base), throwsStateError);
      expect(() => emptyTransform.dataPositionToTime(0), throwsStateError);
      expect(() => emptyTransform.localXToNearestIndex(0), throwsStateError);

      expect(
        () => ChartXTransform(
          viewport: ChartViewport(itemCount: 1),
          data: data,
        ),
        throwsArgumentError,
      );
      expect(
        () => ChartXTransform(
          viewport: ChartViewport(itemCount: 2),
          data: _StableData([data.data.last, data.data.first]),
        ),
        throwsArgumentError,
      );
    });

    test('rejects non-finite continuous coordinates', () {
      final data = _data([0]);
      final transform = ChartXTransform(
        viewport: ChartViewport(itemCount: 1, width: 8, itemExtent: 8),
        data: data,
      );

      expect(
        () => transform.dataPositionToLocalX(double.nan),
        throwsArgumentError,
      );
      expect(
        () => transform.localXToDataPosition(double.infinity),
        throwsArgumentError,
      );
      expect(
        () => transform.dataPositionToTime(double.negativeInfinity),
        throwsArgumentError,
      );
    });
  });

  group('ChartPriceTransform', () {
    test('maps high to top, low to bottom, and midpoint linearly', () {
      final transform = ChartPriceTransform(
        minPrice: 100,
        maxPrice: 200,
        top: 20,
        bottom: 220,
      );

      expect(transform.priceToLocalY(200), 20);
      expect(transform.priceToLocalY(150), 120);
      expect(transform.priceToLocalY(100), 220);
      expect(transform.localYToPrice(20), 200);
      expect(transform.localYToPrice(120), 150);
      expect(transform.localYToPrice(220), 100);
    });

    test('round-trips and extrapolates outside the visible panel', () {
      final transform = ChartPriceTransform(
        minPrice: 63000,
        maxPrice: 65000,
        top: 12.5,
        bottom: 312.5,
      );

      for (final price in <double>[
        62000,
        63000,
        64123.45,
        65000,
        66000,
      ]) {
        final localY = transform.priceToLocalY(price);
        expect(transform.localYToPrice(localY), closeTo(price, 1e-9));
      }
    });

    test('uses structural equality and rejects degenerate ranges', () {
      final first = ChartPriceTransform(
        minPrice: 100,
        maxPrice: 200,
        top: 0,
        bottom: 100,
      );
      final second = ChartPriceTransform(
        minPrice: 100,
        maxPrice: 200,
        top: 0,
        bottom: 100,
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(
        () => ChartPriceTransform(
          minPrice: 100,
          maxPrice: 100,
          top: 0,
          bottom: 100,
        ),
        throwsArgumentError,
      );
      expect(
        () => ChartPriceTransform(
          minPrice: 100,
          maxPrice: 200,
          top: 20,
          bottom: 20,
        ),
        throwsArgumentError,
      );
      expect(
        () => first.priceToLocalY(double.nan),
        throwsArgumentError,
      );
    });
  });
}

_StableData _data(List<int> openTimes) => _StableData(
      [
        for (var index = 0; index < openTimes.length; index++)
          _kline(openTimes[index], index),
      ],
    );

Kline _kline(int openTime, int index) => Kline(
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
    );

final class _StableData implements VersionedKlineData {
  _StableData(this.data);

  @override
  final List<Kline> data;

  @override
  KlineDataVersion get version => KlineDataVersion.zero;
}
