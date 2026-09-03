# K 线 V2 P9-01 发布质量门禁

> 任务：P9-01
>
> 状态：已通过
>
> 日期：2026-09-03

## 1. 验证环境

- Host：macOS 26.5.1，x86_64；
- Flutter：3.44.0 stable；Dart 3.12.0；
- Android 集成设备：Samsung SM-G986U1，Android 13（API 33）；
- 测试数据：离线确定性 K 线、10,000 根指标数据、1,000 买档 + 1,000 卖档深度数据。

## 2. 自动化入口

执行 `FLUTTER_BIN=/path/to/flutter tool/run_p9_host_gate.sh [device-id]` 可依次运行静态检查、根包全量测试、Example 测试、全部 Host benchmark，以及可选的真机集成测试。

性能文件必须逐进程串行执行。若把整个 `test/benchmark` 目录作为一个 `flutter test` 目标，flutter_test 会并发调度多个 CPU/内存密集任务，结果反映的是 Host 资源争用而非单条图表流水线。本轮并发诊断曾使两个六指标 P95 分别升至 19.008 ms 和 9.474 ms；按基线约定串行重测后分别为 6.350 ms 和 4.234 ms，均通过 8 ms 门禁。

## 3. 功能与视觉结果

| 门禁 | 结果 |
| --- | --- |
| `flutter analyze --no-fatal-infos --no-fatal-warnings` | 通过，无 error；仅保留仓库既有 legacy lint 提示 |
| 根包 unit/widget/golden | 359 通过；13 个按默认配置跳过的显式 benchmark |
| Example widget/client | 4 项通过 |
| V2 Golden | 6 个尺寸/主题/主图模式基线一致 |
| Android integration | 1 个端到端流程通过 |

Android 集成流程使用 `loadOnStart: false`，不受公网状态影响，覆盖启动、全屏路由、点击 K 线详情、历史拖动、最新价返回、周期切换和 Widget 销毁。

## 4. 串行 Host benchmark 结果

以下均为 Debug Host 回归信号，不替代 P9-02 的 Profile/Release 设备测量。

| 模块 | 关键指标 | 本轮结果 | 门禁 |
| --- | --- | ---: | ---: |
| KlineStore | replace / prepend / append / update P95 | 0.247 / 0.402 / 0.401 / 0.391 ms | prepend / append ≤ 50 ms |
| 核心六指标 | last update 10,000 P95 | 6.350 ms | ≤ 8 ms |
| 附加六指标 | combined last update P95 | 4.234 ms | ≤ 8 ms |
| 迁移十指标 | combined last update P95 | 2.760 ms | ≤ 8 ms |
| IndicatorCache | full / incremental / exact hit P95 | 0.816 / 1.342 / 0.003 ms | 通过各自预算 |
| Interaction | pan / scale / crosshair dispatch P95 | 0.01279 / 0.00315 / 0.00186 ms | ≤ 1 ms |
| Retained Render | warm / unchanged / selection P95 | 0.917 / 0.196 / 0.334 ms | ≤ 10 / 3 / 3 ms |
| Depth 10 Hz | end-to-end / cached repaint P95 | 1.897 / 1.025 ms | ≤ 16.7 / 5 ms |

旧 Widget 的 2,000 根中位数为拖动 3.757 ms、缩放 8.461 ms、十字线 7.791 ms；10,000 根全量指标计算中位数为 81.481 ms，最后一根增量计算为 0.003 ms。它们作为兼容基线记录，不用于替代 V2 retained pipeline 的 P95 门禁。

## 5. 结论与后续

P9-01 的 unit、widget、golden、integration 和 benchmark 均有可重复入口并已通过。下一步执行 P9-02：Android/iOS/Web Profile 与 Release 构建；Flutter 已报告 Example 的旧 Kotlin Gradle Plugin 应用方式将在未来版本失效，该兼容提示纳入 P9-02 构建审计，不影响当前 Android 集成测试。
