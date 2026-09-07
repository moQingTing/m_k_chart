# m_k_chart 2.0 P5-04 Layer 重绘基线

> 任务：P5-04
>
> 日期：2026-08-25
>
> 环境：macOS、Flutter 3.44.0、Dart 3.12.0、Flutter Test Host Debug

## 1. 场景与口径

- 2,000 根 K 线、390×600 logical px、item extent 8、距最新端 200 根；
- 1 个主图 line 指标，2 个副图分别绘制 histogram 和 line；
- 先生成标准七层保留 Picture，再分别测量版本完全不变和 selection-only 连续变化；
- 每个场景预热 20 帧，记录 100 个批次，每批 20 帧并折算单帧耗时；
- 每帧创建外层 `PictureRecorder` 并按固定顺序复合七层 Picture；selection-only 额外重录 Crosshair；
- 两个场景的 Host Debug P95 回归阈值均为 3,000 μs。

## 2. 结果

| 场景 | 重录 Layer | P50 | P95 | P99 | P95 阈值 | 结论 |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| 版本完全不变 | 0/7 | 309.7 μs | 414.9 μs | 459.85 μs | ≤3,000 μs | 通过 |
| selection-only | crosshair，1/7 | 375.15 μs | 487.6 μs | 534.5 μs | ≤3,000 μs | 通过 |

基准在每个 selection 样本中断言 `repaintedLayerIds == ['crosshair']`，同时确认 grid 始终只录制一次，避免“耗时通过但失效范围错误”。

## 3. 解释与限制

Host Picture 录制结果用于验证调度数量级和稳定性，不代表真机 Raster 一定更快。复合七张嵌套 Picture 本身有固定成本；该优化的核心证据是昂贵的数据 Layer 未被重复执行，而不是宣称 Host 微基准必然低于 P5-03 的直接 Layer Stack 录制。

本基准不包含 Widget build、RepaintBoundary、VSync、GPU Raster、Picture 上传、内存峰值或 GC。P5-07 继续验证 Widget repaint 次数和 Golden，P5-08 在固定 Profile 设备完成最终帧预算。

## 4. 复现

```bash
flutter test \
  --dart-define=RUN_KLINE_BENCHMARK=true \
  test/benchmark/render_cache_benchmark_test.dart
```

普通全量测试默认跳过这两个 Host 基准。
