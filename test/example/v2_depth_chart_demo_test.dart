import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/k_chart_theme.dart';

// The runnable demo is intentionally outside the package's public API.
// ignore: avoid_relative_lib_imports
import '../../example/lib/v2_depth_chart_demo.dart';

void main() {
  test('depth example creates normalized deterministic bid and ask levels', () {
    final first = buildDemoDepthBook(80000);
    final second = buildDemoDepthBook(80000);

    expect(first, second);
    expect(first.bids, hasLength(32));
    expect(first.asks, hasLength(32));
    expect(first.bestBid!.price, lessThan(first.bestAsk!.price));
    expect(first.spread, greaterThan(0));
    expect(() => buildDemoDepthBook(0), throwsArgumentError);
    expect(
      () => buildDemoDepthBook(80000, levelCount: 1001),
      throwsArgumentError,
    );
  });

  testWidgets('depth example paints a Chinese top-of-book summary',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 430,
            child: V2DepthChartDemo(
              referencePrice: 80000,
              theme: KChartTheme.light(),
              version: 1,
            ),
          ),
        ),
      ),
    );

    expect(find.text('V2 买卖深度'), findsOneWidget);
    expect(find.byKey(const ValueKey('v2-depth-summary')), findsOneWidget);
    expect(find.textContaining('买一'), findsOneWidget);
    expect(find.textContaining('卖一'), findsOneWidget);
    expect(find.textContaining('价差'), findsOneWidget);
    expect(find.byKey(const ValueKey('v2-depth-canvas')), findsOneWidget);
    expect(find.text('已应用初始深度快照'), findsOneWidget);
    expect(find.textContaining('盘口 1000 买档 + 1000 卖档'), findsOneWidget);
    expect(find.textContaining('每侧最多绘制 160 点'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('depth-simulate-delta')));
    await tester.pump();
    expect(find.textContaining('已合并增量'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('depth-simulate-gap')));
    await tester.pump();
    expect(find.textContaining('检测到 update ID 缺口'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('depth-recover-snapshot')),
          )
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const ValueKey('depth-recover-snapshot')));
    await tester.pump();
    expect(find.textContaining('已重新同步'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
