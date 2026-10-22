import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/v2_example_support.dart';

// The runnable demo is intentionally outside the package's public API.
// ignore: avoid_relative_lib_imports
import '../../example/lib/binance_market_data_client.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/market/v2_demo_market_data_source.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/market/v2_demo_seed_data.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/v2_chart_demo.dart';
import '../support/v2_kline_fixture.dart';

final class _CountingClient extends BinanceMarketDataClient {
  int candleCalls = 0;

  @override
  Future<List<Kline>> candles({
    required String symbol,
    required KlineInterval interval,
    int limit = 180,
  }) async {
    candleCalls++;
    return limit == 2
        ? buildV2KlineFixture(2, startIndex: 178)
        : buildV2KlineFixture(180);
  }

  @override
  Future<BinanceTicker> ticker({required String symbol}) async => BinanceTicker(
        symbol: symbol,
        last: 1000,
        open24h: 990,
        high24h: 1010,
        low24h: 980,
        baseVolume24h: 100,
        quoteVolume24h: 100000,
      );
}

/// 不继承币安客户端，验证宿主可按示例契约直接注入自己的行情源。
final class _StandaloneSource implements V2DemoMarketDataSource {
  int candleCalls = 0;

  @override
  String get displayName => '自定义源';

  @override
  Future<List<Kline>> candles({
    required String symbol,
    required KlineInterval interval,
    int limit = 180,
  }) async {
    candleCalls++;
    return buildV2KlineFixture(limit, startIndex: limit == 2 ? 178 : 0);
  }

  @override
  Future<V2MarketTicker?> ticker({required String symbol}) async =>
      V2MarketTicker(
        symbol: symbol,
        last: 1234,
        open24h: 1200,
        high24h: 1250,
        low24h: 1180,
        baseVolume24h: 100,
        quoteVolume24h: 123400,
      );
}

final class _CancelableSource implements V2DemoCancelableMarketDataSource {
  final firstLoad = Completer<List<Kline>>();
  int fullWindowCalls = 0;
  int canceledLoads = 0;

  @override
  String get displayName => '可取消源';

