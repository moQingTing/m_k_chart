# K 线 2.0 Legacy 重绘状态边界

> 任务：P5-06
>
> 状态：已实现
>
> 日期：2026-08-26

## 1. 清理目标

P5-06 处理仍在 1.x `KChartWidget` / `ChartPainter` 中的三类运行时耦合，同时不改变正式包入口和现有 Demo 的使用方式：

| 旧边界 | 新边界 |
| --- | --- |
| `ChartPainter.maxScrollX` 静态共享 | `KChartWidgetState` 使用 `LegacyChartViewportMetrics` 持有本实例滚动上限 |
| Painter Canvas 阶段向 `StreamSink` 推送 InfoWindow | Widget 在长按事件阶段用同一纯几何计算选中 Kline，并经 `ValueNotifier` 发布详情 |
| 手势和闪点动画调用全 Widget `setState` | 仅 `ListenableBuilder` 内的 `CustomPaint` 重建，外层加 `RepaintBoundary`；详情 Overlay 由独立 `ValueListenableBuilder` 更新 |

## 2. 纯几何协议

`LegacyChartViewportMetrics` 只由 itemCount、width、scaleX 和 pointWidth 构造，负责：

- 右侧留白和最小 translateX；
- 实例级 maxScrollX 及滚动夹取；
- chart-local X 到选中 index 的映射；
- index 到当前 local X 的投影，用于 InfoWindow 左右对齐。

Painter 和 Widget 都使用此计算，因此输入事件不需要等待 Canvas paint 才能获得选中数据，也不存在两个图表互相覆盖滚动上限的静态状态。

## 3. Painter 契约

`ChartPainter` 只读取构造输入并输出 Canvas 命令；不得持有或写入 `StreamSink`、`StreamController`、Controller 或 Widget state。`BaseChartPainter.shouldRepaint` 改为比较实际绘制输入，`ChartPainter` 继续补充颜色、副图和 opacity 比较。legacy 可变数据列表仍由调用方在数据变更后调用 `KChartWidgetState.notifyChanged()` 触发局部绘制刷新。

## 4. 验证与后续

- 单测覆盖纯几何的 scroll 边界、选中映射及空/小数据 fallback；
- 架构扫描确认 Painter 不再声明 static maxScroll、StreamSink 或 sink 写入，Widget 不再调用 `setState`/创建 `StreamController`，并存在局部 Listenable 与 RepaintBoundary；
- 原有 legacy Demo adapter 回归继续通过。

V2 Pipeline 的 Layer 精确重绘协议保持不变。P5-07 继续负责多尺寸、多主题和多副图 Golden，以及 Widget repaint 计数；P5-08 继续负责真机 Profile、内存和 GC 门禁。
