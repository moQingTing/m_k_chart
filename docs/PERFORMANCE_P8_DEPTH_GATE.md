# m_k_chart 2.0 P8-06 深度 10 Hz 性能门禁

> 任务：P8-06 / BN-O06
>
> 日期：2026-09-03
>
> 结论：1,000 买档 + 1,000 卖档在 10 Hz 更新下通过 Host 回归和 Android Profile 帧门禁。

## 1. 场景与口径

- 本地盘口始终保存 1,000 买档 + 1,000 卖档，每个事件更新买卖各 8 档；
- 每侧保留 1,000 档参与累计，累计曲线最多采样为 160 点，首尾与最外累计量保持精确；
- Host Debug 连续执行 600 次事件，等价于 10 Hz 持续 60 秒，不进行实际等待；
- Android Profile 使用 100 ms 定时器，预热 20 次后连续采样 100 次更新；
- Host 结果用于稳定回退检测，真机 `FrameTiming` 才用于 16.7 ms UI/Raster 帧门禁。

## 2. Host Debug 回归

环境：macOS、Flutter Test Host Debug。耗时单位为微秒。

| 场景 | P50 | P95 | P99 | 结论 |
| --- | ---: | ---: | ---: | --- |
| 1,000×2 档增量合并 | 463 | 904 | 1,148 | 记录 |
| 累计与 160×2 采样准备 | 54 | 113 | 472 | 记录 |
| 160×2 Canvas 指令录制 | 597 | 1,037 | 1,517 | 记录 |
| 合并到 Canvas 端到端 | 1,167 | 1,928 | 2,510 | P95 ≤16,700，通过 |
| 相同盘口缓存重绘 | 543 | 1,130 | 2,813 | P95 ≤5,000，通过 |

同一进程采样前后 RSS 粗略增加 20,492,288 bytes。它包含测试框架、Picture 和运行时抖动，不等同于深度对象 retained size。

## 3. Android Profile 真机

环境：Samsung SM-G986U1、Android 13 / API 33、Flutter Profile、Impeller Vulkan/OpenGLES。

| 指标 | 样本 | P50 | P95 | P99 | 预算/结论 |
| --- | ---: | ---: | ---: | ---: | --- |
| UI Build | 100 | 4.817 ms | 5.309 ms | 5.611 ms | ≤16.7 ms，通过 |
| Raster | 100 | 2.904 ms | 3.360 ms | 5.081 ms | ≤16.7 ms，通过 |
| 增量合并 | 100 | 2.478 ms | 2.611 ms | 2.785 ms | 记录 |
| 曲线准备 | 100 | 0.323 ms | 0.427 ms | 0.521 ms | 记录 |

采样结束时盘口仍为 1,000×2 档且同步状态为 `synchronized`。完整应用进程 Total PSS 为 140,100 KB、Total RSS 为 248,176 KB；该值包含 Flutter Engine、代码映射、字体和图形缓冲，仅作为同设备整进程基线。

## 4. 复现

Host 回归：

```bash
flutter test \
  --dart-define=RUN_DEPTH_BENCHMARK=true \
  test/benchmark/depth_pipeline_benchmark_test.dart
```

Android Profile：

```bash
cd example
flutter run --profile --no-resident \
  -d <android-device-id> \
  -t lib/v2_depth_performance_main.dart
adb -s <android-device-id> logcat -d -v brief | grep v2_depth_profile_result
adb -s <android-device-id> shell dumpsys meminfo com.example.m_k_chart_example
```

普通全量测试默认跳过 Host 高频基准，避免非固定开发机抖动造成偶发失败。Profile 宿主只用于性能验收，不从正式包入口导出。
