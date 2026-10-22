# V2 发布说明与后续验证

更新：2026-10-22。目标发行版为 `m_k_chart 2.0.0`，唯一公开入口为
`package:m_k_chart/m_k_chart.dart`。V1 `KChartWidget` 兼容接口继续保留；V2 新增 `KChart`、
`KChartController` 和 65 个受控语义类型。宿主不应依赖 `src`、Renderer 或 Example 桥接路径。

## 本库验收范围

库的职责是图表渲染、手势、控制器数据替换/追加、选中状态和 Widget 自身资源释放。确定性模拟
K 线可覆盖替换/追加，无需将真实交易所网络作为前置条件。断线重连、宿主后台刷新、行情缓存和绘图
持久化介质由接入方负责，不作为本库发布门槛。

## 已执行的验证

- 根目录 `flutter test --no-pub`：644 项通过，19 个 Host benchmark 按配置跳过。
- Example 测试：6 项通过；iPhone 16 Pro / iOS 18.2 模拟器三个集成 target 共 5 项通过。
- 默认 Demo 与 V2 SDK 验收页 Web Release 构建通过；Web 浏览器人工交互/布局检查仍可作为后续完善。
- 公开 API allowlist、外部宿主编译探针、facade 契约和文档门禁通过；`dart pub publish --dry-run`
  识别 `m_k_chart 2.0.0`，归档约 2 MB。

## 后续完善（非发布阻挡项）

- 补充 Android/iOS Profile UI/Raster 与内存矩阵；现有 Host benchmark 不代表设备帧率。
- 完成 Web 浏览器人工布局/交互检查及 VoiceOver/TalkBack 人工体验。
- 按宿主需要接入网络恢复、后台刷新和绘图持久化适配；这些不是本库必须提供的能力。

本轮已在 Samsung SM-G986U1 Android 真机完成 Debug 安装/启动和短时 Binance BTCUSDT 1 分钟行情
可选演示；行情真实加载、主图/成交量副图可见，截图留档于
[`v2-android-sm-g986u1-binance-btcusdt-1m.png`](release-evidence/v2-android-sm-g986u1-binance-btcusdt-1m.png)。
该演示未跨越完整分钟边界，不作为库增量行为的唯一证据（替换/追加已有模拟数据测试）；也不代表
Profile 性能、签名包、全量设备矩阵或最终归档已核验。

另在 iPhone 16 Pro / iOS 18.2 模拟器留存两张当前公开 API 的 Debug 视觉证据：
[最小接入页（离线模拟 K 线）](release-evidence/v2-ios-iphone16pro-minimal-chart.png)适合作为图表主体展示；
[SDK 验收页](release-evidence/v2-ios-iphone16pro-sdk-acceptance.png)展示配置与绘图操作布局。
两张均为 Debug 模拟数据截图，不应标注为实时行情。

2026-10-22 全量自动化记录：根目录 `flutter test --no-pub` 最新通过 644 项，19 个 Host benchmark
用例按配置跳过；`example/flutter test --no-pub` 通过 6 项；iPhone 16 Pro / iOS 18.2 模拟器
运行全部 3 个 integration target、共 5 项通过。Golden 基线经审阅更新了极值标记视觉变化。
当前复验的根目录 analyzer 有 290 条既有 lint（含 info 和 1 条 warning），Example 有 15 条 info；
均未观察到 analyzer error。该记录不表示 lint 全零或设备性能基准已通过。
V2 API 接入改为正式入口后，三个 iOS 模拟器 integration target 再次全部通过；默认 Demo 与
`v2_sdk_acceptance_main.dart` 均通过 Web Release 构建。Web 浏览器交互与布局人工验收仍未完成。

## 接入路径

- 1.x 项目继续使用 `package:m_k_chart/m_k_chart.dart` 的 `KChartWidget` 兼容 API；
  主题与用户配置可按 `MIGRATING_TO_V2.md` 渐进采用。
- V2 接入示例 `example/lib/v2_minimal_chart_main.dart` 和
  `example/lib/v2_sdk_acceptance_main.dart` 只 import 正式入口，可作为 `m_k_chart: ^2.0.0` 参考。
- 详细开发任务与各批测试记录以 `KLINE_V2_SDK_OPTIMIZATION_PLAN.md` 为准；
  设备未验证项以 `KLINE_V2_DEVICE_ACCEPTANCE.md` 为准。
