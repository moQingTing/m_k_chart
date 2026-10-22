# m_k_chart 2.0 P5-08 Profile 帧、内存与 GC 门禁

> 任务：P5-08
>
> 日期：2026-08-26
>
> 结论：2,000 根 + 2 副图的 V2 渲染帧预算通过；整进程内存/GC 已记录。

## 1. 环境与宿主

- 设备：Samsung SM-G986U1，Android 13 / API 33；
- 构建：Flutter Profile，内部 `example/lib/v2_performance_main.dart`；
- 场景：2,000 根 Kline、390×600 logical px、1 主图 + Volume/Momentum 2 副图；
- 驱动：每帧交替推进 selection 与 viewport 版本，`StandardChartRenderPipeline` 保留 Picture；指标投影在启动时一次构造，循环期间复用；
- 采样：`WidgetsBinding.addTimingsCallback` 的连续 Profile FrameTiming 批次，每批 6～7 帧。

该宿主只服务性能门禁，不从正式包入口导出，也不替代 Phase 6 的公开 V2 Widget。

## 2. 帧结果

修正每帧指标投影分配后，连续采样中观察到的最高批次 P95 如下：

| 指标 | 最高批次 P95 | 预算 | 结论 |
| --- | ---: | ---: | --- |
| UI build | 2.107 ms | ≤16.7 ms | 通过 |
| Raster | 3.506 ms | ≤16.7 ms | 通过 |

由于每个 FrameTiming 回调按 6～7 帧批量交付，报告保守取所有批次 P95 的最大值；它不是将所有原始帧跨批次重新排序后的精确全局 P95。所有记录的批次仍显著低于 60 Hz 预算。

Host 回归基准同时复跑：缓存热路径 P95 1,436.65 μs；保留无变化 P95 227.0 μs；selection-only P95 246.6 μs，均通过既有 Host 阈值。

## 3. 内存与 GC

`adb shell dumpsys meminfo com.example.m_k_chart_example` 在稳定运行后记录：

| 指标 | 结果 |
| --- | ---: |
| Total PSS | 175,092 KB |
| Total RSS | 283,672 KB |
| Native Heap PSS | 22,760 KB |
| Graphics PSS | 60,232 KB |

该值为完整 Android 应用进程，包含 Flutter engine、代码映射、系统字体与图形缓冲，不可与“10,000 根 + 6 指标增量 ≤35 MB”直接比较。该增量内存目标仍需在 Phase 6 的正式 V2 Widget 与完整指标配置接线后，以进程前后差或 DevTools heap snapshot 单独复测。

本进程 logcat 观察到一次 concurrent-copying GC：释放 2,242 KB，暂停 42 μs 和 12 μs，总计 9.509 ms；没有连续五帧严重掉帧的 FrameTiming 信号。该 GC 记录用于确认稳态下存在可观测且短暂停顿的回收，不声称为 Dart heap 的 retained-size 分析。

## 4. 复现

```bash
cd example
flutter pub get
flutter run --profile -d <android-device-id> -t lib/v2_performance_main.dart
adb -s <android-device-id> logcat -d -v brief | grep v2_profile_frame_timing_batch
adb -s <android-device-id> shell dumpsys meminfo com.example.m_k_chart_example
```

## 5. 后续边界

- P5 的 2,000 根 + 2 副图 UI/Raster、整进程内存和 GC 记录已完成；
- P6/P9 仍需在公开 V2 Widget、10,000 根与完整六指标配置下复测增量内存，并补 iOS/Web Profile；
- 低端设备 24 ms 降级目标、十字线端到端输入延迟和发布级多平台矩阵继续由后续 Phase 质量门禁覆盖。
