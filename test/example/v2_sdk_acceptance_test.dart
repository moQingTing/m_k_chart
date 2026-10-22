import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/controller/k_chart_candidate_api.dart';
import 'package:m_k_chart/src/widget/k_chart_surface.dart';

// 真实验收页面使用受控 HTTP 替身，测试不访问外部网络。
// ignore: avoid_relative_lib_imports
import '../../example/lib/binance_market_data_client.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/drawing/v2_demo_drawing_snapshot_store.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/market/v2_demo_market_data_source.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/v2_sdk_acceptance_main.dart';
import '../support/v2_kline_fixture.dart';

final class _Client extends BinanceMarketDataClient {
  final requests = <Completer<List<Kline>>>[];
  final limits = <int>[];

  @override
  Future<List<Kline>> candles({
    required String symbol,
    required KlineInterval interval,
    int limit = 180,
  }) {
    limits.add(limit);
    final request = Completer<List<Kline>>();
    requests.add(request);
    return request.future;
  }
}

final class _MemorySnapshotStore implements V2DemoDrawingSnapshotStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String snapshotJson) async {
    values[key] = snapshotJson;
  }
}

final class _CancellableClient implements V2DemoCancelableMarketDataSource {
  final requests = <Completer<List<Kline>>>[];
  int cancellations = 0;

  @override
  String get displayName => '可取消源';

  @override
  V2DemoMarketRequest<List<Kline>> requestCandles({
    required String symbol,
    required KlineInterval interval,
    int limit = 180,
  }) {
    final request = Completer<List<Kline>>();
    requests.add(request);
    return V2DemoMarketRequest(
      result: request.future,
      cancel: () => cancellations++,
    );
  }

  @override
  V2DemoMarketRequest<V2MarketTicker?> requestTicker({
    required String symbol,
  }) =>
      V2DemoMarketRequest(result: Future.value(null), cancel: () {});

  @override
  Future<List<Kline>> candles({
    required String symbol,
    required KlineInterval interval,
    int limit = 180,
  }) =>
      requestCandles(symbol: symbol, interval: interval, limit: limit).result;

  @override
  Future<V2MarketTicker?> ticker({required String symbol}) =>
      requestTicker(symbol: symbol).result;
}

