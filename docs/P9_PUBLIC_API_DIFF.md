# K 线 V2 P9-04 公共 API 差异

> 任务：P9-04
>
> 基线：1.0.4（提交 `6225ffb792ae49da407f891d17c4d1b44ac298c8`）
>
> 审计日期：2026-09-03

## 结论

本次 2.0 整改没有删除 1.0.4 的正式导出，也没有把 `lib/src`、legacy Renderer 或 V2 演示桥接层暴露为稳定 API。相对 1.0.4，唯一经批准新增的正式类型是不可变主题与可持久化的用户偏好；旧 Widget、实体、指标枚举和计算工具继续保持源码兼容。

## 正式入口差异

| 分类 | 1.0.4 | 当前状态 | 迁移影响 |
| --- | --- | --- | --- |
| 正式入口 | `package:m_k_chart/m_k_chart.dart` | 保持 | 无 |
| 旧入口 | `package:m_k_chart/flutter_k_chart.dart` 有独立导出列表 | deprecated 的纯转发入口 | 可继续使用；改为正式入口可移除 warning |
| Legacy Widget | `KChartWidget` | 保持 | 无；2.x 不再向其添加 V2 功能 |
| Legacy 数据和计算 | `KLineEntity`、`DataUtil`、`MainState`、`SecondaryState` | 保持 | 无；新偏好可由 `KChartUserConfig` 迁移 |
| 新增主题 | 无 | `KChartTheme`、`ChartColorsThemeAdapter` | 可选采用，不影响旧 Widget |
| 新增用户偏好 | 无 | `KChartUserConfig`、`KChartIndicatorPreference` | 可选采用，schema v1 可读取旧 Demo 的 v0 JSON |

当前正式入口的 11 个导出文件和 26 个顶层公共符号由 `tool/public_api_allowlist.txt` 冻结。`test/architecture/public_api_surface_test.dart` 会拒绝未审查的新增、删除或深路径导出；因此该文件既是机器可检验的 API 快照，也是此差异报告的唯一真值来源。

## 已批准的 V2 类型

- `KChartTheme`：不可变主题、主图/副图独立数值格式、十字光标标签和指标调色板；可使用 `KChartTheme.light()`，或从旧 `ChartColors` 调用 `toKChartTheme(chartStyle: ...)` 过渡。
- `KChartUserConfig`：宿主拥有的 JSON 安全偏好值对象，保存交易对、周期、主图模式、指标实例、面板和时区设置；组件不会自行访问任何存储。
- `KChartIndicatorPreference`：配置中的指标实例引用，只保存 ID、有限数值参数和样式 key，不暴露计算缓存或 Renderer。

## 明确不属于稳定 API 的内容

`package:m_k_chart/v2_example_support.dart`、`lib/src/...`、`lib/renderer/...`、`RenderSnapshot`、`ChartViewport`、内部 Controller、Painter、Store 和 Example 数据客户端均不属于发布承诺。它们可以随 V2 Widget/Controller 正式准入而调整；应用不得依赖这些路径。

## 验证命令

```bash
FLUTTER_BIN=/path/to/flutter tool/check_p9_public_api.sh
```

该门禁验证 API allowlist、迁移文档和默认 Example 入口。任何未来的 allowlist 改动都必须同时更新本报告、迁移指南、ADR、CHANGELOG 和相应的语义化版本策略。
