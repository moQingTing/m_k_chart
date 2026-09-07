# m_k_chart

一个功能强大的 Flutter K线图表库，支持多种技术指标和深度图展示。

> 当前发布线保持 1.x Widget 的兼容性；V2 整改已经提供不可变主题、版本化用户配置和完整交易图 Demo。V2 的内部 Renderer/Controller 尚未作为稳定 Widget API 导出，请按 [迁移指南](docs/MIGRATING_TO_V2.md) 使用当前正式入口。

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

### V2 交易图 Demo

`example/` 默认启动 `V2TradingChartDemo` 中文交易图：它请求 Binance 现货公共 K 线并每 2 秒增量刷新，断网时自动回退到确定性本地数据，并可演示蜡烛/空心/OHLC/Heikin-Ashi/分时/面积主图、多主图和副图指标、独立数值格式、时区、十字光标详情、交易 Overlay 和买卖深度图。

```bash
cd example
flutter run
```

Demo 通过仓库内部桥接层展示 V2 Renderer，不是可直接复制的公开 `KChart` Widget 集成方式。应用侧请继续使用本页的稳定 API，并参阅 [完整 Example 说明](docs/architecture/KLINE_V2_EXAMPLE_TOOLBAR.md)。

### 基础 K 线图（1.x 兼容 API）

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

当前唯一正式入口是 `package:m_k_chart/m_k_chart.dart`。`flutter_k_chart.dart` 仍可用，但已标记 deprecated；不要深路径导入 `src`、Renderer 或 Example 支持文件。完整差异见 [P9 公共 API 差异](docs/P9_PUBLIC_API_DIFF.md)。

### KChartTheme

`KChartTheme` 是 V2 的不可变视觉值对象，可独立采用，不会改变旧 `KChartWidget` 行为：

```dart
final theme = KChartTheme.light(
  mainValueDecimalPlaces: 2,
  mainValueUseThousandsSeparator: true,
  secondaryValueDecimalPlaces: 4,
  secondaryValueUseThousandsSeparator: false,
);

final compatibleTheme = chartColors.toKChartTheme(chartStyle: chartStyle);
```

主图和副图的数值格式、指标调色板与十字光标样式均可独立配置。详见 [主题协议](docs/architecture/KLINE_V2_THEME_PROTOCOL.md)。

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
- [V2 迁移指南](docs/MIGRATING_TO_V2.md)
- [P9 公共 API 差异](docs/P9_PUBLIC_API_DIFF.md)
- [P9 跨平台构建门禁](docs/P9_CROSS_PLATFORM_BUILD_GATE.md)
- [m_k_chart 1.x：性能基线](docs/PERFORMANCE_BASELINE.md)

运行示例：

```bash
cd example
flutter run
```

默认 V2 示例功能包括：
- Binance 公开行情、2 秒增量 K 线与确定性离线回退；
- 周期、主图模式、主图/副图指标、叠加或分面板布局；
- 主图和副图独立小数位、千分位、时区与透明指标参数区；
- 点击/长按十字光标、价格/时间标签、历史拖动和返回最新；
- 仓位/挂单等交易 Overlay，以及可模拟增量、丢包和恢复的买卖深度图。

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
