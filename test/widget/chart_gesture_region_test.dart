import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/interaction/interaction.dart';
import 'package:m_k_chart/src/viewport/viewport.dart';
import 'package:m_k_chart/src/widget/widget.dart';

void main() {
  testWidgets('one pointer pans without producing scale or crosshair intent',
      (tester) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.build());

    await tester.drag(find.byKey(_Harness.targetKey), const Offset(48, 0));
    await tester.pump();

    final viewportIntents = harness.intents.whereType<ChartViewportIntent>();
    expect(viewportIntents, isNotEmpty);
    expect(harness.viewport.scrollOffsetItems, greaterThan(20));
    expect(harness.viewport.itemExtent, 8);
    expect(harness.intents.whereType<ChartCrosshairIntent>(), isEmpty);
    expect(harness.machine.isIdle, isTrue);
  });

  testWidgets('two pointers scale around their chart-local focal point',
      (tester) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.build());
    final center = tester.getCenter(find.byKey(_Harness.targetKey));
    final first = await tester.startGesture(center + const Offset(-40, 0));
    final second = await tester.startGesture(center + const Offset(40, 0));

    await first.moveTo(center + const Offset(-70, 0));
    await second.moveTo(center + const Offset(70, 0));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pump();

    expect(harness.intents.whereType<ChartViewportIntent>(), isNotEmpty);
    expect(harness.viewport.itemExtent, greaterThan(8));
    expect(harness.intents.whereType<ChartCrosshairIntent>(), isEmpty);
    expect(harness.machine.isIdle, isTrue);
  });

  testWidgets('stationary long press wins and owns crosshair until release',
      (tester) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.build());
    final center = tester.getCenter(find.byKey(_Harness.targetKey));
    final gesture = await tester.startGesture(center);

    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 10));
    expect(harness.machine.mode, ChartInteractionMode.crosshair);
    expect(
      harness.intents.whereType<ChartCrosshairIntent>().last.isActive,
      isTrue,
    );
    expect(harness.intents.whereType<ChartViewportIntent>(), isEmpty);

    await gesture.moveBy(const Offset(20, 10));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    final crosshair =
        harness.intents.whereType<ChartCrosshairIntent>().toList();
    expect(crosshair.length, greaterThanOrEqualTo(3));
    expect(crosshair.last, const ChartCrosshairIntent.hide());
    expect(harness.machine.isIdle, isTrue);
  });
}

final class _Harness {
  static const targetKey = Key('gesture-target');

  final machine = ChartInteractionMachine();
  final intents = <ChartInteractionIntent>[];
  ChartViewport viewport = ChartViewport(
    itemCount: 100,
    width: 300,
    itemExtent: 8,
    minItemExtent: 4,
    maxItemExtent: 24,
    scrollOffsetItems: 20,
  );

  Widget build() => Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            key: targetKey,
            width: 300,
            height: 300,
            child: ChartGestureRegion(
              machine: machine,
              viewport: () => viewport,
              onIntent: (intent) {
                intents.add(intent);
                if (intent case ChartViewportIntent(:final viewport)) {
                  this.viewport = viewport;
                }
              },
              child: const ColoredBox(color: Color(0xff000000)),
            ),
          ),
        ),
      );
}
