# K 线 2.0 标准 Layer 协议

> 任务：P5-02、P5-05
>
> 状态：已实现
>
> 日期：2026-08-26

## 1. 标准绘制顺序

`buildStandardChartLayerStack` 冻结以下顺序：

| 顺序 | Layer ID | 输出 | 依赖切片 |
| ---: | --- | --- | --- |
| 1 | `grid` | 背景、数据槽位锚定的列网格、逐 panel 行网格 | data、viewport、layout、theme |
| 2 | `main` | 蜡烛/分时/面积主图 | data、viewport、layout、theme |
| 3 | `secondary` | 副图 line/histogram/points 指标 | data、viewport、layout、theme |
| 4 | `axis` | panel 数值标签、实际 openTime 标签 | data、viewport、layout、theme |
| 5 | `marker` | 可见高低点、最新价线和标签 | data、viewport、layout、theme |
| 6 | `drawing` | chart-local 投影线段 | data、layout、theme |
| 7 | `crosshair` | chart-local 十字线和价格标签 | selection、layout、theme |

Crosshair 最后绘制且不依赖 data/viewport。P5-04 已验证选择移动只重录 Crosshair Picture，不重新执行蜡烛和指标 paint。

## 2. 内部绘制样式

`ChartRenderStyle` 是 Phase 5 的最小只读样式接口，包含背景、网格、轴文字、涨跌、marker、crosshair、drawing 颜色，以及各类线宽和轴字号。

`DefaultChartRenderStyle`：

- 冻结 indicator palette，拒绝空 palette；
- 拒绝非有限或非正线宽/字号；
- 使用 instanceId + seriesId 的稳定字符哈希解析 Series 颜色；
- 不依赖 legacy `ChartColors` 或可变 `ChartStyle`。

P6-01 的完整 `KChartTheme` 将实现/扩展该接口，并补齐蜡烛变体、字体、轴位置和语义 style key。

## 3. 值域与坐标

- 每个 Layer 只遍历 `ChartViewport.visibleRange`；纵向网格同样按全局数据槽位锚定并经 X Transform 投影，平移或缩放时与蜡烛、指标同步移动，不保留固定像素网格窗口；每个 panel 可通过 `showHorizontalGrid` 独立关闭内部横向网格，此时仍保留完整 grid 区域的上、下边界和纵向数据列；
- X 使用 `ChartXTransform.indexToLocalX`，时间轴在每个可见数据锚定网格列绘制实际 openTime；标签不在固定屏幕列重新采样，因此与网格、蜡烛作为同一时间序列平移，不假设固定周期；
- `candlestick` 主图值域合并 Kline high/low 与 main 指标中 `includeInRange=true` 的 Series；`line`/`area` 只使用 close 值域；
- 副图按 panel 汇总 Series，并遵守 Descriptor 的 `includeZeroInRange`；
- 平值范围增加 1% 或 1 的有限 padding，空 panel 使用 0～1 fallback；
- 所有 panel、drawing 和 crosshair 输出使用 chart-local Bounds/clip。

P5-03 后所有标准 Layer 共享当前图表实例的 `ChartRenderCache`：同一数据/Viewport 版本只构造一次可见范围与 X Transform，主图 OHLC 极值只扫描一次，各 panel 值域按 panel ID 复用。缓存不使用跨实例 static 状态。

## 4. 指标绘制

Layer 不按指标 definitionId 使用 switch：

- `line`：null 断开 Path；
- `histogram`：以零值 Y 为基线并约束到 panel；
- `points`：按有效值绘制点；
- 普通 Series 颜色按 instanceId/seriesId 从主题解析；Descriptor 可声明 candle-direction、value-sign 或 price-position 语义色；
- histogram 可声明 `valueTrend`，以统一规则表达 MACD 的空心趋势柱。

因此内置、自定义以及同定义多实例使用同一绘制路径。递归 computation state 仍不可见。

## 5. Overlay 与绘图

- Marker 从可见 Kline 派生最高/最低点；最新 Kline 可见时绘制最新价；
- Crosshair 只在 visible selection 位于 drawing bounds 内绘制，hidden/越界状态无 Canvas 输出；显示时绘制贯穿图表的竖向虚线、仅贯穿命中 panel 的横向虚线，以及命中点的实心圆；
- Crosshair 的纵坐标标签使用命中 panel 的格式器（主图或副图），横坐标从实际 K 线 openTime 格式化后绘制在主图和首个副图之间的时间带；标签的背景、文字、内边距、虚线节奏和命中点半径均由 `ChartRenderStyle` 提供；
- `RenderLineDrawing` 在 Snapshot 装配时校验非空唯一 ID 与有限 local 坐标，公开集合不可写；
- Drawing Layer 只读取 Snapshot 并裁剪到 drawing bounds。P7 将 local 投影替换/扩展为时间、价格锚点与命中状态。

## 6. 纯度与性能边界

- 标准 Layer 不发送事件、不修改状态、不保存 Canvas；
- 使用 `save/clipRect/restore`，架构门禁禁止 `saveLayer`；
- 常用 `TextPainter`、指标 line `Path` 与网格 `Picture` 使用有界 LRU；版本或实际样式键变化时自然 miss，淘汰与 pipeline dispose 会释放原生资源；
- 每个 Layer 保留一张最新 Picture；版本未变化时直接复合，变化时事务式重录，任一 Layer 失败则不提交该帧的新 Picture/版本/计数；
- production Painter 未接线，旧 Demo 行为不变。

P5-05 已完成内部 V2 的实心蜡烛、平滑分时线、面积渐变和 legacy 指标视觉语义迁移；P5-06 已清理 legacy 状态链路；P5-07 已冻结多尺寸、主题和副图 Golden，并在 Widget 帧断言 Layer repaint 计数。完整证据见 `KLINE_V2_CHART_MODE_PROTOCOL.md` 与 `KLINE_V2_GOLDEN_REPAINT_GATE.md`。

## 7. 自动门禁

- 标准 Stack ID/顺序/依赖集合；
- 背景和确定性网格像素；
- 涨/跌蜡烛颜色；
- line/histogram/points 副图输出；
- panel 数值轴和 time axis 输出；
- marker/drawing/crosshair 分色独立输出；
- hidden/越界 crosshair 零输出；
- drawing ID、坐标和集合不可变；
- 缓存命中/失效、容量 LRU、clear/dispose、双实例隔离；
- 模块依赖、Renderer 纯度和 `saveLayer` 扫描。
- 三组尺寸/主题/副图 Golden，及 Widget 帧的 selection/viewport Layer repaint 计数。
