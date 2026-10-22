# K 线 2.0 不可变行情模型

> 任务：P2-01  
> 状态：已实现  
> 日期：2026-08-24

## 1. Kline 字段

`Kline` 是不携带任何指标结果的不可变 OHLCV 值对象，包含：

- symbol、interval、openTime、closeTime；
- open、high、low、close；
- baseVolume、quoteVolume、tradeCount；
- takerBuyBaseVolume、takerBuyQuoteVolume；
- firstTradeId、lastTradeId、isClosed；
- timeZoneOffset、priceSource。

`openTime` 和 `closeTime` 始终存储 UTC Unix 毫秒。`openDateTime`/`closeDateTime` 只提供 UTC 读取视图，不改变内部格式。`timeZoneOffset` 用于交易时段/周期边界解释，不改变时间戳本身。

## 2. 运行时校验

Kline 使用 factory 在 debug、profile 和 release 中执行相同校验：

- symbol 非空，时间非负且有序；
- OHLC 为有限非负数，high/low 包含 open 和 close；
- 成交量有限且非负，主动买入量不超过总量；
- 成交笔数和交易 ID 非负，首尾 ID 有序；
- 时区偏移使用整分钟，范围为 Binance 支持的 UTC-12:00～UTC+14:00。

模型不接收 NaN/Infinity，也不通过 `late` 保存 MA、MACD 等派生结果。指标结果将在 P3 由独立 Series/Cache 按数据版本保存。

## 3. 周期模型

`KlineInterval` 区分两种周期：

- fixed：秒、分钟、小时、日、周等固定 Duration；
- calendarMonth：按自然月推进，不能换算成固定 30 天。

内置常用周期覆盖 `1s/1m/3m/5m/15m/30m/1h/2h/4h/6h/8h/12h/1d/3d/1w/1M`，同时允许宿主构造经过校验的自定义固定周期或多月周期。核心模型不依赖 Binance 网络 SDK。

## 4. 价格源

`KlinePriceSource` 支持 trade、mark 和 index price。Dart enum 已内建 `index` 成员，因此源码枚举名使用 `indexPrice`，其稳定传输代码仍是 `index`。

Kline 的实时合并身份为：

```text
symbol + interval + openTime + priceSource
```

OHLC、成交量、closeTime 和闭合状态不参与身份判断，可通过新值替换同一根未闭合 Kline。

## 5. 数据版本

`KlineDataVersion` 是非负、单调递增的快照版本值对象。Store 每次实际数据变更只生成一个新版本；重复或空操作必须保留原版本。版本用于指标缓存键、Renderer 重绘判断和异步结果过期检查，不用于代替 generation token。

## 6. 性能边界

- 模型字段全部为 final，不为状态比较复制或序列化数据。
- Kline 结构相等用于测试和幂等检查；热路径优先比较身份与数据版本。
- Store 对外提供只读列表视图，具体实现由 P2-03 完成。
- 指标字段不进入 Kline，避免每根实体随指标数量膨胀。
