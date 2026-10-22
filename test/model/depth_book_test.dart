import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/model/model.dart';

void main() {
  test('depth book freezes normalized levels and publishes top-of-book data',
      () {
    final bids = <DepthLevel>[
      DepthLevel(price: 99, quantity: 2),
      DepthLevel(price: 98, quantity: 3),
    ];
    final asks = <DepthLevel>[
      DepthLevel(price: 101, quantity: 1),
      DepthLevel(price: 102, quantity: 4),
    ];
    final book = DepthBook(bids: bids, asks: asks);
    bids.clear();
    asks.clear();

    expect(book.bestBid?.price, 99);
    expect(book.bestAsk?.price, 101);
    expect(book.spread, 2);
    expect(book.midPrice, 100);
    expect(book.spreadPercent, 2);
    expect(book.bids, hasLength(2));
    expect(() => book.bids.clear(), throwsUnsupportedError);
  });

  test('cumulative curve sums each side from best price outward', () {
    final curve = DepthCurve.fromBook(
      DepthBook(
        bids: [
          DepthLevel(price: 99, quantity: 2),
          DepthLevel(price: 98, quantity: 3),
          DepthLevel(price: 97, quantity: 5),
        ],
        asks: [
          DepthLevel(price: 101, quantity: 4),
          DepthLevel(price: 102, quantity: 2),
        ],
      ),
    );

    expect(
      curve.bids.map((level) => level.cumulativeQuantity),
      [2, 5, 10],
    );
    expect(
      curve.asks.map((level) => level.cumulativeQuantity),
      [4, 6],
    );
    expect(curve.maxCumulativeQuantity, 10);
    expect(curve.bids.first.side, DepthSide.bid);
    expect(curve.asks.first.side, DepthSide.ask);
  });

  test('curve policy trims outward levels before cumulative sampling', () {
    final curve = DepthCurve.fromBook(
      _largeBook(10),
      policy: DepthCurveSamplingPolicy(
        maxRetainedLevelsPerSide: 6,
        maxRenderedPointsPerSide: 3,
      ),
    );

    expect(curve.retainedBidLevelCount, 6);
    expect(curve.retainedAskLevelCount, 6);
    expect(curve.sourceBidLevelCount, 10);
    expect(curve.sourceAskLevelCount, 10);
    expect(curve.bids.map((level) => level.price), [10000, 9998, 9995]);
    expect(curve.asks.map((level) => level.price), [10002, 10004, 10007]);
    expect(
      curve.bids.map((level) => level.cumulativeQuantity),
      [1, 3, 6],
    );
    expect(curve.bids.last.cumulativeQuantity, 6);
    expect(curve.asks.last.cumulativeQuantity, 6);
    expect(curve.maxCumulativeQuantity, 6);
    expect(curve.isTrimmed, isTrue);
    expect(curve.isSampled, isTrue);
  });

  test('curve sampling preserves full endpoints and bounds large books', () {
    final book = _largeBook(1000);
    final policy = DepthCurveSamplingPolicy(
      maxRetainedLevelsPerSide: 800,
      maxRenderedPointsPerSide: 160,
    );
    final curve = DepthCurve.fromBook(book, policy: policy);

    expect(curve.bids, hasLength(160));
    expect(curve.asks, hasLength(160));
    expect(curve.bids.first.level, same(book.bids.first));
    expect(curve.bids.last.level, same(book.bids[799]));
    expect(curve.asks.first.level, same(book.asks.first));
    expect(curve.asks.last.level, same(book.asks[799]));
    expect(curve.bids.last.cumulativeQuantity, 800);
    expect(curve.asks.last.cumulativeQuantity, 800);
    expect(
      curve.bids.map((level) => level.cumulativeQuantity),
      orderedEquals(
        [...curve.bids.map((level) => level.cumulativeQuantity)]..sort(),
      ),
    );
  });

  test('unbounded curve policy is value-stable and validates limits', () {
    const first = DepthCurveSamplingPolicy.unbounded();
    const second = DepthCurveSamplingPolicy.unbounded();

    expect(first, second);
    expect(first.hashCode, second.hashCode);
    expect(first.isUnbounded, isTrue);
    expect(
      () => DepthCurveSamplingPolicy(maxRetainedLevelsPerSide: 0),
      throwsArgumentError,
    );
    expect(
      () => DepthCurveSamplingPolicy(maxRenderedPointsPerSide: 1),
      throwsArgumentError,
    );
  });

  test('empty and one-sided books keep unavailable spread values null', () {
    final empty = DepthBook(bids: const [], asks: const []);
    final oneSided = DepthBook(
      bids: [DepthLevel(price: 99, quantity: 1)],
      asks: const [],
    );

    expect(empty.isEmpty, isTrue);
    expect(DepthCurve.fromBook(empty).maxCumulativeQuantity, 0);
    expect(oneSided.spread, isNull);
    expect(oneSided.midPrice, isNull);
    expect(oneSided.spreadPercent, isNull);
  });

  test('depth values and ordering reject malformed or crossed books', () {
    expect(
      () => DepthLevel(price: 0, quantity: 1),
      throwsArgumentError,
    );
    expect(
      () => DepthLevel(price: 1, quantity: double.nan),
      throwsArgumentError,
    );
    expect(
      () => DepthBook(
        bids: [
          DepthLevel(price: 98, quantity: 1),
          DepthLevel(price: 99, quantity: 1),
        ],
        asks: const [],
      ),
      throwsArgumentError,
    );
    expect(
      () => DepthBook(
        bids: [DepthLevel(price: 101, quantity: 1)],
        asks: [DepthLevel(price: 100, quantity: 1)],
      ),
      throwsArgumentError,
    );
  });

  test('depth books compare structurally for deterministic snapshots', () {
    DepthBook build() => DepthBook(
          bids: [DepthLevel(price: 99, quantity: 1)],
          asks: [DepthLevel(price: 101, quantity: 2)],
        );

    expect(build(), build());
    expect(build().hashCode, build().hashCode);
  });

  test('cumulative quantity rejects floating-point overflow', () {
    final book = DepthBook(
      bids: [
        DepthLevel(price: 99, quantity: double.maxFinite),
        DepthLevel(price: 98, quantity: double.maxFinite),
      ],
      asks: const [],
    );

    expect(() => DepthCurve.fromBook(book), throwsArgumentError);
  });
}

DepthBook _largeBook(int count) => DepthBook(
      bids: List<DepthLevel>.generate(
        count,
        (index) => DepthLevel(price: 10000 - index.toDouble(), quantity: 1),
      ),
      asks: List<DepthLevel>.generate(
        count,
        (index) => DepthLevel(price: 10002 + index.toDouble(), quantity: 1),
      ),
    );
