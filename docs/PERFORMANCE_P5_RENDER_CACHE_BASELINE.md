# m_k_chart 2.0 P5-03 Renderer 缓存基线

> 任务：P5-03
>
> 日期：2026-08-25
>
> 环境：macOS、Flutter 3.44.0、Dart 3.12.0、Flutter Test Host Debug

## 1. 场景与口径

- 2,000 根 K 线，390×600 logical px，item extent 8，距最新端 200 根；
- 1 个主图 line 指标，2 个副图分别绘制 histogram 和 line；
- 标准七层 Pipeline 预热 20 帧，随后记录 100 个批次，每批录制 20 帧并折算单帧耗时；
- 每帧创建并结束外层 `PictureRecorder`，Pipeline 内部复用 window/extrema/panel range/TextPainter/Path/Grid Picture；
- Host Debug 回归阈值为 P95 ≤ 10,000 μs。

## 2. 结果

| 场景 | P50 | P95 | P99 | P95 阈值 | 结论 |
| --- | ---: | ---: | ---: | ---: | --- |
| 缓存热路径标准 Pipeline Canvas 录制 | 192.85 μs | 533.35 μs | 741.05 μs | ≤10,000 μs | 通过 |

基准同时断言六类缓存均产生命中，防止结果在缓存未实际接入时误通过。

## 3. 限制

该基准不包含 Widget build、平台 VSync、GPU Raster、Picture 上传、屏幕显示、内存峰值或 GC。它只用于发现主机端绘制命令生成的数量级回退，不能证明 16.7 ms 真机帧预算已经达标。

P5-08 仍需在固定 Profile 设备上测量 2,000 根 + 2 副图的 UI/Raster P50/P95/P99、内存峰值与 GC；连续 pan/zoom 还需覆盖新窗口 cache miss。

## 4. 复现

```bash
flutter test \
  --dart-define=RUN_KLINE_BENCHMARK=true \
  test/benchmark/render_cache_benchmark_test.dart
```

普通全量测试默认跳过该基准，避免非固定开发机抖动造成偶发失败。
