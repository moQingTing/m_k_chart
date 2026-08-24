# m_k_chart 1.x 性能基线

> 状态：Phase 0 已完成
> 记录日期：2026-08-24
> Flutter：3.44.0
> 基准代码：`test/benchmark/current_architecture_benchmark_test.dart`
> Android 入口：`example/lib/performance_main.dart`

## 1. 场景和口径

- 确定性数据：100、2,000、10,000 根一分钟 K 线。
- 图表场景：MA 主图，MACD + VOL 两个副图。
- 主机交互尺寸：390 × 600 logical pixels。
- 主机结果来自 Flutter Test Debug，只用于后续相同环境的相对对比，不作为 2.0 发布门禁。
- Android 结果来自 Profile APK + 系统手势注入 + SurfaceFlinger 实际呈现时间戳。
- Android 有效帧间隔排除大于 100 ms 的手势间空闲时间。

## 2. 主机计算基线

| 场景 | 数据量 | 中位数 |
| --- | ---: | ---: |
| 全量指标计算 | 100 | 2,938 μs |
| 全量指标计算 | 2,000 | 18,477 μs |
| 全量指标计算 | 10,000 | 104,537 μs |
| 更新最后一根 K 线 | 10,000 | 3 μs |

结论：实时更新必须走增量路径。10,000 根全量计算已经超过 2.0 的实时更新预算，但当前最后一根增量入口成本很低，可作为新指标协议的对照基线。

## 3. 主机交互基线

| 场景 | 数据量 | 有效样本 | 中位数 |
| --- | ---: | ---: | ---: |
| 水平拖动 + pump | 2,000 | 50 | 8,719 μs |
| 双指缩放 + pump | 2,000 | 18 | 9,798 μs |
| 十字线移动 + pump | 2,000 | 40 | 7,601 μs |

缩放只得到 18 个有效重绘样本，是因为旧长按识别器会在双指序列持续期间介入；未安排重绘的 pump 已从统计中排除。

## 4. Android Profile 上屏基线

设备：Samsung SM-G986U1，Android 13 / API 33，60 Hz，1080 × 2400 override resolution。

操作：启动 2,000 根、MA + MACD + VOL 的独立 Profile App，左右交替注入 16 次 300 ms 水平拖动。

| 指标 | 结果 |
| --- | ---: |
| 刷新周期 | 16.666666 ms |
| SurfaceFlinger 捕获呈现帧 | 127 |
| 有效活动帧间隔 | 119 |
| P50 | 16.627188 ms |
| P90 | 16.656667 ms |
| P95 | 16.675208 ms |
| P99 | 16.709739 ms |
| 最大有效间隔 | 16.748593 ms |
| 超过 1.5× 刷新周期 | 0 |
| 估算丢失 VSync | 0 |

SurfaceFlinger 数据代表最终呈现节奏，不提供 Flutter UI/Raster 线程各自耗时。Phase 5 的 `P5-08` 仍必须使用 Flutter 原生 FrameTiming/DevTools 补齐 UI、Raster、内存和 GC 门禁，不能以本表替代。

## 5. 已确认缺陷和限制

1. 单指拖动同时触发 Scale 和 HorizontalDrag 回调，证实旧手势竞争不正确。
2. 双指缩放持续后会被长按识别器介入，导致缩放有效重绘提前停止。
3. 默认十字线信息框在固定 110 px 宽度下产生 RenderFlex overflow；基准使用最小自定义 info window 隔离该问题。
4. `integration_test` Profile 绑定在 `pumpWidget` 等待首帧时超时 45 秒；正常 Profile App 可在约 465 ms 完成冷启动 Activity，因此判定为旧 Widget 与测试绑定兼容限制，而非正常 App 无法启动。
5. `flutter analyze` 当前存在 269 条历史 info，无新增 error/warning；历史 lint 债务不得混入性能基线任务批量修改。

## 6. 复现方式

主机指标与交互：

```bash
flutter test --dart-define=RUN_KLINE_BENCHMARK=true test/benchmark/current_architecture_benchmark_test.dart
```

Android Profile：

```bash
cd example
flutter build apk --profile --target=lib/performance_main.dart
adb -s <device-id> install -r build/app/outputs/flutter-apk/app-profile.apk
cd ..
dart run tool/android_profile_baseline.dart <device-id> com.example.m_k_chart_example
```

比较性能时必须使用相同 Flutter 版本、设备、显示刷新率、数据规模和指标配置。每次结果保存 P50/P90/P95/P99，不得只比较单次最小值。