  @override
  V2DemoMarketRequest<List<Kline>> requestCandles({
    required String symbol,
    required KlineInterval interval,
    int limit = 180,
  }) {
    final window = createV2DemoSeedData(interval, revision: 0).data;
    if (limit == 2) {
      return V2DemoMarketRequest(
        result: Future.value(window.sublist(window.length - 2)),
        cancel: () {},
      );
    }
    fullWindowCalls++;
    return V2DemoMarketRequest(
      result: fullWindowCalls == 1 ? firstLoad.future : Future.value(window),
      cancel: () => canceledLoads++,
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

/// 第一轮刷新一直等待，用于复现切换周期后旧请求挡住新轮询的竞态。
final class _HeldRefreshClient extends BinanceMarketDataClient {
  final firstRefresh = Completer<List<Kline>>();
  final refreshIntervals = <KlineInterval>[];
  List<Kline>? _firstRecent;

  @override
  Future<List<Kline>> candles({
    required String symbol,
    required KlineInterval interval,
    int limit = 180,
  }) {
    final window = createV2DemoSeedData(interval, revision: 0).data;
    if (limit != 2) return Future.value(window);
    final recent = window.sublist(window.length - 2);
    refreshIntervals.add(interval);
    if (refreshIntervals.length == 1) {
      _firstRecent = recent;
      return firstRefresh.future;
    }
    return Future.value(recent);
  }

  void completeFirstRefresh() {
    if (!firstRefresh.isCompleted) firstRefresh.complete(_firstRecent!);
  }

  @override
  Future<BinanceTicker> ticker({required String symbol}) => Future.value(
        BinanceTicker(
          symbol: symbol,
          last: 1000,
          open24h: 990,
          high24h: 1010,
          low24h: 980,
          baseVolume24h: 100,
          quoteVolume24h: 100000,
        ),
      );
}

/// 首次完整窗口加载一直等待，用于验证隐藏页面时的过期结果与返回重载。
final class _HeldInitialLoadClient extends BinanceMarketDataClient {
  final firstLoad = Completer<List<Kline>>();
  int fullWindowCalls = 0;
  List<Kline>? _oldWindow;

  @override
  Future<List<Kline>> candles({
    required String symbol,
    required KlineInterval interval,
    int limit = 180,
  }) {
    final window = createV2DemoSeedData(interval, revision: 0).data;
    if (limit == 2) return Future.value(window.sublist(window.length - 2));
    fullWindowCalls++;
    if (fullWindowCalls == 1) {
      _oldWindow = _withLastCloseOffset(window, 100);
      return firstLoad.future;
    }
    return Future.value(_withLastCloseOffset(window, 20));
  }

  List<Kline> _withLastCloseOffset(List<Kline> window, double offset) {
    final last = window.last;
    return [
      ...window.take(window.length - 1),
      last.copyWith(close: last.close + offset, high: last.high + offset),
    ];
  }

  void completeFirstLoad() {
    if (!firstLoad.isCompleted) firstLoad.complete(_oldWindow!);
  }

  @override
  Future<BinanceTicker> ticker({required String symbol}) async =>
      throw StateError('用 K 线窗口验证离线摘要');
}

void main() {
  testWidgets('默认 Demo 可进入候选组件验收页并返回原有设置', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: V2TradingChartDemo(loadOnStart: false)),
    );
    expect(
      find.byKey(const ValueKey('open-indicator-settings')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('open-sdk-candidate')));
    await tester.pumpAndSettle();
    expect(find.text('新组件验收'), findsOneWidget);
    expect(find.byKey(const ValueKey('acceptance-simulation')), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('open-indicator-settings')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('open-sdk-candidate')), findsOneWidget);
  });

  testWidgets('进入候选页暂停旧 Demo 轮询，返回后同步并恢复', (tester) async {
    final client = _CountingClient();
    await tester.pumpWidget(
      MaterialApp(
        home: V2TradingChartDemo(marketDataClient: client),
      ),
    );
    await tester.pumpAndSettle();
    expect(client.candleCalls, 1);

    await tester.tap(find.byKey(const ValueKey('open-sdk-candidate')));
    await tester.pumpAndSettle();
    final callsBeforeWait = client.candleCalls;
    await tester.pump(const Duration(seconds: 5));
    expect(client.candleCalls, callsBeforeWait);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(client.candleCalls, callsBeforeWait + 1);
    await tester.pump(const Duration(seconds: 2));
    expect(client.candleCalls, callsBeforeWait + 2);
  });

  testWidgets('非币安行情源直接注入，摘要和增量轮询使用同一来源', (tester) async {
    final source = _StandaloneSource();
    await tester.pumpWidget(
      MaterialApp(home: V2TradingChartDemo(marketDataSource: source)),
    );
    await tester.pumpAndSettle();
    expect(source.candleCalls, 1);
    expect(find.text('自定义源 24h'), findsOneWidget);
    expect(find.text('1,234.00'), findsOneWidget);
    expect(find.textContaining('自定义源 公共行情'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(source.candleCalls, 2);
    expect(find.textContaining('自定义源 实时'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('应用退后台停止轮询，恢复时重载窗口后继续增量同步', (tester) async {
    final client = _CountingClient();
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: V2TradingChartDemo(marketDataClient: client)),
    );
    await tester.pumpAndSettle();
    expect(client.candleCalls, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 5));
    expect(client.candleCalls, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(client.candleCalls, 2);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(client.candleCalls, 3);

    await tester.pumpWidget(const SizedBox.shrink());
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 3));
    expect(client.candleCalls, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('父组件启停自动加载不会遗留轮询，重新启用时重载窗口', (tester) async {
    final client = _CountingClient();
    Widget demo(bool loadOnStart) => MaterialApp(
          home: V2TradingChartDemo(
            loadOnStart: loadOnStart,
            marketDataClient: client,
          ),
        );

    await tester.pumpWidget(demo(false));
    await tester.pump(const Duration(seconds: 3));
    expect(client.candleCalls, 0);

    await tester.pumpWidget(demo(true));
    await tester.pumpAndSettle();
    expect(client.candleCalls, 1);
    await tester.pumpWidget(demo(false));
    await tester.pump(const Duration(seconds: 5));
    expect(client.candleCalls, 1);

    await tester.pumpWidget(demo(true));
    await tester.pumpAndSettle();
    expect(client.candleCalls, 2);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(client.candleCalls, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('父组件替换行情源时旧全量响应不能覆盖新行情', (tester) async {
    final oldClient = _HeldInitialLoadClient();
    final newClient = _CountingClient();
    addTearDown(oldClient.completeFirstLoad);
    await tester.pumpWidget(
      MaterialApp(home: V2TradingChartDemo(marketDataClient: oldClient)),
    );
    await tester.pump();
    expect(oldClient.fullWindowCalls, 1);

    await tester.pumpWidget(
      MaterialApp(home: V2TradingChartDemo(marketDataClient: newClient)),
    );
    await tester.pumpAndSettle();
    expect(newClient.candleCalls, 1);
    final lastPrice = find.byKey(const ValueKey('market-summary-last-price'));
    final newPrice = tester.widget<Text>(lastPrice).data;

    oldClient.completeFirstLoad();
    await tester.pump();
    expect(tester.widget<Text>(lastPrice).data, newPrice);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(newClient.candleCalls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('退后台使在途完整加载失效，恢复后旧结果不能覆盖重载', (tester) async {
    final client = _HeldInitialLoadClient();
    addTearDown(client.completeFirstLoad);
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: V2TradingChartDemo(marketDataClient: client)),
    );
    await tester.pump();
    expect(client.fullWindowCalls, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 3));
    expect(client.fullWindowCalls, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(client.fullWindowCalls, 2);

    final lastPrice = find.byKey(const ValueKey('market-summary-last-price'));
    final reloadedPrice = tester.widget<Text>(lastPrice).data;
    client.completeFirstLoad();
    await tester.pump();
    expect(tester.widget<Text>(lastPrice).data, reloadedPrice);
    expect(tester.takeException(), isNull);
  });

  testWidgets('子页面仍打开时应用恢复，不提前重启父页面轮询', (tester) async {
    final client = _CountingClient();
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: V2TradingChartDemo(marketDataClient: client)),
    );
    await tester.pumpAndSettle();
    expect(client.candleCalls, 1);

    await tester.tap(find.byKey(const ValueKey('open-sdk-candidate')));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 3));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 3));
    expect(client.candleCalls, 1);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(client.candleCalls, 2);
  });

  testWidgets('子页面打开时旧刷新悬挂，返回主图仍立即同步', (tester) async {
    final client = _HeldRefreshClient();
    addTearDown(client.completeFirstRefresh);
    await tester.pumpWidget(
      MaterialApp(home: V2TradingChartDemo(marketDataClient: client)),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(client.refreshIntervals, hasLength(1));

    await tester.tap(find.byKey(const ValueKey('open-sdk-candidate')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    expect(client.refreshIntervals, hasLength(1));

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(client.refreshIntervals, hasLength(2));
    client.completeFirstRefresh();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('完整加载未完成就打开子页面，返回后重载且旧结果不覆盖', (tester) async {
    final client = _HeldInitialLoadClient();
    addTearDown(client.completeFirstLoad);
    await tester.pumpWidget(
      MaterialApp(home: V2TradingChartDemo(marketDataClient: client)),
    );
    await tester.pump();
    expect(client.fullWindowCalls, 1);
    final lastPrice = find.byKey(const ValueKey('market-summary-last-price'));
    final initialPrice = tester.widget<Text>(lastPrice).data;

    await tester.tap(find.byKey(const ValueKey('open-sdk-candidate')));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(client.fullWindowCalls, 2);

    final reloadedPrice = tester.widget<Text>(lastPrice).data;
    expect(reloadedPrice, isNot(initialPrice));
    client.completeFirstLoad();
    await tester.pump();
    expect(tester.widget<Text>(lastPrice).data, reloadedPrice);
    expect(tester.takeException(), isNull);
  });

  testWidgets('隐藏页面取消可取消源的悬挂请求，返回后重新加载', (tester) async {
    final source = _CancelableSource();
    addTearDown(() {
      if (!source.firstLoad.isCompleted) {
        source.firstLoad.complete(
          createV2DemoSeedData(KlineInterval.oneMinute, revision: 0).data,
        );
      }
    });
    await tester.pumpWidget(
      MaterialApp(home: V2TradingChartDemo(marketDataSource: source)),
    );
    await tester.pump();
    expect(source.fullWindowCalls, 1);
    expect(source.canceledLoads, 0);

    await tester.tap(find.byKey(const ValueKey('open-sdk-candidate')));
    await tester.pumpAndSettle();
    expect(source.canceledLoads, 1);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(source.fullWindowCalls, 2);

    source.firstLoad.complete(
      createV2DemoSeedData(KlineInterval.oneMinute, revision: 0).data,
    );
    await tester.pump();
    expect(find.textContaining('可取消源 公共行情'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('旧周期刷新未返回时，新周期仍可开始轮询', (tester) async {
    final client = _HeldRefreshClient();
    addTearDown(client.completeFirstRefresh);
    await tester.pumpWidget(
      MaterialApp(home: V2TradingChartDemo(marketDataClient: client)),
    );
    await tester.pumpAndSettle();

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(client.refreshIntervals, [KlineInterval.oneMinute]);

    await tester.tap(find.byKey(const ValueKey('open-data-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('period-5m')));
    await tester.pump();
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(client.refreshIntervals, contains(KlineInterval.fiveMinutes));
    client.completeFirstRefresh();
    await tester.pump();
    expect(find.textContaining('BTCUSDT · 5m'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Demo accepts custom indicator calculation parameters',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: V2TradingChartDemo(loadOnStart: false)),
    );

    await tester.tap(
      find.byKey(const ValueKey('open-indicator-settings')),
    );
    await tester.pumpAndSettle();

    final parameter = find.byKey(
      const ValueKey('indicator-param-ma-period1'),
    );
    await tester.scrollUntilVisible(
      parameter,
      260,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('settings-sheet-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(parameter);
    await tester.pump();
    await tester.tap(parameter);
    await tester.enterText(parameter, '7');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.textContaining('周期 1 7'), findsOneWidget);
    final reset = find.byKey(const ValueKey('indicator-param-reset-ma'));
    await tester.ensureVisible(reset);
    await tester.tap(reset);
    await tester.pump();
    final input = find.descendant(
      of: parameter,
      matching: find.byType(EditableText),
    );
    expect(tester.widget<EditableText>(input).controller.text, '5');
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('indicator-parameters-ma')),
        matching: find.textContaining('周期 1 5'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('single main indicator legend keeps the secondary header height',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: V2TradingChartDemo(loadOnStart: false)),
    );

    final mainLegend =
        find.byKey(const ValueKey('panel-indicator-legend-main'));
    await tester.scrollUntilVisible(
      mainLegend,
      260,
      scrollable: find.byType(Scrollable).first,
    );
    final secondaryLegend = find.byKey(
      const ValueKey('panel-indicator-legend-secondary-vol'),
      skipOffstage: false,
    );

    expect(mainLegend, findsOneWidget);
    expect(secondaryLegend, findsOneWidget);
    expect(
      tester.getSize(mainLegend).height,
      tester.getSize(secondaryLegend).height,
      reason: '单个主图指标的参数区应与副图使用相同的单行高度。',
    );
  });

  testWidgets('daily candles show date-only crosshair time', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: V2TradingChartDemo(loadOnStart: false)),
    );
    await tester.tap(find.byKey(const ValueKey('open-data-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('period-1d')));
    await tester.pump();
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();

    final chartCanvas = find.byKey(const ValueKey('v2-chart-canvas'));
    await tester.scrollUntilVisible(
      chartCanvas,
      260,
      scrollable: find.byType(Scrollable).first,
    );
    final chartTopLeft = tester.getTopLeft(chartCanvas);
    await tester.tapAt(chartTopLeft + const Offset(100, 50));
    await tester.pump();

    final timeLabel = find.byKey(const ValueKey('crosshair-time-label'));
    final timeText = tester.widget<Text>(
      find.descendant(of: timeLabel, matching: find.byType(Text)),
    );
    expect(timeText.data, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
  });

  testWidgets('realtime replacement and append preserve the selected crosshair',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: V2TradingChartDemo(loadOnStart: false)),
    );

    // 与真实操作一致，先切换一次周期并让图表完成一次新的本地数据窗口组装。
    await tester.tap(find.byKey(const ValueKey('open-data-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('period-1d')));
    await tester.pump();
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();

    final chartCanvas = find.byKey(const ValueKey('v2-chart-canvas'));
    await tester.scrollUntilVisible(
      chartCanvas,
      260,
      scrollable: find.byType(Scrollable).first,
    );
    final chartTopLeft = tester.getTopLeft(chartCanvas);
    await tester.tapAt(chartTopLeft + const Offset(120, 50));
    await tester.pump();

    // 中间时间轴标签证明十字线选中态已经建立。
    expect(
      find.byKey(const ValueKey('crosshair-time-label')),
      findsOneWidget,
    );

    final simulationSettings = find.byKey(
      const ValueKey('open-simulation-settings'),
      skipOffstage: false,
    );
    await tester.ensureVisible(simulationSettings);
    await tester.pumpAndSettle();
    await tester.tap(simulationSettings);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('simulate-update-latest')));
    await tester.pump();
    expect(
      find.byKey(
        const ValueKey('crosshair-details-position'),
        skipOffstage: false,
      ),
      findsOneWidget,
      reason: '替换最新 K 线不应关闭已选数据的信息面板。',
    );

    await tester.tap(find.byKey(const ValueKey('simulate-append-latest')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('crosshair-time-label')),
      findsOneWidget,
      reason: '新增最新 K 线不应清除十字线和时间标签。',
    );
  });

  testWidgets('settings sheets organize chart controls without expanding page',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: V2TradingChartDemo(loadOnStart: false)),
    );

    expect(find.byKey(const ValueKey('v2-chart-canvas')), findsOneWidget);
    expect(find.byKey(const ValueKey('period-1m')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('open-data-settings')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('period-1m')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('period-5m')));
    await tester.pump();
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const ValueKey('period-5m')))
          .selected,
      isTrue,
    );
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('open-indicator-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('main-indicator-super')));
    await tester.pump();
    expect(
      tester
          .widget<FilterChip>(
            find.byKey(const ValueKey('main-indicator-super')),
          )
          .selected,
      isTrue,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('super-area-opacity-setting')),
      260,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('settings-sheet-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(
      find.byKey(const ValueKey('super-area-opacity-setting')),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('open-chart-settings')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('main-header-height-setting')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('main-value-decimals')),
      260,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('settings-sheet-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.byKey(const ValueKey('main-value-decimals')), findsOneWidget);
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('open-simulation-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('simulate-update-latest')));
    await tester.pump();
    expect(find.textContaining('已模拟更新最新 K 线'), findsOneWidget);
  });

  /* Replaced by the focused settings-sheet coverage above.
  testWidgets('V2 example switches periods and all chart modes offline',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: V2TradingChartDemo(loadOnStart: false)),
    );

    expect(find.byKey(const ValueKey('period-1m')), findsOneWidget);
    expect(find.byKey(const ValueKey('mode-candlestick')), findsOneWidget);
    expect(find.byKey(const ValueKey('market-summary')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('market-summary-last-price')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('open-fullscreen-demo')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('close-fullscreen-demo')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('close-fullscreen-demo')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('open-fullscreen-demo')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('period-5m')));
    await tester.pump();
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const ValueKey('period-5m')))
          .selected,
      isTrue,
    );

    for (final mode in [
      ('hollowCandlestick', '空心蜡烛'),
      ('ohlc', 'OHLC'),
      ('heikinAshi', '平均 K 线'),
      ('line', '折线图'),
      ('area', '面积图'),
    ]) {
      await tester.tap(find.byKey(ValueKey('mode-${mode.$1}')));
      await tester.pump();
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(ValueKey('mode-${mode.$1}')),
            )
            .selected,
        isTrue,
      );
    }
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('main-indicator-boll')),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('main-indicator-boll')));
    await tester.pump();
    expect(
      tester
          .widget<FilterChip>(
            find.byKey(const ValueKey('main-indicator-boll')),
          )
          .selected,
      isTrue,
    );
    for (final id in ['avl', 'super']) {
      await tester.tap(find.byKey(ValueKey('main-indicator-$id')));
      await tester.pump();
      expect(
        tester
            .widget<FilterChip>(
              find.byKey(ValueKey('main-indicator-$id')),
            )
            .selected,
        isTrue,
      );
    }
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('super-area-opacity-setting')),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const ValueKey('super-area-opacity-setting')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('secondary-indicator-rsi')),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('secondary-indicator-rsi')));
    await tester.pump();
    expect(
      tester
          .widget<FilterChip>(
            find.byKey(const ValueKey('secondary-indicator-rsi')),
          )
          .selected,
      isTrue,
    );

    await tester.scrollUntilVisible(
      find.byType(Switch),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('main-header-height-setting')),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const ValueKey('main-header-height-setting')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('secondary-header-height-setting')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('main-time-axis-height-setting')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('main-value-decimals')),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    final mainDecimals = tester.widget<DropdownButton<int>>(
      find.byKey(const ValueKey('main-value-decimals')),
    );
    mainDecimals.onChanged!(4);
    await tester.pump();
    expect(
      tester
          .widget<DropdownButton<int>>(
            find.byKey(const ValueKey('main-value-decimals')),
          )
          .value,
      4,
    );
    final compactZeros = find.byKey(
      const ValueKey('main-value-compact-zeros'),
    );
    await tester.ensureVisible(compactZeros);
    await tester.tap(compactZeros);
    await tester.pump();
    expect(tester.widget<FilterChip>(compactZeros).selected, isTrue);
    final compactThreshold = find.byKey(
      const ValueKey('main-value-compact-threshold'),
    );
    expect(tester.widget<DropdownButton<int>>(compactThreshold).value, 3);
    tester.widget<DropdownButton<int>>(compactThreshold).onChanged!(4);
    await tester.pump();
    expect(tester.widget<DropdownButton<int>>(compactThreshold).value, 4);
    final compactDigits = find.byKey(
      const ValueKey('main-value-compact-digits'),
    );
    tester.widget<DropdownButton<int>>(compactDigits).onChanged!(5);
    await tester.pump();
    expect(tester.widget<DropdownButton<int>>(compactDigits).value, 5);
    final secondaryThousands = find.byKey(
      const ValueKey('secondary-value-thousands'),
    );
    expect(tester.widget<FilterChip>(secondaryThousands).selected, isTrue);
    await tester.tap(secondaryThousands);
    await tester.pump();
    expect(tester.widget<FilterChip>(secondaryThousands).selected, isFalse);
    final tradeOverlays = find.byKey(
      const ValueKey('trade-overlay-examples'),
    );
    await tester.scrollUntilVisible(
      tradeOverlays,
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.widget<FilterChip>(tradeOverlays).selected, isTrue);
    expect(
      find.byKey(const ValueKey('trade-overlay-example-labels')),
      findsOneWidget,
    );
    await tester.tap(tradeOverlays);
    await tester.pump();
    expect(tester.widget<FilterChip>(tradeOverlays).selected, isFalse);
    await tester.tap(tradeOverlays);
    await tester.pump();
    expect(tester.widget<FilterChip>(tradeOverlays).selected, isTrue);
    await tester.drag(find.byType(ListView), const Offset(0, -1400));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('panel-indicator-legend-main')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('panel-indicator-legend-secondary-overlay')),
      findsOneWidget,
    );
    final chartCanvas = find.byKey(const ValueKey('v2-chart-canvas'));
    expect(chartCanvas, findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, 420));
    await tester.pumpAndSettle();
    final simulateUpdate = find.byKey(
      const ValueKey('simulate-update-latest'),
      skipOffstage: false,
    );
    await tester.ensureVisible(simulateUpdate);
    await tester.pump();
    await tester.tap(simulateUpdate);
    await tester.pump();
    expect(find.textContaining('已模拟更新最新 K 线'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(
      find.byKey(
        const ValueKey('simulate-append-latest'),
        skipOffstage: false,
      ),
    );
    await tester.pump();
    expect(find.textContaining('已模拟新增 K 线'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(chartCanvas);
    await tester.pump();
    expect(
      find.textContaining('SUPERTREND(10,3)', findRichText: true),
      findsOneWidget,
    );
    final mainLegendHeight = tester
        .getSize(
          find.byKey(const ValueKey('panel-indicator-legend-main')),
        )
        .height;
    expect(
      mainLegendHeight,
      greaterThan(18),
      reason: '多个主图指标参数应换行并扩大专用参数区域。',
    );
    final chartTopLeft = tester.getTopLeft(chartCanvas);
    final chartSize = tester.getSize(chartCanvas);
    const chartBodyY = 50.0;
    await tester.tapAt(chartTopLeft + const Offset(100, chartBodyY));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('crosshair-details')),
      findsOneWidget,
      reason:
          'chart=$chartTopLeft size=$chartSize legend=$mainLegendHeight localY=$chartBodyY',
    );
    expect(find.byKey(const ValueKey('crosshair-time-label')), findsOneWidget);
    expect(find.text('时间'), findsOneWidget);
    expect(find.text('命中值'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('crosshair-details'))).dx,
      greaterThan(chartTopLeft.dx + chartSize.width / 2),
    );

    await tester.tapAt(
      chartTopLeft + Offset(chartSize.width * 0.7, chartBodyY),
    );
    await tester.pump();
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('crosshair-details'))).dx,
      lessThan(chartTopLeft.dx + chartSize.width / 2),
    );

    await tester.drag(chartCanvas, const Offset(90, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('crosshair-details')), findsNothing);

    final latestPriceReturn = find.byKey(const ValueKey('latest-price-return'));
    expect(latestPriceReturn, findsOneWidget);
    await tester.tap(latestPriceReturn);
    await tester.pump();
    expect(latestPriceReturn, findsNothing);
    expect(find.byKey(const ValueKey('crosshair-details')), findsNothing);

    final center = tester.getCenter(chartCanvas);
    final first = await tester.startGesture(center + const Offset(-40, 0));
    final second = await tester.startGesture(center + const Offset(40, 0));
    await first.moveTo(center + const Offset(-70, 0));
    await second.moveTo(center + const Offset(70, 0));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  */

  testWidgets('trade overlay supports exclusive tap drag and cancel actions',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: V2TradingChartDemo(loadOnStart: false)),
    );

    final chartCanvas = find.byKey(const ValueKey('v2-chart-canvas'));
    await tester.scrollUntilVisible(
      chartCanvas,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final chartTopLeft = tester.getTopLeft(chartCanvas);
    final chartSize = tester.getSize(chartCanvas);
    Offset? overlayPosition;
    for (var localY = 22.0; localY < 300; localY += 6) {
      final candidate = chartTopLeft + Offset(chartSize.width * 0.45, localY);
      await tester.tapAt(candidate);
      await tester.pump();
      if (find
          .byKey(const ValueKey('trade-overlay-actions'))
          .evaluate()
          .isNotEmpty) {
        overlayPosition = candidate;
        break;
      }
    }

    expect(overlayPosition, isNotNull);
    expect(find.byKey(const ValueKey('trade-overlay-actions')), findsOneWidget);
    expect(find.byKey(const ValueKey('crosshair-details')), findsNothing);

    await tester.dragFrom(overlayPosition!, const Offset(0, 36));
    await tester.pump();
    expect(find.byKey(const ValueKey('trade-overlay-actions')), findsOneWidget);
    expect(find.byKey(const ValueKey('crosshair-details')), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('trade-overlay-action-cancel')),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('trade-overlay-actions')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'supports RTL large text minute timezone and localized chart semantics',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semanticsHandle = tester.ensureSemantics();

    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: V2TradingChartDemo(loadOnStart: false),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('open-chart-settings')));
      await tester.pumpAndSettle();
      final timeZone = find.byKey(const ValueKey('time-zone-offset'));
      final dropdown = tester.widget<DropdownButton<int>>(timeZone);
      dropdown.onChanged!(5 * 60 + 30);
      await tester.pump();
      expect(tester.widget<DropdownButton<int>>(timeZone).value, 330);
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();

      final chartCanvas = find.byKey(const ValueKey('v2-chart-canvas'));
      await tester.scrollUntilVisible(
        chartCanvas,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      final chartSemantics = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            (widget.properties.label?.startsWith('V2 图表') ?? false),
      );
      final semantics = tester.getSemantics(chartSemantics).getSemanticsData();
      expect(semantics.label, startsWith('V2 图表 1m 蜡烛图'));
      expect(semantics.textDirection, TextDirection.rtl);
      expect(semantics.value, contains('最新'));
      expect(semantics.hasAction(SemanticsAction.increase), isTrue);
      expect(semantics.hasAction(SemanticsAction.decrease), isTrue);
      expect(tester.takeException(), isNull);
    } finally {
      semanticsHandle.dispose();
    }
  });
}
