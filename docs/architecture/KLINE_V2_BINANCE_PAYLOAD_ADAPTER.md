# Binance Kline Payload Adapter

> 任务：P2-05  
> 状态：已实现  
> 日期：2026-08-24

## 1. 范围

`BinanceKlinePayloadAdapter` 只负责把宿主已经 JSON 解码的 `List`/`Map` 转换为不可变 `Kline`。核心包不创建 HTTP/WebSocket 连接，不持有 API Key，不处理重试、心跳、订阅或 JSON codec。

```text
宿主 HTTP/WebSocket + jsonDecode
              ↓ List / Map
BinanceKlinePayloadAdapter
              ↓ Kline / BinanceKlineEvent
KlineRealtimeCoordinator
```

## 2. REST 映射

官方 `/api/v3/klines` 返回固定 12 元组：openTime、OHLC、base volume、closeTime、quote volume、trade count、taker buy base/quote volume 和 ignore 字段。

- 单行解析要求调用方明确 `symbol`、`interval` 和 `isClosed`。
- 批量解析通过注入的 `currentTime` 判断 `closeTime < currentTime`，不读取系统时钟，使测试和回放确定。
- REST 不提供首尾 trade ID，模型保持 null。
- 返回列表不可修改。

## 3. WebSocket 映射

支持 `<symbol>@kline_<interval>` raw payload 和 combined stream 的 `{stream, data}` 包装。解析器校验：

- event type 必须是 `kline`；
- 外层 symbol 与 `k.s` 一致；
- interval 属于官方 16 个 Kline 周期；
- 所有时间、价格、成交量、交易 ID 和闭合字段类型正确；
- 构造出的 OHLCV 继续通过核心 Kline 语义校验。

Adapter 不自动修正 high/low 或非有限数；异常交易所数据以 FormatException/ArgumentError 反馈给宿主，由宿主记录并决定重拉。

## 4. 时间与时区

官方 REST/Stream 默认时间单位是毫秒，并支持请求微秒模式。Adapter 通过 `BinanceTimestampUnit` 显式配置：

- milliseconds：直接使用；
- microseconds：向下转换为内部 UTC 毫秒。

`timeZoneOffset` 由宿主根据 REST `timeZone` 参数或 Stream 名称配置。payload 中的 Unix 时间仍按 UTC 解释，offset 只描述周期边界。

## 5. 使用示例

```dart
const payloadAdapter = BinanceKlinePayloadAdapter();

final history = payloadAdapter.parseRestResponse(
  decodedJsonList,
  symbol: 'BTCUSDT',
  interval: KlineInterval.oneMinute,
  currentTime: serverTimeMillis,
);
coordinator.beginNextGeneration(replacement: history);

final event = payloadAdapter.parseWebSocketEvent(decodedJsonMap);
final result = coordinator.apply(
  event.kline,
  generation: coordinator.generation,
);
if (result.requiresReload) {
  // 由宿主重新请求 REST 快照。
}
```

当前类型仍位于 `lib/src`，示例用于内部开发验证；P2-06 门禁完成前不加入正式公共入口。

## 6. 官方依据

- [Binance Spot REST Kline/Candlestick data](https://developers.binance.com/en/docs/catalog/core-trading-spot-trading/api/rest-api/market)
- [Binance Spot WebSocket Kline/Candlestick streams](https://developers.binance.com/en/docs/catalog/core-trading-spot-trading/api/ws-streams/~)
- [Binance Spot REST 时间单位与通用规则](https://developers.binance.com/en/docs/products/spot/rest-api)
