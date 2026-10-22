# Binance 实时 K 线 Demo 验证

> 日期：2026-09-03
> 状态：已通过真机 Profile 验证

## 数据源与增量策略

V2 Demo 与 legacy `ExamplePage` 统一使用 Binance Spot 无鉴权市场数据域
`https://data-api.binance.vision`：

- 首次加载请求 `/api/v3/klines` 的完整窗口，默认 `BTCUSDT`、`1m`、180 根；
- 行情摘要请求 `/api/v3/ticker/24hr`；
- 首次加载后每 2 秒请求最近两根 K 线；相同 `openTime` 替换正在形成的最新柱，新的
  `openTime` 追加为新柱，并按窗口上限移除最旧柱；
- 图表正在浏览历史时，增量合并经 `ChartViewportNavigator` 保持视口，不会把用户强制跳回最新数据。

Binance K 线行按官方顺序映射：开盘时间、OHLC、成交量、收盘时间、成交额、成交笔数、主动买入量。
不会使用 API Key、账户或交易接口。

## 真机结果

测试设备：Samsung SM G986U1（Android 13，Profile 模式）。

- 成功加载 Binance 的 `BTCUSDT / 1m` 实时 24 小时摘要与 180 根 K 线；
- 持续运行时，最新价格标签中的 `1m` 倒计时从 `00:31` 继续递减；
- 同一分钟内，最新柱、成交量和 MACD 数据随轮询更新，验证“替换最新柱”；
- 跨分钟后，右侧出现新的最新成交量柱和 MACD 柱，验证“追加新柱”；合并函数的追加行为也由单元测试覆盖。

## 回归命令

```bash
flutter test test/example/v2_chart_demo_test.dart
(cd example && flutter test test)
flutter analyze --no-fatal-infos --no-fatal-warnings
```

## 官方依据

- [Binance 公共市场数据域](https://github.com/binance/binance-spot-api-docs/blob/master/faqs/market_data_only.md)
- [Binance K 线流字段定义](https://github.com/binance/binance-spot-api-docs/blob/master/web-socket-streams.md)
