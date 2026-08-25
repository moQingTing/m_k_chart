# K 线 2.0 标准 Layer 协议

> 任务：P5-02
>
> 状态：已实现
>
> 日期：2026-08-25

## 1. 标准绘制顺序

`buildStandardChartLayerStack` 冻结以下顺序：

| 顺序 | Layer ID | 输出 | 依赖切片 |
| ---: | --- | --- | --- |
| 1 | `grid` | 背景、全宽列网格、逐 panel 行网格 | layout、theme |
| 2 | `main` | 涨跌蜡烛、主图指标 | data、viewport、layout、theme |
| 3 | `secondary` | 副图 line/histogram/points 指标 | data、viewport、layout、theme |
| 4 | `axis` | panel 数值标签、实际 openTime 标签 | data、viewport、layout、theme |
| 5 | `marker` | 可见高低点、最新价线和标签 | data、viewport、layout、theme |
| 6 | `drawing` | chart-local 投影线段 | data、layout、theme |
| 7 | `crosshair` | chart-local 十字线和价格标签 | selection、layout、theme |

Crosshair 最后绘制且不依赖 data/viewport，因此 P5-04 可以让选择移动只失效 Overlay，不重新绘制蜡烛和指标。

## 2. 内部绘制样式

`ChartRenderStyle` 是 Phase 5 的最小只读样式接口，包含背景、网格、轴文字、涨跌、marker、crosshair、drawing 颜色，以及各类线宽和轴字号。

`DefaultChartRenderStyle`：

- 冻结 indicator palette，拒绝空 palette；
- 拒绝非有限或非正线宽/字号；
- 使用 instanceId + seriesId 的稳定字符哈希解析 Series 颜色；
- 不依赖 legacy `ChartColors` 或可变 `ChartStyle`。

P6-01 的完整 `KChartTheme` 将实现/扩展该接口，并补齐蜡烛变体、字体、轴位置和语义 style key。

## 3. 值域与坐标

- 每个 Layer 只遍历 `ChartViewport.visibleRange`；
- X 使用 `ChartXTransform.indexToLocalX`，时间轴使用实际 openTime 往返，不假设固定周期；
- 主图值域合并 Kline high/low 与 main 指标中 `includeInRange=true` 的 Series；
- 副图按 panel 汇总 Series，并遵守 Descriptor 的 `includeZeroInRange`；
- 平值范围增加 1% 或 1 的有限 padding，空 panel 使用 0～1 fallback；
- 所有 panel、drawing 和 crosshair 输出使用 chart-local Bounds/clip。

当前多个 Layer 会各自解析同一 panel 值域。该重复计算是 P5-03 极值缓存的明确输入基线，不允许在 paint 中引入跨实例 static 缓存。

## 4. 指标绘制

Layer 不按指标 definitionId 使用 switch：

- `line`：null 断开 Path；
- `histogram`：以零值 Y 为基线并约束到 panel；
- `points`：按有效值绘制点；
- 颜色只按 instanceId/seriesId 从主题解析。

因此内置、自定义以及同定义多实例使用同一绘制路径。递归 computation state 仍不可见。

## 5. Overlay 与绘图

- Marker 从可见 Kline 派生最高/最低点；最新 Kline 可见时绘制最新价；
- Crosshair 只在 visible selection 位于 drawing bounds 内绘制，hidden/越界状态无 Canvas 输出；
- `RenderLineDrawing` 在 Snapshot 装配时校验非空唯一 ID 与有限 local 坐标，公开集合不可写；
- Drawing Layer 只读取 Snapshot 并裁剪到 drawing bounds。P7 将 local 投影替换/扩展为时间、价格锚点与命中状态。

## 6. 纯度与性能边界

- 标准 Layer 不发送事件、不修改状态、不保存 Canvas；
- 使用 `save/clipRect/restore`，架构门禁禁止 `saveLayer`；
- 本阶段不引入 Text/Path/Picture 缓存，避免在失效协议冻结前产生隐式状态；
- production Painter 未接线，旧 Demo 行为不变。

后续任务：P5-03 缓存与可见区优化、P5-04 精确失效、P5-05 完整视觉迁移、P5-07 Golden。

## 7. 自动门禁

- 标准 Stack ID/顺序/依赖集合；
- 背景和确定性网格像素；
- 涨/跌蜡烛颜色；
- line/histogram/points 副图输出；
- panel 数值轴和 time axis 输出；
- marker/drawing/crosshair 分色独立输出；
- hidden/越界 crosshair 零输出；
- drawing ID、坐标和集合不可变；
- 模块依赖、Renderer 纯度和 `saveLayer` 扫描。
