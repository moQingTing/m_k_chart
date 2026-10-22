# K 线 2.0 主图蜡烛与价格标记协议

> 任务：P6-02  
> 状态：已实现  
> 日期：2026-08-26

## 1. 主图模式

内部 `ChartMainMode` 的语义固定如下：

| 模式 | 数据 | 绘制 | 主图指标 |
| --- | --- | --- | --- |
| `candlestick` | 原始 OHLC | 实体蜡烛 | 显示 |
| `hollowCandlestick` | 原始 OHLC | 空心实体与影线 | 显示 |
| `ohlc` | 原始 OHLC | 高低影线、开盘左 tick、收盘右 tick | 显示 |
| `heikinAshi` | Heikin-Ashi 投影 | 实体蜡烛与影线 | 显示 |
| `line` / `area` | 原始 close | 曲线 / 曲线加面积 | 隐藏 |

已有 `candlestick`、`line`、`area` 输出保持其 P5-07 基线；新增模式由同一 Layer Stack 与 RenderSnapshot 版本协议驱动，不引入第二条 Painter 路径。

## 2. Heikin-Ashi 投影

`ChartCandleProjection` 是 Renderer 私有、不可变的 OHLC 投影。首根：

```text
haClose = (open + high + low + close) / 4
haOpen  = (open + close) / 2
```

后续 K 线使用前一根投影：

```text
haOpen = (previousHaOpen + previousHaClose) / 2
haHigh = max(sourceHigh, haOpen, haClose)
haLow  = min(sourceLow, haOpen, haClose)
```

主图极值、Y 轴范围、最新价标记和高低点标记都读取同一投影，避免绘制内容与坐标范围不一致。

## 3. 标记语义

`ChartMarkerLayer` 在可见主图中绘制：

- 可见范围内的最高价 `H <price>` 与最低价 `L <price>`；
- 若最后一根数据可见，则从其收盘价延伸到右边界的最新价线和数值；
- 最新价线按当前 candle 的涨跌使用主题 `upColor` / `downColor`，高低点使用 `markerColor`。

最新数据不在可见范围时，不能显示陈旧或伪造的“最新价”线；高低点仅基于当前可见窗口。

## 4. 缓存与门禁

- candle 投影以 `(data version, data slice version, main mode)` 为键、容量为 4 的独立 LRU 缓存保存；不会占用文字、Path 或 Picture 缓存预算。
- 极值和面板范围继续将主图模式纳入键；切换模式、数据或视口均重录 main/marker，selection-only 仍不触发它们。
- `test/render/chart_candle_projection_test.dart` 锁定递推公式、不可变性和 raw OHLC 保持。
- `test/render/chart_layer_geometry_test.dart` 锁定 Heikin-Ashi 极值和范围。
- `test/render/standard_chart_layers_test.dart` 验证新增模式与既有模式像素不同。
- `test/render/standard_chart_golden_test.dart` 冻结 dark/light、多面板下的 hollow、OHLC、Heikin-Ashi 基线，并更新包含价格标记的既有基线。
