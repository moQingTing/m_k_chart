# V2 交易图表示例接入说明

[`v2_chart_demo.dart`](lib/v2_chart_demo.dart) 是一份完整的 SDK 组装参考：它默认使用 Binance 公共行情，但图表本身不依赖 Binance。示例行情入口是 [`V2DemoMarketDataSource`](lib/market/v2_demo_market_data_source.dart)，宿主可以直接实现它并通过 `marketDataSource` 注入，无需继承币安客户端。旧 `marketDataClient` 参数保留兼容；二者不要同时传入。

行情源需要返回对应交易对、周期的 K 线窗口；首次请求完整窗口，后续轮询请求最近两根。可选的 24 小时摘要返回 `null` 时会退回 K 线窗口估算。由宿主持有稳定的源实例；更换实例会被视为切换数据源，旧请求结果失效并重新加载。默认币安 HTTP 源支持单请求取消；自定义源可选实现 `V2DemoCancelableMarketDataSource`，在暂停、切源、后台或销毁时收到取消调用。没有取消能力的源仍可用，但旧响应只会被忽略，底层操作不会自动停止。这个契约只属于示例，正式 SDK 的数据输入仍通过 Controller，WebSocket 订阅与取消由宿主管理。

接入自己的应用时，建议按下面的职责替换，而不是复制整个页面：

1. **行情仓库**：把 REST 历史数据与 WebSocket 最新 K 线转换为 `Kline`，并提供不可变的 `VersionedKlineData`。
2. **数据窗口更新**：使用示例中的 `_applyDataWindow` 思路统一处理替换最新 K 线和新增下一根 K 线；更新历史数据时保留 `ChartViewport`，用户浏览历史不会被拉回最新价。
3. **指标引擎**：启动时注册定义，随后为每个启用指标创建 `IndicatorConfig`，交给 `IndicatorEngine.resolveAll`。配置参数变化时只需创建带新 `parameters` 的配置，缓存会安全地重新计算。
4. **渲染快照**：由 `ChartLayoutModel`、`ChartViewport`、主题、指标投影和可选交易叠加共同构成 `RenderSnapshot`，再调用 `StandardChartRenderPipeline` 绘制。
5. **交互**：用 `ChartGestureRegion` 路由点击、拖动与缩放；点击结果写入选择状态后重建快照，而不要在画布回调中直接改变业务数据。

## 示例中的可替换点

| 示例代码 | 生产环境替换方式 |
| --- | --- |
| `V2DemoMarketDataSource` / `BinanceMarketDataClient` | 你的行情仓库或缓存适配器；WebSocket 推送由宿主协调 |
| `createV2DemoSeedData` | 本地缓存、首屏骨架或空状态 |
| `_indicators` | 产品支持的指标目录与默认参数 |
| `_theme` | 应用设计系统的 `KChartTheme` |
| `_tradeOverlays` | 仓位、订单、止盈止损等真实交易数据 |

Demo 将设置收纳到独立底部页：行情与周期、指标与参数、图表显示、模拟实时数据。主页面只保留图表和快捷入口，移动端接入时可直接沿用这一结构，或把每个设置页替换为自己的路由、侧栏或状态管理界面。
