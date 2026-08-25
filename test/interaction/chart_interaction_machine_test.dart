import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/interaction/interaction.dart';
import 'package:m_k_chart/src/viewport/viewport.dart';

void main() {
  group('ChartInteractionMachine pan', () {
    test('converts chart-local delta to bounded data-slot scrolling', () {
      final machine = ChartInteractionMachine();
      final viewport = _viewport(scrollOffsetItems: 20);

      expect(machine.beginPan(viewport), isTrue);
      final moved = machine.updatePan(16);

      expect(machine.mode, ChartInteractionMode.panning);
      expect(moved?.viewport.scrollOffsetItems, 22);
      expect(machine.updatePan(-1000)?.viewport.scrollOffsetItems, 0);
      expect(machine.endPan(), isTrue);
      expect(machine.isIdle, isTrue);
      expect(machine.updatePan(10), isNull);
    });

    test('cancel returns to idle without creating another gesture', () {
      final machine = ChartInteractionMachine()..beginPan(_viewport());

      expect(machine.cancelPan(), isTrue);
      expect(machine.isIdle, isTrue);
      expect(machine.cancelPan(), isFalse);
    });
  });

  group('ChartInteractionMachine focus scale', () {
    test('keeps the focal data position stable while zooming', () {
      final machine = ChartInteractionMachine();
      final viewport = _viewport(scrollOffsetItems: 20);
      const focalX = 80.0;
      final anchor =
          viewport.visibleLeftDataPosition + focalX / viewport.itemExtent;

      expect(
        machine.beginScale(viewport: viewport, focalLocalX: focalX),
        isTrue,
      );
      final zoomed = machine.updateScale(scale: 2, focalLocalX: focalX)!;
      final next = zoomed.viewport;

      expect(next.itemExtent, 16);
      expect(next.scrollOffsetItems, 25);
      expect(
        next.visibleLeftDataPosition + focalX / next.itemExtent,
        closeTo(anchor, 1e-12),
      );
      expect(machine.endScale(), isTrue);
      expect(machine.isIdle, isTrue);
    });

    test('supports focal movement and clamps zoom/scroll boundaries', () {
      final machine = ChartInteractionMachine();
      final viewport = _viewport(scrollOffsetItems: 20);

      machine.beginScale(viewport: viewport, focalLocalX: 80);
      final zoomed = machine.updateScale(scale: 100, focalLocalX: 100)!;

      expect(zoomed.viewport.itemExtent, viewport.maxItemExtent);
      expect(
        zoomed.viewport.scrollOffsetItems,
        inInclusiveRange(0, zoomed.viewport.maxScrollOffsetItems),
      );
    });
  });

  group('ChartInteractionMachine mutual exclusion', () {
    test('never preempts an active winner with a conflicting begin', () {
      final machine = ChartInteractionMachine();
      final viewport = _viewport();

      expect(machine.beginPan(viewport), isTrue);
      expect(
        machine.beginScale(viewport: viewport, focalLocalX: 10),
        isFalse,
      );
      expect(machine.beginCrosshair(localX: 10, localY: 20), isNull);
      expect(machine.mode, ChartInteractionMode.panning);

      machine.cancelActive();
      expect(
        machine.beginCrosshair(localX: 10, localY: 20),
        const ChartCrosshairIntent.show(localX: 10, localY: 20),
      );
      expect(machine.beginPan(viewport), isFalse);
      expect(machine.cancelActive(), const ChartCrosshairIntent.hide());
      expect(machine.isIdle, isTrue);
    });

    test('crosshair move/end emits local immutable selection state', () {
      final machine = ChartInteractionMachine();

      final shown = machine.beginCrosshair(localX: 12, localY: 34)!;
      final moved = machine.updateCrosshair(localX: 20, localY: 40)!;
      final hidden = machine.endCrosshair()!;

      expect(
        shown.state,
        const ChartCrosshairState.visible(localX: 12, localY: 34),
      );
      expect(moved.localX, 20);
      expect(moved.localY, 40);
      expect(hidden.state, const ChartCrosshairState.hidden());
      expect(machine.isIdle, isTrue);
    });

    test('rejects malformed coordinates and scale values', () {
      final machine = ChartInteractionMachine();

      expect(() => machine.updatePan(double.nan), throwsArgumentError);
      expect(
        () => machine.beginScale(
          viewport: _viewport(),
          focalLocalX: double.infinity,
        ),
        throwsArgumentError,
      );
      expect(
        () => machine.updateScale(scale: 0, focalLocalX: 10),
        throwsArgumentError,
      );
      expect(
        () => machine.beginCrosshair(localX: 0, localY: double.nan),
        throwsArgumentError,
      );
    });
  });
}

ChartViewport _viewport({double scrollOffsetItems = 10}) => ChartViewport(
      itemCount: 100,
      width: 160,
      itemExtent: 8,
      minItemExtent: 4,
      maxItemExtent: 24,
      scrollOffsetItems: scrollOffsetItems,
    );
