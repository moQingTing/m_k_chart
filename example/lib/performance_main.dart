import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:m_k_chart/m_k_chart.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final style = ChartStyle()
    ..emaConfigs = [
      EMAConfig(period: 5, color: Colors.yellow),
      EMAConfig(period: 10, color: Colors.pink),
      EMAConfig(period: 30, color: Colors.purple),
    ];
  final data = _buildKlineFixture(2000);
  DataUtil.calculate(
    data,
    obvPeriod: style.obvPeriod,
    emaConfigs: style.emaConfigs,
    chartStyle: style,
  );

  runApp(_PerformanceBaselineApp(data: data, style: style));
}

class _PerformanceBaselineApp extends StatelessWidget {
  const _PerformanceBaselineApp({required this.data, required this.style});

  final List<KLineEntity> data;
  final ChartStyle style;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(
                height: 32,
                child: Center(
                  child: Text(
                    'm_k_chart Profile Baseline: 2000 / MA / MACD / VOL',
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
              Expanded(
                child: KChartWidget(
                  data,
                  mainState: MainState.ma,
                  secondaryStates: const [
                    SecondaryState.macd,
                    SecondaryState.vol,
                  ],
                  chartStyle: style,
                  chartColors: ChartColors(
                    isDarkMode: true,
                    upColor: Colors.green,
                    downColor: Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<KLineEntity> _buildKlineFixture(int count) {
  return List<KLineEntity>.generate(count, (index) {
    final trend = index * 0.37;
    final cycle = ((index % 23) - 11) * 0.41;
    final open = 1000.0 + trend + cycle;
    final close = open + ((index % 7) - 3) * 0.29;
    final high = math.max(open, close) + 1.2 + (index % 5) * 0.13;
    final low = math.min(open, close) - 1.1 - (index % 3) * 0.17;
    final volume = 800.0 + (index % 17) * 53.0 + index * 1.7;

    return KLineEntity()
      ..id = 1704067200 + index * 60
      ..open = open
      ..high = high
      ..low = low
      ..close = close
      ..vol = volume
      ..amount = volume * (open + close) / 2
      ..count = 20 + index % 31;
  });
}
