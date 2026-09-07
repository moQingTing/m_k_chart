# ADR-001：V2 整改期间的公共 API 过渡边界

> 状态：已接受
>
> 日期：2026-09-03
>
> 决策：P9-04

## 背景

V2 已实现不可变数据、指标、视口、分层绘制、手势、主题、交易 Overlay 和深度图能力。与此同时，`KChartWidget` 仍是稳定的 1.x facade，而新的 Renderer/Controller 装配仍包含内部生命周期和缓存细节。若此时直接导出内部类型，后续修复会成为无法撤回的 API 兼容负担。

## 决策

1. `package:m_k_chart/m_k_chart.dart` 是唯一正式入口；`flutter_k_chart.dart` 只保留 deprecated 转发。
2. 2.x 保留 1.x Widget、实体、枚举和工具的源码兼容性，不删除、不重命名，也不向 legacy facade 注入新的 V2 行为。
3. `KChartTheme`、`ChartColorsThemeAdapter`、`KChartUserConfig` 和 `KChartIndicatorPreference` 是当前唯一批准的 V2 公共增量。
4. `lib/src`、Renderer、Painter、Store、内部 Controller 与 `v2_example_support.dart` 保持私有；完整 Example 可以使用桥接库，但用户代码不得依赖它。
5. 公开 V2 Widget/Controller 的准入必须同时包含 API 草案定稿、生命周期/错误处理/可访问性契约、迁移示例、allowlist diff、语义化版本决策和真实接入反馈。

## 后果

正面结果是现有 1.x 应用可以无风险升级，并可逐步采用主题与偏好协议；内部渲染链路可继续演进。代价是 Example 不能被当作当前稳定 Widget API 的复制模板，且需要在正式 Widget 准入时发布一次明确的主版本迁移指南。

## 验证与关联资料

- `tool/public_api_allowlist.txt` 与 `test/architecture/public_api_surface_test.dart` 冻结并验证公开面；
- [P9 公共 API 差异](../P9_PUBLIC_API_DIFF.md) 记录相对 1.0.4 的变化；
- [迁移指南](../MIGRATING_TO_V2.md) 提供可执行的兼容升级路径；
- [公共 API 策略](KLINE_V2_PUBLIC_API_POLICY.md) 仍定义日常准入规则。
