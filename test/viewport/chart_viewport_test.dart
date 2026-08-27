import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/viewport/viewport.dart';

void main() {
  group('ChartViewport', () {
    test('starts as an empty, latest-bound viewport', () {
      const viewport = ChartViewport.initial();

      expect(viewport.visibleRange, const VisibleIndexRange.empty());
      expect(viewport.maxScrollOffsetItems, 0);
      expect(viewport.isAtLatest, isTrue);
      expect(viewport.isAtOldest, isTrue);
    });

    test('reports the latest visible half-open index range', () {
      final viewport = ChartViewport(
        itemCount: 100,
        width: 80,
        itemExtent: 8,
      );

      expect(viewport.visibleItemCapacity, 10);
      expect(viewport.visibleRange, const VisibleIndexRange(90, 100));
      expect(viewport.maxScrollOffsetItems, 90);
      expect(viewport.isAtLatest, isTrue);
      expect(viewport.isAtOldest, isFalse);
    });

    test('includes partially visible items after fractional scrolling', () {
      final viewport = ChartViewport(
        itemCount: 100,
        width: 80,
        itemExtent: 8,
        scrollOffsetItems: 0.5,
      );

      expect(viewport.visibleRange, const VisibleIndexRange(89, 100));
      expect(viewport.visibleRange.length, 11);
      expect(viewport.visibleRange.contains(89), isTrue);
      expect(viewport.visibleRange.contains(100), isFalse);
    });

    test('keeps legacy-style virtual space after the newest item', () {
      final viewport = ChartViewport(
        itemCount: 100,
        width: 80,
        itemExtent: 8,
        trailingPaddingItems: 1.5,
      );

      expect(viewport.visibleRightDataPosition, 101.5);
      expect(viewport.visibleLeftDataPosition, 91.5);
      expect(viewport.visibleRange, const VisibleIndexRange(91, 100));
      expect(viewport.maxScrollOffsetItems, 91.5);
      expect(
        viewport.copyWith(scrollOffsetItems: 500).visibleLeftDataPosition,
        0,
      );
    });

    test('clamps scrolling at both latest and oldest boundaries', () {
      final viewport = ChartViewport(
        itemCount: 100,
        width: 80,
        itemExtent: 8,
      );

      final latest = viewport.scrollByItems(-5);
      final oldest = viewport.scrollByItems(500);

      expect(latest.scrollOffsetItems, 0);
      expect(oldest.scrollOffsetItems, 90);
      expect(oldest.visibleRange, const VisibleIndexRange(0, 10));
      expect(oldest.isAtOldest, isTrue);
    });

    test('clamps zoom and recomputes capacity and scroll boundaries', () {
      final viewport = ChartViewport(
        itemCount: 100,
        width: 80,
        itemExtent: 8,
        minItemExtent: 4,
        maxItemExtent: 20,
        scrollOffsetItems: 90,
      );

      final zoomedOut = viewport.zoomTo(1);
      final zoomedIn = viewport.zoomTo(50);

      expect(zoomedOut.itemExtent, 4);
      expect(zoomedOut.visibleItemCapacity, 20);
      expect(zoomedOut.scrollOffsetItems, 80);
      expect(zoomedIn.itemExtent, 20);
      expect(zoomedIn.visibleItemCapacity, 4);
      expect(zoomedIn.scrollOffsetItems, 90);
    });

    test('normalizes scroll when width or item count changes', () {
      final viewport = ChartViewport(
        itemCount: 100,
        width: 80,
        itemExtent: 8,
        scrollOffsetItems: 90,
      );

      final widened = viewport.copyWith(width: 160);
      final shortened = viewport.copyWith(itemCount: 5);

      expect(widened.scrollOffsetItems, 80);
      expect(widened.visibleRange, const VisibleIndexRange(0, 20));
      expect(shortened.scrollOffsetItems, 0);
      expect(shortened.visibleRange, const VisibleIndexRange(0, 5));
    });

    test('small datasets remain latest-aligned without artificial scrolling',
        () {
      final viewport = ChartViewport(
        itemCount: 5,
        width: 80,
        itemExtent: 8,
        scrollOffsetItems: 20,
      );

      expect(viewport.scrollOffsetItems, 0);
      expect(viewport.maxScrollOffsetItems, 0);
      expect(viewport.visibleRange, const VisibleIndexRange(0, 5));
    });

    test('uses structural equality for deterministic state comparisons', () {
      final first = ChartViewport(itemCount: 100, width: 80);
      final second = ChartViewport(itemCount: 100, width: 80);

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first.toString(), contains('itemCount: 100'));
    });

    test('rejects invalid dimensions and non-finite inputs', () {
      expect(() => ChartViewport(itemCount: -1), throwsArgumentError);
      expect(() => ChartViewport(width: -1), throwsArgumentError);
      expect(() => ChartViewport(width: double.infinity), throwsArgumentError);
      expect(() => ChartViewport(itemExtent: 0), throwsArgumentError);
      expect(() => ChartViewport(minItemExtent: 0), throwsArgumentError);
      expect(
        () => ChartViewport(minItemExtent: 10, maxItemExtent: 5),
        throwsArgumentError,
      );
      expect(
        () => ChartViewport(scrollOffsetItems: double.nan),
        throwsArgumentError,
      );
      expect(
        () => ChartViewport(trailingPaddingItems: -1),
        throwsArgumentError,
      );
      expect(
        () => ChartViewport().scrollByItems(double.infinity),
        throwsArgumentError,
      );
    });
  });

  group('VisibleIndexRange', () {
    test('uses half-open containment and value equality', () {
      const range = VisibleIndexRange(2, 5);

      expect(range.length, 3);
      expect(range.isNotEmpty, isTrue);
      expect(range.contains(2), isTrue);
      expect(range.contains(4), isTrue);
      expect(range.contains(5), isFalse);
      expect(range, const VisibleIndexRange(2, 5));
    });
  });
}
