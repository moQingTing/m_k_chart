# K 线 2.0 Golden 与 Widget 重绘门禁

> 任务：P5-07
>
> 状态：已实现
>
> 日期：2026-08-26

## 1. 视觉基线矩阵

`test/render/standard_chart_golden_test.dart` 使用真实 `StandardChartRenderPipeline` 和 `RenderSnapshot` 生成以下离屏 Widget Golden：

| Golden | 逻辑尺寸 | 主题 | 主图 | 副图 |
| --- | ---: | --- | --- | --- |
| `wide_dark_candlestick.png` | 360 × 320 | 深色 | 蜡烛 | Volume、Momentum |
| `compact_light_area.png` | 240 × 260 | 浅色 | 面积 | Volume |
| `tall_dark_line.png` | 300 × 520 | 深色 | 分时线 | Volume、Momentum、Flow |

三组画面均包含网格、主图、轴、marker、crosshair 和声明式 line/histogram 指标。测试先固定 Flutter test surface 为场景尺寸，再截取实际 `CustomPaint` RenderBox，避免默认测试 surface 的透明留白进入基线。

Golden 是可审阅的视觉回归门禁；更新必须通过 `flutter test --update-goldens test/render/standard_chart_golden_test.dart` 明确执行，并在变更说明中解释视觉意图。

## 2. Widget 重绘计数

同一测试文件将真实 Pipeline 放入 `RepaintBoundary` 内的 `CustomPaint` 宿主，并断言：

1. 首帧重录全部标准 Layer；
2. selection version 变化时 Widget 帧报告只重录 `crosshair`，主图累计 repaint 不增加；
3. 相同 Snapshot 重建不触发 CustomPainter 再绘制；
4. viewport version 变化时只重录 `main`、`secondary`、`axis`、`marker`，grid 与 crosshair 继续复用。

这使 P5-04 的 retained Picture 诊断从离屏 Canvas 单元测试提升到真实 Widget 绘制帧，而无需让测试宿主成为正式公开 API。

## 3. 边界

- P5-07 覆盖内部 V2 Pipeline；production V2 Widget 接线与 Alpha public API 仍在 Phase 6；
- Golden 在当前 Flutter test engine 上冻结，字体或 Flutter engine 升级导致的像素变化必须经人工审阅；
- 真机 UI/Raster、内存与 GC 性能不由 Golden 代替，继续由 P5-08 Profile 门禁判定。
