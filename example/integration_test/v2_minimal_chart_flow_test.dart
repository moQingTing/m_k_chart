import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:m_k_chart/src/widget/k_chart_surface.dart';
import 'package:m_k_chart_example/v2_minimal_chart_main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('最小接入示例在模拟器完成尾柱更新、追加和选中', (tester) async {
    final now = DateTime.utc(2026, 10, 22, 12).millisecondsSinceEpoch;
    await tester.pumpWidget(
      MaterialApp(
        home: V2MinimalChartExample(nowMilliseconds: () => now),
      ),
    );
    await tester.pump();
    final surface = find.byType(KChartSurface);
    final chart = tester.widget<KChartSurface>(surface).controller;
    expect(chart.value.data.length, 60);

    await tester.tap(find.byKey(const ValueKey('minimal-replace')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('minimal-append')));
    await tester.pump();
    expect(chart.value.data.length, 61);
    expect(chart.value.data[59].isClosed, isTrue);

    await tester.tapAt(tester.getTopLeft(surface) + const Offset(120, 150));
    await tester.pump();
    await tester.pump();
    expect(chart.value.selection, isNotNull);
    expect(find.textContaining('选中 '), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(chart.isDisposed, isTrue);
  });
}
