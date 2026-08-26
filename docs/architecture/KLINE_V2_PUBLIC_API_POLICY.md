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

因此当前 `lib/src/controller` 仍为内部契约。待数据模型、Controller 用户操作和 Widget facade 完整后，再一次性审核其稳定公共子集。

`KChartTheme` 是上述规则已批准的例外：它只暴露不可变颜色、尺寸和指标调色板值，不泄露其内部绘制接口或任意 Renderer 类型。具体迁移约束见 `KLINE_V2_THEME_PROTOCOL.md`。
