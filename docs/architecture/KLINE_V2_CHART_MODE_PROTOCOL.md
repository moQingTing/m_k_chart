# K 线 2.0 主图模式与指标视觉协议

> 任务：P5-05
>
> 状态：已实现（内部 V2 Layer）
>
> 日期：2026-08-26

## 1. 主图模式

`RenderSnapshot.mainMode` 冻结主图为以下三种互斥模式：

| 模式 | 主数据 | 值域 | 输出 |
| --- | --- | --- | --- |
| `candlestick` | open/high/low/close | 可见 high/low，并合并主图指标 | 涨跌实体与影线，以及主图指标 |
| `line` | close | 可见 close | 平滑收盘价线 |
| `area` | close | 可见 close | 平滑收盘价线及到底部的纵向渐变填充 |

`line` 与 `area` 沿用 legacy 分时线的收盘价语义；两种模式不绘制主图指标，避免把蜡烛量程指标错误叠加到分时值域。P6 将再扩展蜡烛变体和 Heikin-Ashi，本任务只保留实心蜡烛。

模式属于 theme 可见配置的一部分：调用方切换模式时必须推进 `theme` 版本，使保留式 Layer 合成器重录受 theme 影响的 Layer。缓存同时将 mode 纳入主图极值、主图值域与主图 Path key；可见窗口/X 变换不依赖 mode，继续复用。

## 2. 样式边界

`ChartRenderStyle` 增加只读的主图视觉值：`mainLineColor`、`areaFillColors`、`mainLineStrokeWidth`、`candleWidthRatio`、`histogramWidthRatio` 和 `indicatorPointRadius`。默认样式在构造时复制渐变色列表、拒绝空渐变和非法比例/尺寸，Layer 不读取 legacy 可变主题。

## 3. 指标语义

Renderer 继续只解释 `IndicatorRendererDescriptor`，不对 definition ID 分支：

| 描述符语义 | 用途 | V2 绘制规则 |
| --- | --- | --- |
| `series` | 普通 line/points/histogram | 稳定 instance/series palette 色 |
| `candleDirection` | Volume 柱 | close ≥ open 为 up，否则为 down |
| `valueSign` | MACD 柱 | 非负为 up，负为 down |
| `pricePosition` | SAR 点 | 值在 close 下/等于 close 为 up，否则为 down |
| `valueTrend` | MACD 柱形样式 | 与前一值比较；正值未增长、负值增长时使用空心描边 |

这套中立语义同时适用于自定义指标和同定义多实例。MA、EMA、BOLL、KDJ、RSI、WR、OBV 等仍通过既有 line/points Descriptor 路径绘制，不需要 Renderer enum 或 switch 扩展。

## 4. 验证边界

- 离屏像素测试确认三种主图模式的可见输出及面积填充；
- 几何与缓存测试确认 line/area 使用 close 值域、切换模式只失效主图 extrema/range，不丢失 visible window；
- Descriptor 测试确认 Volume、MACD、SAR 的颜色/空心语义及非法组合被拒绝；
- production Painter、正式包入口和 Demo 尚未接线；P5-07 负责 Golden 与 Widget repaint 计数，P5-08 负责真机 Profile/内存/GC 门禁。
