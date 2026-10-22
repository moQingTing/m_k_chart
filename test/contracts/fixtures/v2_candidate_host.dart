import 'package:m_k_chart/m_k_chart.dart';

/// 外部宿主只通过正式入口使用 Widget，不需要构造渲染快照或手动传时钟。
KChart createPublicWidget(KChartController controller) => KChart(
      controller: controller,
      labels: const KChartLabels.zhCN(),
      onSelectionChanged: (_) {},
      onIssue: (_) {},
    );

/// 宿主编译探针只引用正式入口，不用内部模块补齐参数类型。
KChartController createPublicChart({
  required KlineSeries series,
  Iterable<Kline> initialData = const [],
  KChartHistoryLoader? historyLoader,
}) =>
    KChartController(
      series: series,
      initialData: initialData,
      historyLoader: historyLoader,
      options: KChartOptions(
        mainMode: ChartMainMode.candlestick,
        mainPanel: KChartPanelOptions(headerHeight: 18),
        secondaryPanels: [KChartSecondaryPanelOptions(id: 'cci')],
        indicators: [
          KChartIndicatorBinding(
            panelId: 'cci',
            config: IndicatorConfig(
              instanceId: 'cci-14',
              definitionId: 'builtin.cci',
              parameters: const {'period': 14},
            ),
          ),
        ],
        viewport: KChartViewportOptions(initialVisibleCandles: 60),
      ),
    );

/// 版本值属于宿主可见的数据契约，可用于识别 K 线快照的新旧。
KlineDataVersion nextPublicDataVersion(KlineDataVersion version) =>
    version.next();

/// 覆盖物、绘图和样式同样只从正式入口取得，避免示例隐式依赖深路径。
KChartOverlayUpdateStatus installPublicOverlays(
  KChartController chart,
  Kline candle,
) =>
    chart.setOverlays(
      session: chart.session,
      priceLines: [
        ChartPriceLine(
          id: 'order',
          price: candle.close,
          side: ChartOverlaySide.buy,
          style: ChartPriceLineStyle.dashed,
          label: '示例订单',
        ),
      ],
      events: [
        ChartEventOverlay(
          id: 'event',
          epochMilliseconds: candle.openTime,
          price: candle.close,
        ),
      ],
      valueMarkers: [
        ChartValueMarker(id: 'marker', price: candle.close, text: '示例标记'),
      ],
      drawings: [
        ChartDrawing(
          id: 'drawing',
          kind: ChartDrawingKind.horizontalLine,
          anchors: [
            ChartDrawingAnchor(
              epochMilliseconds: candle.openTime,
              price: candle.close,
            ),
          ],
          style: ChartDrawingStyle(dashPattern: const [4, 2]),
        ),
      ],
    );
