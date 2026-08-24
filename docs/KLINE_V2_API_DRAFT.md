# m_k_chart 2.0 公共 API 草案

> 状态：Phase 0 讨论稿，不代表最终兼容承诺
> 日期：2026-08-24

## 1. 设计原则

- 只有 `m_k_chart.dart` 是正式公共入口。
- 原始 K 线不可变，不携带指标结果。
- 业务通过 `KChartController` 控制图表，不访问 State。
- 指标、绘图和交易标记使用配置/注册机制扩展。
- 网络、WebSocket、持久化和下单由宿主实现。
- 状态单向进入 Renderer，Painter 不产生业务副作用。

## 2. 核心模型草案

```dart
final class Kline {
  Kline({
    required this.symbol,
    required this.interval,
    required this.openTime,
    required this.closeTime,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.baseVolume,
    required this.quoteVolume,
    required this.tradeCount,
    required this.isClosed,
    this.takerBuyBaseVolume = 0,
    this.takerBuyQuoteVolume = 0,
    this.firstTradeId,
    this.lastTradeId,
    this.priceSource = KlinePriceSource.trade,
  });
}

enum KlinePriceSource {
  trade('trade'),
  mark('mark'),
  indexPrice('index');
}

final class KlineInterval { /* fixed Duration 或 calendarMonth */ }
```

内部时间戳使用 UTC Unix 毫秒，并提供只读 UTC `DateTime` getter。周期支持内置常用值和校验后的自定义值；`1M` 使用自然月语义，不等同于固定 30 天。

## 3. Widget 与 Controller 草案

```dart
KChart(
  controller: controller,
  theme: theme,
  layout: layout,
  onLoadMore: loadHistory,
  selectionBuilder: selectionBuilder,
)

final controller = KChartController(
  data: initialData,
  indicators: indicatorConfigs,
);

controller.replaceData(data);
controller.prependHistory(history);
controller.updateKline(liveKline);
controller.scrollToLatest();
controller.scrollToTime(time);
controller.resetViewport();
```

Controller 对外提供只读 Listenable 状态，但不暴露 Painter、Renderer 或 Widget State。

## 4. 指标草案

```dart
abstract interface class IndicatorDefinition {
  String get id;
  IndicatorPlacement get placement;
  IndicatorResult calculate(IndicatorInput input);
  IndicatorResult update(IndicatorUpdate input);
}

final class IndicatorConfig {
  const IndicatorConfig({
    required this.instanceId,
    required this.definitionId,
    required this.parameters,
    required this.seriesStyles,
  });
}
```

同一种指标可通过不同 `instanceId` 同时存在多组参数。

## 5. 主题草案

主题拆分为不可变配置：

- `KChartTheme`
- `CandleStyle`
- `AxisStyle`
- `GridStyle`
- `CrosshairStyle`
- `PriceMarkerStyle`
- `IndicatorSeriesStyle`

所有配置提供 `copyWith` 和结构化相等比较，使 Layer 可以准确判断缓存是否失效。

## 6. Overlay 草案

```dart
sealed class ChartOverlay {}

final class PriceLineOverlay extends ChartOverlay {}
final class TradeMarkerOverlay extends ChartOverlay {}
final class PositionOverlay extends ChartOverlay {}
final class DrawingOverlay extends ChartOverlay {}
```

Overlay 只保存绘制所需的公开数据和事件 ID，不保存账户对象或交易 SDK 类型。

## 7. 兼容策略

- `KChartWidget` 在 2.0 继续提供 legacy facade。
- `KLineEntity`、`MainState`、`SecondaryState`、`DataUtil` 标记 deprecated。
- 提供 `KLineEntityAdapter` 和旧样式转换器。
- 兼容层至少保留整个 2.x 周期，删除时间在后续主版本决定。
- 新 API 与 legacy Renderer 在过渡阶段并存，避免一次性替换导致无法回滚。

## 8. 待决策问题

- 新 Widget 最终命名采用 `KChart` 还是保留 `KChartWidget`。
- ~~`KlineInterval` 是否提供内置常量并允许自定义周期。~~ 已决定：同时支持内置常用周期与自定义周期。
- 指标插件是否允许宿主提供自定义 Renderer。
- ~~Controller 状态采用单一快照还是多个细粒度 Listenable。~~ 已决定：对外单一只读快照，内部按 StateSlice 版本细粒度判断。
- Web 是否需要单独的文本测量和鼠标交互策略。
