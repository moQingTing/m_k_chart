# K 线 2.0 Renderer 缓存协议

> 任务：P5-03
>
> 状态：已实现
>
> 日期：2026-08-25

## 1. 所有权与边界

每个 `StandardChartRenderPipeline` 持有一个独立 `ChartRenderCache`，并在 `dispose()` 时统一释放。调用方注入缓存时，Pipeline 同样取得其所有权。render 模块的实例隔离门禁禁止 mutable static 状态，因此两个图表不会共享条目、命中计数或原生绘制资源。

缓存只保存由不可变 `RenderSnapshot` 派生的绘制数据，不保存 Canvas、Controller、业务状态或异步任务。`clear()` 清空条目但保留累计诊断计数；`dispose()` 可重复调用，之后的所有访问都抛出 `StateError`。

## 2. 缓存项与默认上限

| 类型 | 内容 | 默认容量 | 失效键 |
| --- | --- | ---: | --- |
| window | `VisibleIndexRange`、`ChartXTransform` | 32 | data version、render data/viewport version、Viewport 值 |
| extrema | 可见 OHLC high/low 及索引 | 32 | 同 window |
| panel range | 合并 OHLC/指标后的 panel 值域 | 32 | window key、layout version、panel ID |
| text | 已 layout 的 `TextPainter` | 128 | 文本、ARGB、字号 |
| path | 指标 line `Path` | 64 | 指标实例/Series、数据/视口/layout 版本、panel、价格变换 |
| picture | 背景与网格 `Picture` | 8 | layout/theme version、Layout 值 |

所有存储均为 LRU 且拒绝非正容量。`TextPainter` 和 `Picture` 在淘汰、clear 与 dispose 时释放；`Path` 由 Dart 对象生命周期管理。统计快照以不可修改 Map 暴露每类 hit/miss。

## 3. 绘制链路

- 主图、Axis 与 Marker 复用同一 panel range；Marker 直接复用可见 OHLC 极值。
- Main、Secondary 与 Axis 复用同一可见窗口和经过时间轴校验的 X Transform。
- line 指标复用 Path；histogram/points 仍只遍历可见范围并直接绘制。
- Axis、Marker 与 Crosshair 复用已布局文本。
- Grid 录制为 Picture，尺寸、布局或主题版本变化时重新生成。

选择版本不属于 geometry key，因此仅移动十字线不会冲掉可见窗口、极值或值域。数据、Viewport、Layout 或 Theme 的调用方版本必须单调反映对应输入变化；P5-04 已使用相同切片版本决定 Layer 是否需要重录。

## 4. 已知边界

- 当前极值和值域是“精确可见窗口 + 有界 LRU”。相同窗口不会重复扫描，但连续 pan 到新窗口仍会扫描可见数据；`PERF-12` 的滑动窗口/分块 min-max 或 Segment Tree 仍未关闭。
- `PERF-23` 只完成 Path 与 TextPainter 复用；Paint 池化留待完整视觉迁移后评估，避免提前固化样式组合。
- Host Debug 基准只覆盖缓存热路径的 Canvas 命令录制，不代表真机 UI/Raster、内存或 GC。最终预算由 P5-08 固定 Profile 设备门禁判定。

## 5. 自动化证据

- selection-only 命中与 data/viewport 版本失效；
- panel range 与 OHLC extrema 跨 Layer 复用；
- Text/Path/Picture LRU 容量、命中计数与重建；
- clear、幂等 dispose、dispose 后拒绝访问；
- 两实例缓存与计数隔离；
- 完整标准 Pipeline 第二帧六类缓存均命中；
- 2,000 根 + 2 副图 Host Debug 热路径基准。
