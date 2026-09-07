# K 线 2.0 主题与 Legacy 配色协议

> 任务：P6-01  
> 状态：已实现  
> 日期：2026-08-31

## 1. 正式入口

`KChartTheme` 从唯一正式入口 `package:m_k_chart/m_k_chart.dart` 导出。它是 V2 图表可见样式的公开值对象；Renderer、Painter 和内部 `ChartRenderStyle` 不属于公开 API。

```dart
final theme = KChartTheme(
  upColor: const Color(0xff0ecb81),
  downColor: const Color(0xfff6465d),
  indicatorColors: {
    'my-macd:dif': const Color(0xffc9b885),
  },
);
```

指标专有配色的键固定为 `instanceId:seriesId`。没有精确键时，主题使用稳定 hash 从 `indicatorPalette` 取色，因此新增其他指标不会改变既有指标颜色。

## 2. 值对象不变量

- 所有颜色、尺寸和比例在构造时校验；尺寸必须为有限正数，蜡烛/柱宽比例必须在 `(0, 1]`。
- `areaFillColors` 至少含两个颜色，`indicatorPalette` 不得为空。
- 调色板、显式指标配色均在构造时复制为不可修改集合。
- `copyWith` 产生新对象；相等比较和 hashCode 覆盖全部可见字段及集合内容。
- 主题更新应仅在新旧 `KChartTheme` 不相等时推进 RenderSnapshot 的 `theme` 版本。

`KChartTheme.light()` 提供浅色基线；无参数构造提供深色交易图基线。

## 3. 主图与副图数值格式

主图和副图拥有完全独立的数值格式配置。两者默认保留两位小数并使用千分位分隔：

```dart
final theme = KChartTheme.light(
  mainValueDecimalPlaces: 4,
  mainValueUseThousandsSeparator: true,
  secondaryValueDecimalPlaces: 1,
  secondaryValueUseThousandsSeparator: false,
  // 回调可分别替换默认格式；decimalPlaces 是上方对应配置值。
  mainValueFormatter: (value, decimalPlaces) =>
      value.toStringAsFixed(decimalPlaces),
);
```

主图格式覆盖主图纵轴、最高/最低价、最新价、主图十字光标、指标图例和详情 OHLC；副图格式覆盖副图纵轴、十字光标、指标图例和详情成交量。自定义回调优先于千分位开关；通过 `copyWith(clearMainValueFormatter: true)` 或 `copyWith(clearSecondaryValueFormatter: true)` 可恢复对应区域的默认格式。

## 4. 十字光标样式

点击或长按选择时，`KChartTheme` 默认绘制黑底白字的时间与数值标签、虚线十字线和实心交点；这与详情卡样式独立，方便应用保留浅色详情面板或改成深色面板。

```dart
final theme = KChartTheme.light(
  crosshairColor: const Color(0xff111111),
  crosshairDashLength: 5,
  crosshairDashGap: 4,
  crosshairPointRadius: 3,
  crosshairLabelBackgroundColor: const Color(0xff000000),
  crosshairLabelTextColor: const Color(0xffffffff),
  crosshairDetailBackgroundColor: const Color(0xf2ffffff),
  crosshairDetailTextColor: const Color(0xff0f172a),
  crosshairDetailBorderColor: const Color(0xff94a3b8),
);
```

纵坐标标签会自动采用被命中主图或副图的数值格式；横坐标以实际 K 线的 openTime 为准，显示在主图与首个副图之间的无网格时间带中。

## 5. ChartColors 兼容适配

1.x 项目可在保留旧 Widget 的同时，将旧配色用于 V2 装配：

```dart
final theme = chartColors.toKChartTheme(chartStyle: chartStyle);
```

`ChartColorsThemeAdapter` 保留背景、网格、轴、主线、面积渐变、涨跌色、标记/十字线色，以及 `ChartStyle` 的线宽、字号、蜡烛和成交量宽度比例。它还为 legacy MA、EMA、成交量 MA、MACD DIF/DEA、KDJ、RSI 和 OBV MA 写入显式指标配色。

成交量、MACD 柱和 SAR 的涨跌配色继续由 P5-05 已冻结的 descriptor 语义决定，分别读取 V2 主题的 `upColor`、`downColor`；适配器不会把旧 `macdColor` 或 `sarUpColor`/`sarDownColor` 错误套用到不同的 V2 语义。

由于 1.x `ChartStyle` 可变且允许非法尺寸，适配器会将非有限或非正的尺寸回退到 V2 默认值，并将无效宽度比例回退为 `1`。这保证现有应用可以逐步迁移，而不会把无效 legacy 状态传播进 V2 Renderer。

## 6. API 和回归门禁

- `tool/public_api_allowlist.txt` 明确审查新增的 `KChartTheme` 和 `ChartColorsThemeAdapter`；公开入口仍禁止导出 `src/` 或 `renderer/`。
- `test/theme/k_chart_theme_test.dart` 覆盖集合不可变性、结构化相等、主副图独立格式、格式回调清除、显式指标色优先级、legacy 映射和非法 legacy 尺寸归一化。
- `test/render/standard_chart_layers_test.dart` 验证主图和副图绘制入口不会串用格式器。
- `test/architecture/public_api_surface_test.dart` 防止公开表面无审查漂移。
