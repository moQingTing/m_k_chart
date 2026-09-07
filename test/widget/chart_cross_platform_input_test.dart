import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/interaction/interaction.dart';
import 'package:m_k_chart/src/viewport/viewport.dart';
import 'package:m_k_chart/src/widget/widget.dart';

void main() {
  testWidgets('vertical drag yields to parent while horizontal drag pans chart',
      (tester) async {
    final parent = ScrollController();
    final harness = _InputHarness(keyName: 'nested-chart');
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 320,
          height: 500,
          child: ListView(
            controller: parent,
            children: <Widget>[
              const SizedBox(height: 80),
              harness.build(width: 300, height: 200),
              const SizedBox(height: 800),
            ],
          ),
        ),
      ),
    );

    await tester.drag(harness.finder, const Offset(0, -120));
    await tester.pump();

    expect(parent.offset, greaterThan(0));
    expect(harness.viewportIntents, isEmpty);

    final parentBeforeHorizontal = parent.offset;
    await tester.drag(harness.finder, const Offset(60, 0));
    await tester.pump();

    expect(parent.offset, parentBeforeHorizontal);
    expect(harness.viewport.scrollOffsetItems, greaterThan(20));
  });

  testWidgets('two chart instances isolate touch and desktop navigation',
      (tester) async {
    final first = _InputHarness(keyName: 'first-chart');
    final second = _InputHarness(keyName: 'second-chart');
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: <Widget>[
            first.build(width: 200, height: 240),
            second.build(width: 200, height: 240),
          ],
        ),
      ),
    );

    await tester.drag(first.finder, const Offset(40, 0));
    await tester.pump();

    expect(first.viewport.scrollOffsetItems, greaterThan(20));
    expect(second.viewport.scrollOffsetItems, 20);
    final firstAfterTouch = first.viewport;

    final secondCenter = tester.getCenter(second.finder);
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: secondCenter,
        kind: PointerDeviceKind.mouse,
        scrollDelta: const Offset(0, -100),
      ),
    );
    await tester.pump();

    expect(second.viewport.itemExtent, greaterThan(8));
    expect(first.viewport, firstAfterTouch);
  });

  testWidgets('landscape nested chart keeps hover coordinates local',
      (tester) async {
    final harness = _InputHarness(keyName: 'landscape-chart');
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 50, top: 40),
            child: harness.build(width: 600, height: 260),
          ),
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    final topLeft = tester.getTopLeft(harness.finder);

    await mouse.addPointer(location: topLeft + const Offset(300, 120));
    await tester.pump();
    await mouse.moveTo(topLeft + const Offset(420, 140));
    await tester.pump();

    final crosshair = harness.crosshairIntents.last;
    expect(crosshair.localX, closeTo(420, 1e-12));
    expect(crosshair.localY, closeTo(140, 1e-12));
    expect(crosshair.localX, isNot(closeTo(470, 1e-12)));

    await mouse.moveTo(const Offset(10, 10));
    await tester.pump();
    expect(harness.crosshairIntents.last, const ChartCrosshairIntent.hide());
  });

  testWidgets('disposing a hovered chart clears desktop selection',
      (tester) async {
    final harness = _InputHarness(keyName: 'disposed-hover-chart');
    await tester.pumpWidget(harness.app(width: 320, height: 240));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);

    final center = tester.getCenter(harness.finder);
    await mouse.addPointer(location: center);
    await mouse.moveTo(center + const Offset(1, 0));
    await tester.pump();
    expect(harness.crosshairIntents.last.isActive, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(harness.crosshairIntents.last, const ChartCrosshairIntent.hide());
  });

  testWidgets('portrait to landscape resize preserves normalized navigation',
      (tester) async {
    final harness = _InputHarness(keyName: 'resizable-chart');
    await tester.pumpWidget(harness.app(width: 240, height: 360));

    await tester.drag(harness.finder, const Offset(40, 0));
    await tester.pump();
    final scrollBeforeResize = harness.viewport.scrollOffsetItems;

    await tester.pumpWidget(harness.app(width: 600, height: 260));
    await tester.pump();

    expect(harness.viewport.width, 600);
    expect(harness.viewport.scrollOffsetItems, scrollBeforeResize);
    expect(tester.getSize(harness.finder), const Size(600, 260));

    await tester.drag(harness.finder, const Offset(-100, 0));
    await tester.pump();
    expect(harness.viewport.scrollOffsetItems, lessThan(scrollBeforeResize));
  });

  testWidgets('mouse wheel zooms at focus and horizontal wheel pans',
      (tester) async {
    final harness = _InputHarness(keyName: 'mouse-chart');
    await tester.pumpWidget(harness.app(width: 320, height: 240));
    final center = tester.getCenter(harness.finder);

    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: center,
        kind: PointerDeviceKind.mouse,
        scrollDelta: const Offset(0, -120),
      ),
    );
    await tester.pump();
    final afterZoom = harness.viewport;

    expect(afterZoom.itemExtent, greaterThan(8));
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: center,
        kind: PointerDeviceKind.mouse,
        scrollDelta: const Offset(-48, 0),
      ),
    );
    await tester.pump();

    expect(
      harness.viewport.scrollOffsetItems,
      greaterThan(afterZoom.scrollOffsetItems),
    );
    expect(harness.machine.isIdle, isTrue);
  });

  testWidgets('trackpad pan zoom preserves one isolated interaction sequence',
      (tester) async {
    final harness = _InputHarness(keyName: 'trackpad-chart');
    await tester.pumpWidget(harness.app(width: 320, height: 240));
    final center = tester.getCenter(harness.finder);

    await tester.sendEventToBinding(
      PointerPanZoomStartEvent(
        pointer: 61,
        position: center,
      ),
    );
    await tester.sendEventToBinding(
      PointerPanZoomUpdateEvent(
        pointer: 61,
        position: center,
        pan: const Offset(40, 0),
        panDelta: const Offset(40, 0),
        scale: 1.5,
      ),
    );
    await tester.pump();

    expect(harness.viewport.itemExtent, closeTo(12, 1e-12));
    expect(harness.machine.mode, ChartInteractionMode.scaling);

    await tester.sendEventToBinding(
      PointerPanZoomEndEvent(pointer: 61, position: center),
    );
    await tester.pump();

    expect(harness.machine.isIdle, isTrue);
    expect(harness.crosshairIntents, isEmpty);
  });

  testWidgets('input policy can leave wheel and trackpad signals untouched',
      (tester) async {
    final harness = _InputHarness(
      keyName: 'disabled-pointer-chart',
      pointerInputPolicy: const ChartPointerInputPolicy(
        mouseHoverCrosshair: false,
        mouseWheelZoom: false,
        trackpadPanZoom: false,
      ),
    );
    await tester.pumpWidget(harness.app(width: 320, height: 240));
    final center = tester.getCenter(harness.finder);
    final before = harness.viewport;

    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: center,
        kind: PointerDeviceKind.mouse,
        scrollDelta: const Offset(0, -100),
      ),
    );
    await tester.sendEventToBinding(
      PointerPanZoomStartEvent(pointer: 72, position: center),
    );
    await tester.sendEventToBinding(
      PointerPanZoomUpdateEvent(
        pointer: 72,
        position: center,
        scale: 2,
      ),
    );
    await tester.sendEventToBinding(
      PointerPanZoomEndEvent(pointer: 72, position: center),
    );
    await tester.pump();

    expect(harness.viewport, before);
    expect(harness.intents, isEmpty);
  });
}