void main() {
  final data = buildV2KlineFixture(180);

  testWidgets('候选页暂停时取消可取消源请求，恢复后由新请求加载', (tester) async {
    final source = _CancellableClient();
    addTearDown(() {
      for (final request in source.requests) {
        if (!request.isCompleted) request.complete(data);
      }
    });
    await tester.pumpWidget(
      MaterialApp(home: V2SdkAcceptancePage(client: source)),
    );
    await tester.tap(find.byKey(const ValueKey('acceptance-binance')));
    await tester.pump();
    expect(source.requests, hasLength(1));
    expect(find.text('可取消源 实时'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('acceptance-pause')));
    await tester.pump();
    expect(source.cancellations, 1);
    source.requests.first.complete(data);
    await tester.pump();
    final controller =
        tester.widget<KChartSurface>(find.byType(KChartSurface)).controller;
    expect(controller.value.data, isEmpty);

    await tester.tap(find.byKey(const ValueKey('acceptance-pause')));
    await tester.pump();
    expect(source.requests, hasLength(2));
    source.requests.last.complete(data);
    await tester.pump();
    expect(controller.value.data, hasLength(180));
    expect(tester.takeException(), isNull);
  });

  Future<void> mount(
    WidgetTester tester,
    _Client client, {
    V2DemoDrawingSnapshotStore? drawingSnapshotStore,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: V2SdkAcceptancePage(
          client: client,
          nowMilliseconds: () => data.last.openTime,
          drawingSnapshotStore: drawingSnapshotStore,
        ),
      ),
    );
    await tester.pump();
  }

  KChartController chart(WidgetTester tester) =>
      tester.widget<KChartSurface>(find.byType(KChartSurface)).controller;
  Future<void> tap(WidgetTester tester, String action) async {
    await tester.tap(find.byKey(ValueKey('acceptance-$action')));
    await tester.pump();
  }

  testWidgets('默认无网络，每秒替换、五秒新增，所选数据仍保留', (tester) async {
    final client = _Client();
    await mount(tester, client);
    expect(find.byType(KChart), findsOneWidget);
    expect(client.requests, isEmpty);
    await tester.tapAt(
      tester.getTopLeft(find.byType(KChartSurface)) + const Offset(120, 100),
    );
    await tester.pump();
    final selectedTime = chart(tester).value.selection!.candle.openTime;
    await tester.pump(const Duration(seconds: 5));
    expect(chart(tester).value.data.length, 181);
    expect(chart(tester).value.selection!.candle.openTime, selectedTime);
    expect(find.textContaining('替换 4 次 · 新增 1 根'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('验收页可在主图画水平线和趋势线，落点不打开信息面板', (tester) async {
    await mount(tester, _Client());
    final controller = chart(tester);
    Offset chartPoint(double x, double y) =>
        tester.getTopLeft(find.byType(KChartSurface)) + Offset(x, y);

    await tap(tester, 'horizontal-line');
    expect(
      tester.widget<KChartSurface>(find.byType(KChartSurface)).onDrawingAnchor,
      isNotNull,
    );
    await tester.ensureVisible(find.byType(KChartSurface));
    await tester.pump();
    await tester.tapAt(chartPoint(120, 120));
    await tester.pump();
    expect(controller.value.overlays.drawings, hasLength(1));
    expect(
      controller.value.overlays.drawings.single.kind,
      ChartDrawingKind.horizontalLine,
    );
    expect(controller.value.selection, isNull);

    await tester
        .ensureVisible(find.byKey(const ValueKey('acceptance-trend-line')));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tap(tester, 'trend-line');
    await tester.ensureVisible(find.byType(KChartSurface));
    await tester.pump();
    await tester.tapAt(chartPoint(120, 140));
    await tester.pump();
    expect(
      controller.value.overlays.drawings,
      hasLength(1),
      reason: '首个锚点仅是草稿',
    );
    await tester.tapAt(chartPoint(220, 160));
    await tester.pump();
    expect(controller.value.overlays.drawings, hasLength(2));
    expect(controller.value.overlays.drawings.last.anchors, hasLength(2));
    expect(controller.value.selection, isNull);

    await tester
        .ensureVisible(find.byKey(const ValueKey('acceptance-remove-drawing')));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tap(tester, 'remove-drawing');
    expect(controller.value.overlays.drawings, hasLength(1));

    await tester.ensureVisible(
      find.byKey(const ValueKey('acceptance-undo-drawing')),
    );
    await tap(tester, 'undo-drawing');
    expect(controller.value.overlays.drawings, hasLength(2));
    await tester.ensureVisible(
      find.byKey(const ValueKey('acceptance-redo-drawing')),
    );
    await tap(tester, 'redo-drawing');
    expect(controller.value.overlays.drawings, hasLength(1));

    await tester.ensureVisible(
      find.byKey(const ValueKey('acceptance-drawing-list')),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const ValueKey('acceptance-drawing-list')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('水平线 · acceptance-drawing-1'));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('acceptance-toggle-visible')),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tap(tester, 'toggle-visible');
    expect(controller.value.overlays.drawings.last.style.visible, isFalse);

    await tester.ensureVisible(
      find.byKey(const ValueKey('acceptance-drawing-list')),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const ValueKey('acceptance-drawing-list')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('水平线 · acceptance-drawing-1（隐藏）'));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('acceptance-toggle-visible')),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tap(tester, 'toggle-visible');
    expect(controller.value.overlays.drawings.last.style.visible, isTrue);
    await tap(tester, 'toggle-lock');
    expect(controller.value.overlays.drawings.last.isLocked, isTrue);
    await tap(tester, 'toggle-lock');
    expect(controller.value.overlays.drawings.last.isLocked, isFalse);
    await tester.ensureVisible(
      find.byKey(const ValueKey('acceptance-undo-drawing')),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tap(tester, 'undo-drawing');
    expect(controller.value.overlays.drawings.last.style.visible, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('验收页其余绘图工具按锚点数创建并可进入渲染', (tester) async {
    await mount(tester, _Client());
    final controller = chart(tester);
    const tools = <(String, ChartDrawingKind, int)>[
      ('垂直线', ChartDrawingKind.verticalLine, 1),
      ('射线', ChartDrawingKind.ray, 2),
      ('矩形', ChartDrawingKind.rectangle, 2),
      ('平行通道', ChartDrawingKind.parallelChannel, 3),
      ('斐波那契回撤', ChartDrawingKind.fibonacciRetracement, 2),
      ('文本标注', ChartDrawingKind.text, 1),
      ('价格标记', ChartDrawingKind.priceMarker, 1),
    ];
    for (final (label, kind, anchorCount) in tools) {
      final menu = find.byKey(const ValueKey('acceptance-drawing-tools'));
      await tester.ensureVisible(menu);
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pump();
      await tester.ensureVisible(find.byType(KChartSurface));
      await tester.pump();
      final point = tester.getTopLeft(find.byType(KChartSurface));
      for (var index = 0; index < anchorCount; index++) {
        await tester.tapAt(point + Offset(100 + index * 35, 120 + index * 25));
        await tester.pump();
      }
      expect(controller.value.overlays.drawings.last.kind, kind);
      expect(
        controller.value.overlays.drawings.last.anchors,
        hasLength(anchorCount),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('验收页保存/删除/恢复绘图快照并隔离行情来源', (tester) async {
    final store = _MemorySnapshotStore();
    await mount(tester, _Client(), drawingSnapshotStore: store);
    final controller = chart(tester);
    await tap(tester, 'horizontal-line');
    await tester.ensureVisible(find.byType(KChartSurface));
    await tester.pump();
    final origin = tester.getTopLeft(find.byType(KChartSurface));
    await tester.tapAt(origin + const Offset(120, 120));
    await tester.pump();
    final savedDrawing = controller.value.overlays.drawings.single;

    Future<void> tapVisible(String key, String action) async {
      await tester.ensureVisible(find.byKey(ValueKey('acceptance-$key')));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      await tap(tester, action);
    }

    await tapVisible('save-drawings', 'save-drawings');
    await tapVisible('remove-drawing', 'remove-drawing');
    expect(controller.value.overlays.drawings, isEmpty);
    await tapVisible('restore-drawings', 'restore-drawings');
    expect(controller.value.overlays.drawings, [savedDrawing]);

    await tapVisible('remove-drawing', 'remove-drawing');
    expect(controller.value.overlays.drawings, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await mount(tester, _Client(), drawingSnapshotStore: store);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    final remountedController = chart(tester);
    await tapVisible('restore-drawings', 'restore-drawings');
    expect(remountedController.value.overlays.drawings, [savedDrawing]);

    await tester.ensureVisible(
      find.byKey(const ValueKey('acceptance-binance')),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tap(tester, 'binance');
    await tester.pump();
    expect(
      tester
          .widget<TextButton>(
            find.byKey(const ValueKey('acceptance-restore-drawings')),
          )
          .onPressed,
      isNull,
    );
    expect(remountedController.value.overlays.drawings, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('设置面板切换主图模式及多主副指标，直接更新同一 Controller', (tester) async {
    await mount(tester, _Client());
    final controller = chart(tester);
    await tap(tester, 'settings');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('sdk-mode-line')));
    await tester.pump();
    expect(controller.value.options.mainMode, ChartMainMode.line);
    await tester.tap(find.byKey(const ValueKey('sdk-mode-candlestick')));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('sdk-indicator-ma')));
    await tester.pump();
    expect(
      controller.value.options.indicators
          .any((binding) => binding.config.instanceId == 'ma'),
      isTrue,
    );
    expect(
      controller.value.options.indicators
          .any((binding) => binding.config.instanceId == 'ema'),
      isTrue,
    );

    final editMa = find.byKey(const ValueKey('sdk-edit-ma'));
    await tester.ensureVisible(editMa);
    await tester.tap(editMa);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sdk-param-period3')), findsOneWidget);
    expect(find.byKey(const ValueKey('sdk-param-period4')), findsNothing);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('sdk-series-ma')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sdk-series-option-ma30')), findsNothing);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    final vol = find.byKey(const ValueKey('sdk-indicator-vol'));
    await tester.ensureVisible(vol);
    await tester.tap(vol);
    await tester.pump();
    expect(controller.value.options.secondaryPanels, isEmpty);

    final macd = find.byKey(const ValueKey('sdk-indicator-macd'));
    await tester.ensureVisible(macd);
    await tester.tap(macd);
    await tester.pump();
    expect(
      controller.value.options.secondaryPanels.single.id,
      'secondary-macd',
    );
    expect(
      controller.value.options.indicators
          .any((binding) => binding.config.definitionId == 'legacy.macd'),
      isTrue,
    );

    final rsi = find.byKey(const ValueKey('sdk-indicator-rsi'));
    await tester.ensureVisible(rsi);
    await tester.tap(rsi);
    await tester.pump();
    expect(
      controller.value.options.secondaryPanels.map((panel) => panel.id),
      containsAll(['secondary-macd', 'secondary-rsi']),
    );

    await tester.tap(find.byTooltip('关闭设置'));
    await tester.pumpAndSettle();
    expect(chart(tester), same(controller));
    expect(tester.takeException(), isNull);
  });

  testWidgets('指标周期弹窗拦截非法值并提交到原 Controller', (tester) async {
    await mount(tester, _Client());
    final controller = chart(tester);
    await tap(tester, 'settings');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sdk-edit-ema')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('sdk-param-period1')),
      '0',
    );
    await tester.tap(find.byKey(const ValueKey('sdk-param-save')));
    await tester.pump();
    expect(find.text('请输入大于 0 的整数'), findsOneWidget);
    expect(
      controller.value.options.indicators
          .firstWhere((item) => item.config.instanceId == 'ema')
          .config
          .parameter('period1'),
      7,
    );

    await tester.enterText(
      find.byKey(const ValueKey('sdk-param-period1')),
      '9',
    );
    await tester.tap(find.byKey(const ValueKey('sdk-param-save')));
    await tester.pumpAndSettle();
    expect(
      controller.value.options.indicators
          .firstWhere((item) => item.config.instanceId == 'ema')
          .config
          .parameter('period1'),
      9,
    );
    expect(find.textContaining('周期 1 9'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('曲线设置只改变展示选择，不重算且参数编辑保留选择', (tester) async {
    await mount(tester, _Client());
    final controller = chart(tester);
    await tap(tester, 'settings');
    await tester.pumpAndSettle();
    final edit = find.byKey(const ValueKey('sdk-series-ema'));
    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('sdk-series-option-ema30')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('sdk-series-option-ema10')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sdk-series-save')));
    await tester.pumpAndSettle();
    expect(
      controller.value.options.indicators
          .firstWhere((item) => item.config.instanceId == 'ema')
          .visibleSeriesIds,
      {'ema5', 'ema30'},
    );

    await tester.tap(find.byKey(const ValueKey('sdk-series-ema')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sdk-series-option-ema5')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sdk-series-option-ema30')));
    await tester.pump();
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const ValueKey('sdk-series-option-ema30')),
          )
          .value,
      isTrue,
    );
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('sdk-edit-ema')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('sdk-param-period1')),
      '8',
    );
    await tester.tap(find.byKey(const ValueKey('sdk-param-save')));
    await tester.pumpAndSettle();
    expect(
      controller.value.options.indicators
          .firstWhere((item) => item.config.instanceId == 'ema')
          .visibleSeriesIds,
      {'ema5', 'ema30'},
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('新增内建指标可配置；SAR 关联参数越界不提交', (tester) async {
    await mount(tester, _Client());
    final controller = chart(tester);
    await tap(tester, 'settings');
    await tester.pumpAndSettle();

    final sar = find.byKey(const ValueKey('sdk-indicator-sar'));
    await tester.ensureVisible(sar);
    await tester.tap(sar);
    await tester.pump();
    final editSar = find.byKey(const ValueKey('sdk-edit-sar'));
    await tester.ensureVisible(editSar);
    await tester.tap(editSar);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('sdk-param-afStart')),
      '0.3',
    );
    await tester.tap(find.byKey(const ValueKey('sdk-param-save')));
    await tester.pump();
    expect(find.text('初始加速不能超过加速上限'), findsOneWidget);
    expect(
      controller.value.options.indicators
          .firstWhere((item) => item.config.instanceId == 'sar')
          .config
          .parameter('afStart'),
      isNull,
    );
    await tester.enterText(
      find.byKey(const ValueKey('sdk-param-afMax')),
      '0.4',
    );
    await tester.tap(find.byKey(const ValueKey('sdk-param-save')));
    await tester.pumpAndSettle();
    expect(
      controller.value.options.indicators
          .firstWhere((item) => item.config.instanceId == 'sar')
          .config
          .parameter('afStart'),
      0.3,
    );

    final atr = find.byKey(const ValueKey('sdk-indicator-atr'));
    await tester.ensureVisible(atr);
    await tester.tap(atr);
    await tester.pump();
    expect(
      controller.value.options.indicators
          .any((item) => item.config.definitionId == 'builtin.atr'),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('自定义指标从只读目录进入设置页并编辑独立参数', (tester) async {
    await mount(tester, _Client());
    final controller = chart(tester);
    await tap(tester, 'settings');
    await tester.pumpAndSettle();
    final custom =
        find.byKey(const ValueKey('sdk-indicator-custom-example.typicalPrice'));
    await tester.ensureVisible(custom);
    await tester.tap(custom);
    await tester.pump();
    expect(
      controller.value.options.secondaryPanels.last.id,
      'secondary-custom-example.typicalPrice',
    );
    final edit =
        find.byKey(const ValueKey('sdk-edit-custom:example.typicalPrice'));
    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    expect(find.text('典型价 参数'), findsWidgets);
    await tester.enterText(
      find.byKey(const ValueKey('sdk-param-scale')),
      '2.5',
    );
    await tester.tap(find.byKey(const ValueKey('sdk-param-save')));
    await tester.pumpAndSettle();
    expect(
      controller.value.options.indicators
          .firstWhere(
            (item) => item.config.instanceId == 'custom:example.typicalPrice',
          )
          .config
          .parameter('scale'),
      2.5,
    );
    expect(controller.value.issues, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('指标错误可见，修复配置后提示消失', (tester) async {
    await mount(tester, _Client());
    final controller = chart(tester);
    final options = controller.value.options;
    controller.setOptions(
      options.copyWith(
        indicators: [
          ...options.indicators,
          KChartIndicatorBinding(
            panelId: 'main',
            config: IndicatorConfig(
              instanceId: 'broken',
              definitionId: 'missing',
            ),
          ),
        ],
      ),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('acceptance-chart-issue')),
      findsOneWidget,
    );
    expect(find.textContaining('broken'), findsOneWidget);

    controller.setOptions(options);
    await tester.pump();
    expect(find.byKey(const ValueKey('acceptance-chart-issue')), findsNothing);
  });

  testWidgets('暂停停止自动更新但允许手动替换/新增', (tester) async {
    await mount(tester, _Client());
    await tap(tester, 'pause');
    final initial = chart(tester).value.data;
    await tester.pump(const Duration(seconds: 8));
    expect(chart(tester).value.data, same(initial));
    await tap(tester, 'replace');
    expect(chart(tester).value.data.last.close, isNot(initial.last.close));
    await tap(tester, 'append');
    expect(chart(tester).value.data.length, 181);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('币安首次全量，随后请求两条并走真正增量命令', (tester) async {
    final client = _Client();
    await mount(tester, client);
    await tap(tester, 'binance');
    expect(client.limits, [180]);
    client.requests.first.complete(data);
    await tester.pump();
    expect(chart(tester).value.data.length, 180);
    await tester.pump(const Duration(seconds: 2));
    expect(client.limits, [180, 2]);
    client.requests.last.complete([
      data.last.copyWith(close: data.last.close + 0.1),
      ...buildV2KlineFixture(1, startIndex: 180),
    ]);
    await tester.pump();
    await tester.pump(); // 请求完成后，再绘制计数状态和新组件的同一提交。
    expect(chart(tester).value.data.length, 181);
    expect(find.textContaining('替换 1 次 · 新增 1 根'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('切回模拟或卸载后，旧币安请求不污染数据', (tester) async {
    final client = _Client();
    await mount(tester, client);
    await tap(tester, 'binance');
    await tap(tester, 'simulation');
    final simulated = chart(tester).value.data;
    client.requests.first.complete(data);
    await tester.pump();
    expect(chart(tester).value.data, same(simulated));
    await tap(tester, 'binance');
    final controller = chart(tester);
    await tester.pumpWidget(const SizedBox());
    client.requests.last.complete(data);
    await tester.pump();
    expect(controller.isDisposed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('网络失败明确显示，不伪装成真实数据或默默回退模拟', (tester) async {
    final client = _Client();
    await mount(tester, client);
    await tap(tester, 'binance');
    client.requests.first.completeError(StateError('离线'));
    await tester.pump();
    expect(chart(tester).value.data, isEmpty);
    expect(find.textContaining('未自动切换为模拟数据'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('进入后台暂停时钟和网络，恢复前台后重新刷新', (tester) async {
    final client = _Client();
    await mount(tester, client);
    await tap(tester, 'binance');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    client.requests.first.complete(data);
    await tester.pump(const Duration(seconds: 8));
    expect(client.requests.length, 1);
    expect(chart(tester).value.data, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(client.requests.length, 2);
    client.requests.last.complete(data);
    await tester.pump();
    expect(chart(tester).value.data.length, 180);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
