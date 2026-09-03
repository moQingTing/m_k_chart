import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../lib/v2_chart_demo.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('V2 offline chart completes its primary interaction flow',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: V2TradingChartDemo(loadOnStart: false)),
    );
    await tester.pumpAndSettle();

    expect(find.text('V2 交易图表'), findsOneWidget);
    expect(find.byKey(const ValueKey('market-summary')), findsOneWidget);
    expect(find.byKey(const ValueKey('period-1m')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('open-fullscreen-demo')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('close-fullscreen-demo')), findsOneWidget);

    final chartCanvas = find.byKey(const ValueKey('v2-chart-canvas'));
    await tester.scrollUntilVisible(
      chartCanvas,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final chartTopLeft = tester.getTopLeft(chartCanvas);
    await tester.tapAt(chartTopLeft + const Offset(100, 80));
    await tester.pump();
    expect(find.byKey(const ValueKey('crosshair-details')), findsOneWidget);
    expect(find.byKey(const ValueKey('crosshair-time-label')), findsOneWidget);

    await tester.timedDrag(
      chartCanvas,
      const Offset(280, 0),
      const Duration(milliseconds: 700),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('crosshair-details')), findsNothing);
    final returnToLatest = find.byKey(const ValueKey('latest-price-return'));
    expect(returnToLatest, findsOneWidget);
    await tester.tap(returnToLatest);
    await tester.pump();
    expect(returnToLatest, findsNothing);

    await tester.tap(find.byKey(const ValueKey('close-fullscreen-demo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('period-5m')));
    await tester.pump();
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const ValueKey('period-5m')))
          .selected,
      isTrue,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