final class _InputHarness {
  _InputHarness({
    required this.keyName,
    this.pointerInputPolicy = const ChartPointerInputPolicy(),
  });

  final String keyName;
  final ChartPointerInputPolicy pointerInputPolicy;
  final ChartInteractionMachine machine = ChartInteractionMachine();
  final ChartNavigationMachine navigationMachine = ChartNavigationMachine();
  final List<ChartInteractionIntent> intents = <ChartInteractionIntent>[];
  ChartViewport viewport = ChartViewport(
    itemCount: 200,
    width: 300,
    itemExtent: 8,
    minItemExtent: 4,
    maxItemExtent: 24,
    scrollOffsetItems: 20,
  );

  Finder get finder => find.byKey(ValueKey<String>(keyName));

  Iterable<ChartViewportIntent> get viewportIntents =>
      intents.whereType<ChartViewportIntent>();

  List<ChartCrosshairIntent> get crosshairIntents =>
      intents.whereType<ChartCrosshairIntent>().toList();

  Widget app({required double width, required double height}) => Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: build(width: width, height: height)),
      );

  Widget build({required double width, required double height}) {
    viewport = viewport.copyWith(width: width);
    return SizedBox(
      key: ValueKey<String>(keyName),
      width: width,
      height: height,
      child: ChartGestureRegion(
        machine: machine,
        navigationMachine: navigationMachine,
        viewport: () => viewport,
        pointerInputPolicy: pointerInputPolicy,
        onIntent: (intent) {
          intents.add(intent);
          if (intent case ChartViewportIntent(:final viewport)) {
            this.viewport = viewport;
          }
        },
        child: const ColoredBox(color: Color(0xff000000)),
      ),
    );
  }
}
