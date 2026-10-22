import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:m_k_chart/m_k_chart.dart';

/// 独立运行：cd example && flutter run -t lib/v2_minimal_chart_main.dart
void main() => runApp(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: V2MinimalChartExample(),
      ),
    );

/// 最小接入示例：宿主创建 Controller、提交行情，并在页面销毁时释放它。
///
/// 行情来自本地确定性数据，不需要网络；真实项目可把按钮回调替换成自己的 REST 或
/// WebSocket 数据源。时间统一使用 UTC epoch 毫秒，切换序列时应重新取得 session。
class V2MinimalChartExample extends StatefulWidget {
  const V2MinimalChartExample({this.nowMilliseconds, super.key});

  /// 只控制显示时钟，便于测试；不修改 K 线原始时间。
  final int Function()? nowMilliseconds;

  @override
  State<V2MinimalChartExample> createState() => _V2MinimalChartExampleState();
}

class _V2MinimalChartExampleState extends State<V2MinimalChartExample> {
  late final KChartController _chart;
  int? _selectedOpenTime;

  @override
  void initState() {
    super.initState();
    final now =
        widget.nowMilliseconds?.call() ?? DateTime.now().millisecondsSinceEpoch;
    final latestOpenTime = now ~/ 60000 * 60000;
    final seed = _seedCandles(latestOpenTime);
    _chart = KChartController(
      series: KlineSeries.fromKline(seed.first),
      initialData: seed,
      options: KChartOptions(
        indicators: [
          KChartIndicatorBinding(
            panelId: 'main',
            config: IndicatorConfig(
              instanceId: 'ema',
              definitionId: 'legacy.ema',
              parameters: const {
                'period1': 7,
                'period2': 25,
                'period3': 50,
              },
            ),
          ),
        ],
      ),
    );
  }

  void _replaceLatest() {
    final last = _chart.value.data.last;
    final close = last.close + 1;
    // 同一开盘时间用 updateKline；不要修改旧 Kline 或快照里的列表。
    _chart.updateKline(
      last.copyWith(
        high: math.max(last.high, close),
        close: close,
        baseVolume: last.baseVolume + 1,
        quoteVolume: last.quoteVolume + close,
      ),
      session: _chart.session,
    );
  }

  void _appendNext() {
    final last = _chart.value.data.last;
    final session = _chart.session;
    // 一分钟周期到边界后先闭合旧柱，再追加严格更晚的新柱。
    if (!last.isClosed) {
      _chart.updateKline(last.copyWith(isClosed: true), session: session);
    }
    final openTime = last.openTime + 60000;
    _chart.appendData(
      [
        Kline(
          symbol: last.symbol,
          interval: last.interval,
          priceSource: last.priceSource,
          openTime: openTime,
          closeTime: openTime + 59999,
          open: last.close,
          high: last.close + 1,
          low: last.close - 1,
          close: last.close + 0.5,
          baseVolume: 1,
          quoteVolume: last.close + 0.5,
          tradeCount: 1,
          isClosed: false,
        ),
      ],
      session: session,
    );
  }

  @override
  void dispose() {
    // Controller 属于宿主，KChart 不会替宿主释放；取消订阅/请求也应在此处理。
    _chart.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('K 线最小接入示例')),
        body: SafeArea(
          child: Column(
            children: [
              Wrap(
                children: [
                  TextButton(
                    key: const ValueKey('minimal-replace'),
                    onPressed: _replaceLatest,
                    child: const Text('更新当前 K 线'),
                  ),
                  TextButton(
                    key: const ValueKey('minimal-append'),
                    onPressed: _appendNext,
                    child: const Text('新增一根 K 线'),
                  ),
                  TextButton(
                    onPressed: _chart.scrollToLatest,
                    child: const Text('回到最新'),
                  ),
                ],
              ),
              ValueListenableBuilder<KChartViewState>(
                valueListenable: _chart,
                builder: (context, state, _) => Text(
                  'K 线 ${state.data.length} 根 · 数据版本 ${state.dataRevision}'
                  '${_selectedOpenTime == null ? '' : ' · 选中 $_selectedOpenTime'}',
                  key: const ValueKey('minimal-status'),
                ),
              ),
              Expanded(
                child: KChart(
                  controller: _chart,
                  theme: KChartTheme.light(),
                  currentTimeMilliseconds: widget.nowMilliseconds,
                  onSelectionChanged: (selection) {
                    final openTime = selection?.candle.openTime;
                    if (_selectedOpenTime != openTime) {
                      setState(() => _selectedOpenTime = openTime);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      );
}

List<Kline> _seedCandles(int latestOpenTime) => List.generate(60, (index) {
      final openTime = latestOpenTime - (59 - index) * 60000;
      final open = 100.0 + index * 0.2 + math.sin(index / 5) * 2;
      final close = open + (index.isEven ? 0.6 : -0.4);
      return Kline(
        symbol: 'BTCUSDT',
        interval: KlineInterval.oneMinute,
        openTime: openTime,
        closeTime: openTime + 59999,
        open: open,
        high: math.max(open, close) + 0.3,
        low: math.min(open, close) - 0.3,
        close: close,
        baseVolume: 10 + index.toDouble(),
        quoteVolume: (10 + index) * close,
        tradeCount: 10 + index,
        isClosed: index != 59,
      );
    }, growable: false);
