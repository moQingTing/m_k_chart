# K 线 V2 P9-04 公共 API 差异

> 任务：P9-04
>
> 基线：1.0.4（提交 `6225ffb792ae49da407f891d17c4d1b44ac298c8`）
>
> 审计日期：2026-10-22

## 结论

本次 2.0 整改没有删除 1.0.4 的既有正式导出，也没有把 Painter、Renderer、Store、Widget State 或演示桥接层暴露为稳定 API。相对 1.0.4，2.0.0 新增 V2 Widget/Controller、不可变数据与配置、指标描述、覆盖物及绘图语义 API；这些新增类型由 `m_k_chart` 2.0.0 起纳入稳定兼容面。

## 正式入口差异

| 分类 | 1.0.4 | 当前状态 | 迁移影响 |
| --- | --- | --- | --- |
| 正式入口 | `package:m_k_chart/m_k_chart.dart` | 保持唯一入口，增加受控 V2 facade | V2 新接入使用 `KChart`；旧 API 保持 |
| 旧入口 | `package:m_k_chart/flutter_k_chart.dart` 有独立导出列表 | deprecated 的纯转发入口 | 可继续使用；改为正式入口可移除 warning |
| Legacy Widget | `KChartWidget` | 保持 | 无；2.x 不再向其添加 V2 功能 |
| Legacy 数据和计算 | `KLineEntity`、`DataUtil`、`MainState`、`SecondaryState` | 保持 | 无；新偏好可由 `KChartUserConfig` 迁移 |
| 新增主题 | 无 | `KChartTheme`、`ChartColorsThemeAdapter` | 可选采用，不影响旧 Widget |
| 新增用户偏好 | 无 | `KChartUserConfig`、`KChartIndicatorPreference` | 可选采用，schema v1 可读取旧 Demo 的 v0 JSON |
| 新增 V2 图表 | 无 | `KChart`、`KChartController` 与所需数据、指标、覆盖物、绘图契约 | 从唯一入口接入；发布版本号之前不承诺兼容性 |

当前正式入口的 12 个受控导出文件和 91 个顶层公共符号由 `tool/public_api_allowlist.txt` 冻结；数量包含 1.x 兼容 API、主题/用户配置与本轮 V2 语义类型。`test/architecture/public_api_surface_test.dart` 会递归解析正式入口的 `export/show` 和 `part`，拒绝未审查的新增、删除或 `src` 深路径直出；因此 allowlist 是机器可检验的 API 快照。

## 已批准的 V2 类型

- `KChartTheme`：不可变主题、主图/副图独立数值格式、十字光标标签和指标调色板；可使用 `KChartTheme.light()`，或从旧 `ChartColors` 调用 `toKChartTheme(chartStyle: ...)` 过渡。
- `KChartUserConfig`：宿主拥有的 JSON 安全偏好值对象，保存交易对、周期、主图模式、指标实例、面板和时区设置；组件不会自行访问任何存储。
- `KChartIndicatorPreference`：配置中的指标实例引用，只保存 ID、有限数值参数和样式 key，不暴露计算缓存或 Renderer。

## 明确不属于稳定 API 的内容

`package:m_k_chart/v2_example_support.dart`、`lib/src/...`、`lib/renderer/...`、`RenderSnapshot`、`ChartViewport`、内部协调器、Widget State、Painter、Store 和 Example 数据客户端均不属于公开承诺。应用只能依赖正式入口显式列出的语义类型。

## 验证命令

```bash
FLUTTER_BIN=/path/to/flutter tool/check_p9_public_api.sh
```

该门禁统一验证 API allowlist、只导入正式入口的外部宿主编译探针、facade 契约、迁移文档和默认 Example 入口。任何未来的 allowlist 改动都必须同时更新本报告、迁移指南、ADR、CHANGELOG 和相应的语义化版本策略。
