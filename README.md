# m_k_chart

一个功能强大的 Flutter K线图表库，支持多种技术指标和深度图展示。

## 图片展示

![K线图表演示1](https://github.com/moQingTing/m_k_chart/raw/main/example/0d45c754e1d760926e2a97cdec01a464.jpg)

![K线图表演示2](https://github.com/moQingTing/m_k_chart/raw/main/example/39d489b40a933d2fa64ceec7b28997cf.jpg)

## 致谢

本项目参考了 [flutter_k_chart](https://github.com/gwhcn/flutter_k_chart) 的设计思路与实现方案，感谢原作者 [@gwhcn](https://github.com/gwhcn) 的贡献。

## 特性

- 📈 **K线图表**：支持蜡烛图和折线图两种展示方式
- 📊 **多种技术指标**：
  - 主图指标：MA（移动平均线）、BOLL（布林带）、EMA（指数移动平均线）、SAR（抛物线转向指标）
  - 副图指标：MACD、KDJ、RSI、WR、VOL（成交量）、OBV（能量潮）
- 🎨 **高度可定制**：支持自定义颜色、样式、格式化器等
- 🌓 **暗色模式**：内置暗色模式支持
- 👆 **交互功能**：支持缩放、平移、长按查看详情等手势操作
- ⚡ **性能优化**：流畅的动画和渲染性能

## 安装

在 `pubspec.yaml` 文件中添加依赖：

```yaml
dependencies:
  m_k_chart: ^1.0.0
```

然后运行：

```bash
flutter pub get
```

## 快速开始

### 1. 准备数据

首先准备K线数据，数据格式为 `KLineEntity` 列表：

```dart
List<KLineEntity> klineData = [
  KLineEntity()
    ..open = 50000.0
    ..high = 51000.0
    ..low = 49000.0
    ..close = 50500.0
    ..vol = 1000.0
    ..id = 1640995200, // 时间戳（秒）
  // ... 更多数据
];
```

### 2. 计算技术指标

在使用图表前，需要先计算技术指标：

```dart
import 'package:m_k_chart/m_k_chart.dart';

// 创建图表样式配置
final chartStyle = ChartStyle(
  obvPeriod: 30, // OBV 移动平均线周期
  emaConfigs: [
    EMAConfig(period: 5, color: Colors.yellow),
    EMAConfig(period: 10, color: Colors.pink),
    EMAConfig(period: 30, color: Colors.purple),
  ],
  sarAFStart: 0.02,      // SAR 加速因子初始值
  sarAFIncrement: 0.02, // SAR 加速因子增量
  sarAFMax: 0.2,        // SAR 加速因子最大值
);

// 计算所有技术指标
DataUtil.calculate(
  klineData,
  obvPeriod: chartStyle.obvPeriod,
  emaConfigs: chartStyle.emaConfigs,
  chartStyle: chartStyle,
);
```

### 3. 创建图表

```dart
KChartWidget(
  klineData,
  mainState: MainState.ma, // 主图指标：MA、BOLL、EMA、SAR 或 none
  secondaryStates: [
    SecondaryState.macd, // 副图指标：MACD、KDJ、RSI、WR、VOL、OBV
    SecondaryState.vol,
  ],
  isLine: false, // false 为蜡烛图，true 为折线图
  chartStyle: chartStyle,
  chartColors: ChartColors(
    isDarkMode: false,
    upColor: Colors.green,   // 上涨颜色
    downColor: Colors.red,   // 下跌颜色
  ),
)
```

## 完整示例

### 基础K线图

```dart
import 'package:flutter/material.dart';
import 'package:m_k_chart/m_k_chart.dart';

class KLineChartPage extends StatefulWidget {
  @override
  _KLineChartPageState createState() => _KLineChartPageState();
}

class _KLineChartPageState extends State<KLineChartPage> {
  List<KLineEntity> _klineData = [];

  @override
  void initState() {
    super.initState();
    _loadKLineData();
  }

  void _loadKLineData() {
    // 加载K线数据
    // ... 从API或本地加载数据
  }

  @override
  Widget build(BuildContext context) {
    if (_klineData.isEmpty) {
      return Center(child: CircularProgressIndicator());
    }

    // 创建图表样式
    final chartStyle = ChartStyle(
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
      dateFormatter: (date) {
        final dateTime = DateTime.fromMillisecondsSinceEpoch(date * 1000);
        return '${dateTime.year}-${dateTime.month}-${dateTime.day}';
      },
    );

    // 计算技术指标
    DataUtil.calculate(
      _klineData,
      obvPeriod: chartStyle.obvPeriod,
      emaConfigs: chartStyle.emaConfigs,
      chartStyle: chartStyle,
    );

    return Scaffold(
      appBar: AppBar(title: Text('K线图')),
      body: KChartWidget(
        _klineData,
        mainState: MainState.ma,
        secondaryStates: [SecondaryState.macd, SecondaryState.vol],
        chartStyle: chartStyle,
        chartColors: ChartColors(
          isDarkMode: false,
          upColor: Colors.green,
          downColor: Colors.red,
        ),
      ),
    );
  }
}
```

## 主要API

### KChartUserConfig

V2 用户配置采用版本化 JSON 值对象，由宿主自行选择持久化方式：

```dart
final config = KChartUserConfig(
  intervalCode: '15m',
  mainMode: 'candlestick',
  mainIndicators: [
    KChartIndicatorPreference(
      instanceId: 'ema-fast',
      definitionId: 'legacy.ema',
      parameters: {'period': 7},
    ),
  ],
);

final restored = KChartUserConfig.fromJson(config.toJson());
```

详见 [V2 用户配置序列化协议](docs/architecture/KLINE_V2_USER_CONFIG_PROTOCOL.md)。

### KChartWidget

K线图表主组件。

**参数：**
- `datas` (List<KLineEntity>): K线数据列表
- `mainState` (MainState): 主图指标状态
  - `MainState.none`: 无指标
  - `MainState.ma`: 移动平均线
  - `MainState.boll`: 布林带
  - `MainState.ema`: 指数移动平均线
  - `MainState.sar`: 抛物线转向指标
- `secondaryStates` (List<SecondaryState>): 副图指标列表
  - `SecondaryState.macd`: MACD指标
  - `SecondaryState.kdj`: KDJ指标
  - `SecondaryState.rsi`: RSI指标
  - `SecondaryState.wr`: WR指标
  - `SecondaryState.vol`: 成交量
  - `SecondaryState.obv`: OBV指标
- `isLine` (bool): 是否使用折线图（默认false，即蜡烛图）
- `chartStyle` (ChartStyle): 图表样式配置
- `chartColors` (ChartColors): 图表颜色配置
- `infoWindowBuilder` (Widget Function?): 自定义信息窗口构建器

### ChartStyle

图表样式配置类。

**主要属性：**
- `pointWidth`: 点与点的距离
- `candleWidth`: 蜡烛宽度
- `volWidth`: 成交量柱子宽度
- `macdWidth`: MACD柱子宽度
- `gridRows`: 网格行数
- `gridColumns`: 网格列数
- `obvPeriod`: OBV移动平均线周期
- `emaConfigs`: EMA配置列表
- `sarAFStart`: SAR加速因子初始值
- `sarAFIncrement`: SAR加速因子增量
- `sarAFMax`: SAR加速因子最大值
- `priceFormatter`: 价格格式化回调
- `volumeFormatter`: 成交量格式化回调
- `dateFormatter`: 日期格式化回调

### ChartColors

图表颜色配置类。

**主要属性：**
- `isDarkMode`: 是否使用暗色模式
- `upColor`: 上涨颜色
- `downColor`: 下跌颜色
- `ma5Color`: MA5颜色
- `ma10Color`: MA10颜色
- `ma30Color`: MA30颜色
- `macdColor`: MACD颜色
- `sarUpColor`: SAR上升趋势颜色
- `sarDownColor`: SAR下降趋势颜色

### DataUtil

技术指标计算工具类。

**主要方法：**
- `calculate()`: 计算所有技术指标
- `addLastData()`: 增量添加数据并计算指标
- `updateLastData()`: 更新最后一条数据并重新计算指标

## 运行示例

项目包含完整的示例代码，位于 `example` 目录下。

## 开发规划

- [m_k_chart 2.0：币安风格 K 线整改开发计划](docs/BINANCE_KLINE_V2_DEVELOPMENT_PLAN.md)
- [m_k_chart 2.0：开发清单与时序线](docs/KLINE_V2_EXECUTION_ROADMAP.md)
- [m_k_chart 1.x：性能基线](docs/PERFORMANCE_BASELINE.md)

运行示例：

```bash
cd example
flutter run
```

示例功能包括：
- 多种市场数据切换（BTC、ETH等）
- 多种时间周期切换（1m、5m、15m、1H、4H、1D）
- 主图指标切换（MA、BOLL、EMA、SAR）
- 副图指标多选（MACD、KDJ、RSI、WR、VOL、OBV）
- 实时数据更新

## 注意事项

1. **数据要求**：
   - 至少需要5条数据才能显示MA指标
   - 至少需要12条数据才能显示MACD等副图指标
   - 数据需要按时间顺序排列

2. **指标计算**：
   - 使用图表前必须先调用 `DataUtil.calculate()` 计算指标
   - 增量更新数据时使用 `DataUtil.addLastData()`
   - 更新最后一条数据时使用 `DataUtil.updateLastData()`

3. **性能优化**：
   - 建议数据量控制在1000条以内以保证流畅性
   - 大量数据时考虑分页加载

## License

MIT License

See [LICENSE](LICENSE) file for details.
