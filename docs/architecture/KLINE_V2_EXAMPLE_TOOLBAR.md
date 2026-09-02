# K 线 2.0 交易图表 Example

> 任务：P6-03、P6-04、P8-02、P8-03
> 状态：已实现  
> 日期：2026-08-31

## 1. 运行入口

在 `example/` 目录执行 `flutter run`，默认入口为 `V2TradingChartDemo`。它默认请求 OKX 无鉴权 K 线接口，使用 `BTC-USDT`、`1m` 和 180 根数据；用户可以输入任意合法 OKX `instId`、选择周期和数据根数后刷新。网络失败时保留确定性的本地数据，便于离线演示与测试。

legacy `ExamplePage` 和现有网络数据示例仍保留在 `example/lib/main.dart`，但默认启动页现在优先展示 V2 Layer 体验。

## 2. 工具栏行为

| 工具栏 | 可选值 | 效果 |
| --- | --- | --- |
| Instrument & data window | OKX `instId`；100、180、300 根 | 请求 OKX 最新 K 线，校验交易对格式，并按时间升序映射为 `Kline` |
| Period | `1m`、`5m`、`15m`、`1h`、`4h`、`1d` | 先切换本地回退数据，再请求对应 OKX 周期，并更新标题与语义标签 |
| Main chart | Candle（默认）、Hollow、OHLC、Heikin-Ashi、Line、Area | 设置 `ChartMainMode` 并推进 visual version，触发 retained Layer 重录 |
| Main overlays | MA、EMA、BOLL、SAR、VWAP | 将内置指标计算结果装配到 `main` panel，与 K 线叠加显示 |
| Secondary indicators | VOL、MACD、KDJ、RSI、WR、OBV、ATR、CCI、DMI、ROC、Stoch RSI | 可以任意组合；默认 VOL + MACD |
| Secondary layout | 合并为一个面板、分面板排序、72～180 px 最小高度 | 允许副图指标叠加，或按用户顺序拥有独立面板 |
| Panel legends | 当前主图和副图指标 | 在每个面板左上角的透明专用标题区显示当前序列值；计算参数会传入 `IndicatorConfig` |
| Value format | 主图/副图 0～6 位小数、千分位开关 | 两个区域独立更新纵轴、指标图例、最新价与坐标详情；默认均为两位小数和千分位 |
| Trade overlays | 仓位均价、强平价、买入挂单、止盈、止损 | 将五种 SDK 无关的业务示例映射为通用 PriceLine，可整体显示或隐藏 |
| Viewport | 20～300 根可见 K 线 | 将可见根数换算成 viewport 的 item extent |

界面采用高对比浅色主题，标题和操作文案均为中文。指标缩写沿用交易软件的行业通用写法。图表每个面板的左上角均在网格首行内预留透明参数区，显示与线条同色的 `系列名称: 当前值` 图例；该行不参与蜡烛或指标数据绘制，因此文字不会与图形重叠。默认使用当前视图最后一根 K 线，点击或长按后切换为所选 K 线的数值。主图与首个副图之间另预留时间轴区域，展示当前视图的起止时间且不绘制网格。

## 3. 图表手势与坐标详情

图表区域支持左右拖动，按数据槽位更新 `ChartViewport.scrollOffsetItems` 浏览历史 K 线。点击或长按会显示十字光标：竖线和命中 panel 的横线使用虚线，交点使用实心点；命中主图或副图时，右侧显示对应格式化数值的黑底白字标签，所选 K 线时间则显示在主图与首个副图之间的时间带。左侧详情卡展示时间、开高低收、涨跌、涨跌幅、振幅、量和额；拖动浏览时会自动隐藏详情与十字线，避免将旧选择误认为当前视图的数据。十字线、标签和详情卡的颜色、虚线节奏、交点半径与内边距均可通过 `KChartTheme` 配置。

周期和图表类型使用 `ChoiceChip`，指标使用 `FilterChip`；它们带稳定 key（如 `period-5m`、`mode-heikinAshi`、`main-indicator-boll`）和选中状态。图表容器提供包含当前周期和类型的语义标签，便于无障碍工具和自动化测试定位。

## 4. Renderer 装配边界

示例直接装配内部 V2 `RenderSnapshot`、`ChartViewport`、`ChartLayoutModel` 和 `StandardChartRenderPipeline`，主题使用公开 `KChartTheme`。这些 Renderer 合约尚未通过 public API 准入，因此 Example 经由 `package:m_k_chart/v2_example_support.dart` 这个未从正式入口导出的仓库演示桥接库使用它们；不会示范 `package:m_k_chart/src/...` 深路径 import。它是 P6 阶段的真实 Renderer 演示，不是提前稳定的 `KChart` Widget API；正式 Widget/Controller 公共化仍须遵守 API 准入门禁。

`ChartMainMode` 当前属于 Renderer 输入，尚未拥有独立版本切片。因此示例在切换模式时推进 visual version，使 retained Layers 必定重录；后续 public Controller 会将此装配细节隐藏起来。

## 5. 回归门禁

`example/test/okx_market_data_client_test.dart` 验证 OKX 请求参数、官方行结构到 `Kline` 的映射、时间排序，以及异常信封和参数校验。

`test/example/v2_chart_demo_test.dart` 验证：

- 默认 V2 canvas、周期与 Candle 按钮存在；
- 切换至 `5m` 后 ChoiceChip 状态同步；
- Hollow、OHLC、Heikin-Ashi、Line、Area 全部可切换且各自成为唯一选中项；
- 主图增加 BOLL、副图增加 RSI、再切换为单副图叠加后，真实 Renderer 可以完成绘制。
- 主图小数位与副图千分位开关可以分别修改，且状态互不影响。
- 交易叠加示例默认开启，可独立关闭和恢复，五类中文业务标签保持稳定。
- 交易线点击显示独立操作区且不打开 K 线详情；垂直拖动更新本地示例价格，取消按钮隐藏命中对象。
- 点击图表后出现十字光标详情，且包含时间、命中值和 OHLC；横坐标时间标签位于主副图之间的时间带；左右拖动后选择状态清除。

P6-02 Golden 继续冻结所有实际主图模式的像素输出；P6-03/P6-04 覆盖 Example 的装配与交互。
