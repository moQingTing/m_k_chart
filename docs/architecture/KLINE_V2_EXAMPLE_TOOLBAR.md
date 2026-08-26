# K 线 2.0 周期与图表类型 Example

> 任务：P6-03  
> 状态：已实现  
> 日期：2026-08-26

## 1. 运行入口

在 `example/` 目录执行 `flutter run`，默认入口为 `V2TradingChartDemo`。示例不请求网络：每次切换周期时，按周期 code 生成固定的 96 根 `Kline`，因此演示、截图与 widget 测试均可离线复现。

legacy `ExamplePage` 和现有网络数据示例仍保留在 `example/lib/main.dart`，但默认启动页现在优先展示 V2 Layer 体验。

## 2. 工具栏行为

| 工具栏 | 可选值 | 效果 |
| --- | --- | --- |
| Period | `1m`、`5m`、`15m`、`1h`、`4h`、`1d` | 生成对应 `KlineInterval`、推进 data version，并更新标题与语义标签 |
| Chart type | Candle、Hollow、OHLC、Heikin-Ashi、Line、Area | 设置 `ChartMainMode` 并推进 visual version，触发 retained Layer 重录 |

每个按钮是 `ChoiceChip`，带稳定 key（如 `period-5m`、`mode-heikinAshi`）和选中状态；图表容器提供包含当前周期和类型的语义标签，便于无障碍工具和自动化测试定位。

## 3. Renderer 装配边界

示例直接装配内部 V2 `RenderSnapshot`、`ChartViewport`、`ChartLayoutModel` 和 `StandardChartRenderPipeline`，主题使用公开 `KChartTheme`。这些 Renderer 合约尚未通过 public API 准入，因此 Example 经由 `package:m_k_chart/v2_example_support.dart` 这个未从正式入口导出的仓库演示桥接库使用它们；不会示范 `package:m_k_chart/src/...` 深路径 import。它是 P6 阶段的真实 Renderer 演示，不是提前稳定的 `KChart` Widget API；正式 Widget/Controller 公共化仍须遵守 API 准入门禁。

`ChartMainMode` 当前属于 Renderer 输入，尚未拥有独立版本切片。因此示例在切换模式时推进 visual version，使 retained Layers 必定重录；后续 public Controller 会将此装配细节隐藏起来。

## 4. 回归门禁

`test/example/v2_chart_demo_test.dart` 验证：

- 默认 V2 canvas、周期与 Candle 按钮存在；
- 切换至 `5m` 后 ChoiceChip 和图表语义状态同步；
- Hollow、OHLC、Heikin-Ashi、Line、Area 全部可切换且各自成为唯一选中项。

P6-02 Golden 继续冻结所有实际主图模式的像素输出；P6-03 仅验证 Example 的装配与交互。
