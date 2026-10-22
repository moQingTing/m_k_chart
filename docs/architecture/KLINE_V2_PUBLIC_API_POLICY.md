# K 线 2.0 公共 API 与兼容策略

> 任务：P1-05  
> 状态：已实现  
> 日期：2026-08-24

## 1. 唯一正式入口

`package:m_k_chart/m_k_chart.dart` 是唯一正式公共入口。`flutter_k_chart.dart` 仅为旧项目保留，已标记 deprecated，并只转发正式入口，不再维护第二份导出列表。

`lib/src`、legacy `renderer` 和其他实现文件不是稳定 API。Dart 允许宿主深路径 import 不代表兼容承诺；2.0 迁移指南将要求移除这类引用。

## 2. 当前兼容面

`tool/public_api_allowlist.txt` 冻结正式入口当前暴露的文件和符号。P6-01 已经审核并加入首个 V2 样式值对象 `KChartTheme` 及其 `ChartColorsThemeAdapter`；其余 1.x 兼容面保持不变。自动测试拒绝：

- 正式入口意外新增或删除导出；
- `lib/src` 或 Renderer 被正式入口提前导出；
- 旧入口与正式入口再次发生漂移；
- 已导出文件新增或删除顶层公共声明但未评审 allowlist。

allowlist 的变化属于 API 变更，必须关联任务、迁移说明和版本策略，不能把更新快照当作修复测试的默认方式。

## 3. Deprecated 分组

| 分组 | 符号 | 策略 |
| --- | --- | --- |
| 重复入口 | `flutter_k_chart.dart` | 立即 deprecated，整个 2.x 保留转发 |
| 旧数据/计算 | `KLineEntity`、`DataUtil` | P2 adapter 可用时添加代码级 deprecated，2.x 保留 |
| enum 指标选择 | `MainState`、`SecondaryState` | P3 注册式指标可用时 deprecated，2.x facade 内保留 |
| 旧 Widget | `KChartWidget` | 2.x 作为 legacy facade 保留，不在新功能上扩展 |
| 意外暴露实现 | `KChartWidgetState`、三个自定义 Recognizer、`DepthChartPainter` | 兼容冻结但不作为 2.0 新 API；只允许在主版本边界配合迁移指南移除 |

代码级 deprecated 必须在替代 API 已可用时添加，避免用户收到无法消除的警告。因此本任务只立即标记已经有等价替代的重复入口。

## 4. 2.0 新 API 准入

新类型满足以下条件后才能从 `m_k_chart.dart` 导出：

1. 所属 Phase 接口和行为测试通过；
2. 命名、不可变性和生命周期完成评审；
3. 不暴露 Painter、Renderer、Widget State、Store 可变容器或临时桥接事件；
4. 更新 allowlist、API 草案和迁移指南；
5. API diff 门禁确认只包含预期变化。

内部协调器仍不是公开类型；通过根目录 `k_chart_v2_api.dart` 的显式转发，仅开放审核后的语义子集。
2026-10-22：数据模型、Controller 用户操作、Widget facade 与数据/指标/绘图语义类型已完成源码级准入。
新增 API 经 `tool/public_api_allowlist.txt` 冻结，并由仅导入 `m_k_chart.dart` 的宿主编译探针
覆盖创建图表、配置指标、更新行情、接收选择/错误回调和设置覆盖物/绘图。发布包的编译核验仍属
P9 发布门禁；只有版本发布后，才承诺对应版本的兼容性。

OPT-02 已通过 [ADR-002](ADR-002_V2_SDK_FACADE_CONTRACT.md) 冻结基础接入设计。
新增 KlineSeries、KChartDataSession、KChartDataCommands、KChartDataCoordinator 及其运行时快照和生命周期守卫仍属于内部实现，
不改变本文件的准入标准或当前 allowlist；守卫类不会作为正式 SDK 类型导出。

2026-10-15：`k_chart_facade.dart` Controller 与显式 show 集合先以仓库候选形式供集成测试使用；
配置几何方法移到未导出的内部扩展。旧内部同名事件控制器和 Demo 导入保持不变。
2026-10-20：候选 show 集合补充图例声明类型；实例级可见序列作为候选绑定值对象字段，
严格名单测试已同步；当时正式入口及 allowlist 未改变。
2026-10-22：V2 语义类型经 `k_chart_v2_api.dart` 从唯一正式入口开放；allowlist 与公共 API diff
同步更新，宿主探针和 Example 的 V2 接入示例改为只 import 正式入口。2.0.0 将该受控 API 集合
纳入稳定兼容面；后续只允许按语义化版本策略演进。

`KChartTheme` 与 `KChartUserConfig` 是上述规则已批准的例外：前者只暴露不可变颜色、尺寸和指标调色板值；后者只暴露 JSON 安全的用户偏好与版本迁移，不泄露内部绘制接口、任意 Renderer 类型或持久化实现。具体约束见 `KLINE_V2_THEME_PROTOCOL.md` 与 `KLINE_V2_USER_CONFIG_PROTOCOL.md`。
