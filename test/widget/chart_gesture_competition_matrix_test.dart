import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/interaction/interaction.dart';
import 'package:m_k_chart/src/model/model.dart';
import 'package:m_k_chart/src/render/render.dart';
import 'package:m_k_chart/src/viewport/viewport.dart';
import 'package:m_k_chart/src/widget/widget.dart';

void main() {
  testWidgets('movement below touch slop leaves every interaction idle',
      (tester) async {
    final harness = _CompetitionHarness();
    await tester.pumpWidget(harness.app());
    final gesture = await tester.startGesture(tester.getCenter(harness.finder));

    await gesture.moveBy(const Offset(2, 1));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.up();
    await tester.pump();

    expect(harness.intents, isEmpty);
    expect(harness.machine.isIdle, isTrue);
  });

  testWidgets('horizontal winner pans chart and keeps parent stationary',
      (tester) async {
    final parent = ScrollController();
    final harness = _CompetitionHarness();
    await tester.pumpWidget(harness.nested(parent));

    await tester.drag(harness.finder, const Offset(80, 12));
    await tester.pump();

    expect(parent.offset, 0);
    expect(harness.viewportIntents, isNotEmpty);
    expect(harness.crosshairIntents, isEmpty);
    expect(harness.machine.isIdle, isTrue);
  });

  testWidgets('vertical winner scrolls parent without chart intent',
      (tester) async {
    final parent = ScrollController();
    final harness = _CompetitionHarness();
    await tester.pumpWidget(harness.nested(parent));

    await tester.drag(harness.finder, const Offset(12, -100));
    await tester.pump();

    expect(parent.offset, greaterThan(0));
    expect(harness.intents, isEmpty);
    expect(harness.machine.isIdle, isTrue);
  });

  testWidgets('stationary long press owns crosshair and excludes viewport',
      (tester) async {
    final harness = _CompetitionHarness();
    await tester.pumpWidget(harness.app());
    final gesture = await tester.startGesture(tester.getCenter(harness.finder));

    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 10));
    expect(harness.machine.mode, ChartInteractionMode.crosshair);
    expect(harness.viewportIntents, isEmpty);
    expect(harness.crosshairIntents.last.isActive, isTrue);

    await gesture.up();
    await tester.pump();
    expect(harness.crosshairIntents.last, const ChartCrosshairIntent.hide());
    expect(harness.machine.isIdle, isTrue);
  });

  testWidgets('drag before timeout wins pan and suppresses long press',
      (tester) async {
    final harness = _CompetitionHarness();
    await tester.pumpWidget(harness.app());
    final gesture = await tester.startGesture(tester.getCenter(harness.finder));

    await gesture.moveBy(const Offset(60, 0));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 10));
    await gesture.up();
    await tester.pump();

    expect(harness.viewportIntents, isNotEmpty);
    expect(harness.crosshairIntents, isEmpty);
    expect(harness.machine.isIdle, isTrue);
  });

  testWidgets('two pointers scale without crosshair and return to idle',
      (tester) async {
    final harness = _CompetitionHarness();
    await tester.pumpWidget(harness.app());
    final center = tester.getCenter(harness.finder);
    final first = await tester.startGesture(center + const Offset(-30, 0));
    final second = await tester.startGesture(center + const Offset(30, 0));

    await first.moveTo(center + const Offset(-70, 0));
    await second.moveTo(center + const Offset(70, 0));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pump();

    expect(harness.viewport.itemExtent, greaterThan(8));
    expect(harness.crosshairIntents, isEmpty);
    expect(harness.machine.isIdle, isTrue);
  });

  testWidgets('pointer cancellation resets the accepted pan winner',
      (tester) async {
    final harness = _CompetitionHarness();
    await tester.pumpWidget(harness.app());
    final gesture = await tester.startGesture(tester.getCenter(harness.finder));

    await gesture.moveBy(const Offset(60, 0));
    await tester.pump();
    expect(harness.machine.mode, ChartInteractionMode.panning);

    await gesture.cancel();
    await tester.pump();
    expect(harness.machine.isIdle, isTrue);
    expect(harness.crosshairIntents, isEmpty);
  });

  testWidgets('overlay tap owns the tap and suppresses chart details',
      (tester) async {
    final harness = _CompetitionHarness(withTradeOverlay: true);
    await tester.pumpWidget(harness.app());

    await tester
        .tapAt(tester.getTopLeft(harness.finder) + const Offset(150, 110));
    await tester.pump();

    expect(harness.overlayTaps, hasLength(1));
    expect(harness.chartTaps, isEmpty);
  });

  testWidgets('tap away from overlay keeps the normal chart tap route',
      (tester) async {
    final harness = _CompetitionHarness(withTradeOverlay: true);
    await tester.pumpWidget(harness.app());

    await tester
        .tapAt(tester.getTopLeft(harness.finder) + const Offset(150, 40));
    await tester.pump();

    expect(harness.overlayTaps, isEmpty);
    expect(harness.chartTaps, hasLength(1));
  });

  testWidgets('overlay vertical drag excludes viewport and parent scroll',
      (tester) async {
    final parent = ScrollController();
    final harness = _CompetitionHarness(withTradeOverlay: true);
    await tester.pumpWidget(harness.nested(parent));
    final start = tester.getTopLeft(harness.finder) + const Offset(150, 110);

    final gesture = await tester.startGesture(start);
    await gesture.moveBy(const Offset(2, -70));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(harness.overlayDragStarts, hasLength(1));
    expect(harness.overlayDragUpdates, isNotEmpty);
    expect(harness.overlayDragEnds, hasLength(1));
    expect(harness.viewportIntents, isEmpty);
    expect(parent.offset, 0);
    expect(harness.machine.isIdle, isTrue);
  });
}

