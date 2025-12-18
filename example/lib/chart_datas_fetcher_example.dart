//
//  ChartDatasFetcher 使用示例
//  演示如何使用 ChartDatasFetcher 获取 K 线数据
//

import 'package:flutter/material.dart';
import 'package:m_k_chart/m_k_chart.dart';
import 'chart_datas_fetcher.dart';

/// 使用 ChartDatasFetcher 的示例页面
class ChartDataExamplePage extends StatefulWidget {
  const ChartDataExamplePage({super.key});

  @override
  State<ChartDataExamplePage> createState() => _ChartDataExamplePageState();
}

class _ChartDataExamplePageState extends State<ChartDataExamplePage> {
  List<KLineEntity> _klineData = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // 页面加载时自动获取数据
    _fetchChartData();
  }

  /// 获取 K 线数据
  Future<void> _fetchChartData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // 使用单例获取数据
    // symbol: BTC-USDT (BTC/USDT 交易对)
    // timeType: 1m (1分钟K线)
    // size: 100 (获取100条数据)
    await ChartDatasFetcher.shared.getRemoteChartData(
      'BTC-USDT',
      '1m',
      100,
      (success, data) {
        setState(() {
          _isLoading = false;
          if (success && data.isNotEmpty) {
            _klineData = data;
            _errorMessage = null;
          } else {
            _errorMessage = '获取数据失败，请检查网络连接';
          }
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('K线数据获取示例'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchChartData,
            tooltip: '刷新数据',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在加载 K 线数据...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(fontSize: 16, color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchChartData,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_klineData.isEmpty) {
      return const Center(
        child: Text('暂无数据'),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 显示数据统计信息
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '数据统计',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text('数据条数: ${_klineData.length}'),
                if (_klineData.isNotEmpty) ...[
                  Text('最新价格: ${_klineData.last.close.toStringAsFixed(2)}'),
                  Text('最高价: ${_klineData.map((e) => e.high).reduce((a, b) => a > b ? a : b).toStringAsFixed(2)}'),
                  Text('最低价: ${_klineData.map((e) => e.low).reduce((a, b) => a < b ? a : b).toStringAsFixed(2)}'),
                ],
              ],
            ),
          ),
          const Divider(),
          // K 线图
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'K线图',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 400,
                  child: KChartWidget(
                    _klineData,
                    mainState: MainState.ma,
                    secondaryStates: [SecondaryState.macd],
                    isLine: false,
                    chartStyle: ChartStyle(
                      priceFormatter: (price, defaultStyle) {
                        return TextSpan(
                          text: price.toStringAsFixed(2),
                          style: defaultStyle,
                        );
                      },
                      volumeFormatter: (volume, defaultStyle) {
                        return TextSpan(
                          text: volume.toStringAsFixed(0),
                          style: defaultStyle,
                        );
                      },
                    ),
                    chartColors: ChartColors(
                      isDarkMode: false,
                      upColor: Colors.green,
                      downColor: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

