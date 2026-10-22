import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/controller/k_chart_candidate_api.dart';
import 'package:m_k_chart/src/widget/k_chart_surface.dart';

// 示例是仓库内的独立运行入口，测试不访问网络。
// ignore: avoid_relative_lib_imports
import '../../example/lib/v2_minimal_chart_main.dart';

void main() {
  final fixedNow = DateTime.utc(2026, 10, 22, 12).millisecondsSinceEpoch;

  Future<KChartController> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: V2MinimalChartExample(nowMilliseconds: () => fixedNow),
      ),
    );
    await tester.pump();
    return tester.widget<KChartSurface>(find.byType(KChartSurface)).controller;
  }

  testWidgets('最小示例替换尾柱、闭合旧柱并追加新柱，旧快照不变', (tester) async {
    final chart = await mount(tester);
    final before = chart.value.data;
    final last = before.last;
    expect(before.length, 60);
    expect(find.textContaining('K 线 60 根'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('minimal-replace')));
    await tester.pump();
    expect(chart.value.data.length, 60);
    expect(chart.value.data.last.close, last.close + 1);
    expect(before.last, same(last));

    await tester.tap(find.byKey(const ValueKey('minimal-append')));
    await tester.pump();
    expect(chart.value.data.length, 61);
    expect(chart.value.data[59].isClosed, isTrue);
    expect(chart.value.data.last.openTime, last.openTime + 60000);
    expect(chart.value.data.last.isClosed, isFalse);
    expect(find.textContaining('K 线 61 根'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(chart.isDisposed, isTrue);
  });

  testWidgets('最小示例将图表点击选中回传给宿主', (tester) async {
    final chart = await mount(tester);
    final surface = find.byType(KChartSurface);
    await tester.tapAt(tester.getTopLeft(surface) + const Offset(120, 150));
    await tester.pump();
    await tester.pump(); // KChart 的宿主回调在帧后交付，下一帧再检查文案。

    expect(chart.value.selection, isNotNull);
    expect(find.textContaining('选中 '), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
