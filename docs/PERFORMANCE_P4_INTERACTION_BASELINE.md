# m_k_chart 2.0 Phase 4 输入状态管线基线

> 任务：P4-07
>
> 日期：2026-08-25
>
> 环境：macOS、Flutter 3.44.0、Dart 3.12.0、Flutter Test Host Debug

## 1. 场景与口径

- 每个样本包含 `ChartInteractionMachine` 从输入状态生成 intent，以及 `KChartController.dispatchInteraction` 提交不可变状态。
- 平移、缩放和十字线各预热 200 次，记录 200 个批次；每批执行 100 次后折算单次耗时，降低微秒计时器离散误差。
- 使用 2,000 根数据规模对应的 Viewport，宽 390、item extent 8、scroll 200。
- 门禁为 Host Debug 状态管线 P95 ≤ 1,000 μs，用于尽早发现纯 Dart 状态处理回退。

## 2. 结果

| 场景 | P50 | P95 | P99 | P95 预算 | 结论 |
| --- | ---: | ---: | ---: | ---: | --- |
| pan intent + controller dispatch | 2.25 μs | 16.42 μs | 24.17 μs | ≤1,000 μs | 通过 |
| scale intent + controller dispatch | 0.65 μs | 3.46 μs | 5.99 μs | ≤1,000 μs | 通过 |
| crosshair intent + controller dispatch | 0.92 μs | 3.89 μs | 10.22 μs | ≤1,000 μs | 通过 |

## 3. 限制

该基准不包含平台事件传递、Gesture Arena、Widget build、Layer paint、GPU Raster 或屏幕显示，因此不能替代以下发布预算：

- pan/zoom 固定 Profile 设备 P95 UI/Raster ≤16.7 ms；
- 低端设备 P95 ≤24 ms；
- crosshair 输入到帧 P95 ≤32 ms。

Phase 5 在新 Renderer 可运行后使用固定 Profile 设备恢复原生 `FrameTiming`、输入时间戳与 UI/Raster 测量。本报告只冻结 Phase 4 的状态处理基线。

## 4. 复现

```bash
flutter test \
  --dart-define=RUN_KLINE_BENCHMARK=true \
  test/benchmark/interaction_latency_benchmark_test.dart
```

普通全量测试默认跳过此基准，避免开发机抖动成为非固定环境的偶发失败源。