final class _CompetitionHarness {
  _CompetitionHarness({this.withTradeOverlay = false});

  static const _key = Key('competition-chart');

  final bool withTradeOverlay;

  final machine = ChartInteractionMachine();
  final navigationMachine = ChartNavigationMachine();
  final intents = <ChartInteractionIntent>[];
  final chartTaps = <Offset>[];
  final overlayTaps = <ChartTradeOverlayHit>[];
  final overlayDragStarts = <Offset>[];
  final overlayDragUpdates = <Offset>[];
  final overlayDragEnds = <ChartTradeOverlayHit>[];
  ChartViewport viewport = ChartViewport(
    itemCount: 200,
    width: 300,
    itemExtent: 8,
    minItemExtent: 4,
    maxItemExtent: 24,
    scrollOffsetItems: 20,
  );

  Finder get finder => find.byKey(_key);
  List<ChartViewportIntent> get viewportIntents =>
      intents.whereType<ChartViewportIntent>().toList();
  List<ChartCrosshairIntent> get crosshairIntents =>
      intents.whereType<ChartCrosshairIntent>().toList();

  Widget app() => Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: chart()),
      );

  Widget nested(ScrollController parent) => Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 320,
          height: 500,
          child: ListView(
            controller: parent,
            children: <Widget>[
              chart(),
              const SizedBox(height: 800),
            ],
          ),
        ),
      );

  Widget chart() => SizedBox(
        key: _key,
        width: 300,
        height: 220,
        child: ChartGestureRegion(
          machine: machine,
          navigationMachine: navigationMachine,
          viewport: () => viewport,
          onIntent: (intent) {
            intents.add(intent);
            if (intent case ChartViewportIntent(:final viewport)) {
              this.viewport = viewport;
            }
          },
          onTapUp: chartTaps.add,
          tradeOverlayGestures: withTradeOverlay
              ? ChartTradeOverlayGestureCallbacks(
                  hitTest: _overlayHitTest,
                  onTap: overlayTaps.add,
                  onDragStart: (hit, position) =>
                      overlayDragStarts.add(position),
                  onDragUpdate: (hit, position) =>
                      overlayDragUpdates.add(position),
                  onDragEnd: overlayDragEnds.add,
                )
              : null,
          child: const ColoredBox(color: Color(0xff000000)),
        ),
      );

  ChartTradeOverlayHit? _overlayHitTest(Offset position) =>
      (position.dy - 110).abs() <= 12
          ? ChartTradeOverlayHit(
              id: 'entry',
              kind: ChartTradeOverlayKind.priceLine,
              side: ChartOverlaySide.buy,
              price: 100,
              distance: (position.dy - 110).abs(),
            )
          : null;
}
