# K 线 2.0 实时合并策略

> 任务：P2-04  
> 状态：已实现  
> 日期：2026-08-24

## 1. 事件结果

`KlineRealtimeCoordinator` 将每个事件归类为明确结果：

| 结果 | 数据变化 | 处理建议 |
| --- | --- | --- |
| `appended` | 是 | 新周期 Kline |
| `updated` | 是 | 更新同一未闭合 Kline，或授权校正 |
| `insertedOutOfOrder` | 是 | 在有限窗口内补齐缺口 |
| `ignoredDuplicate` | 否 | 幂等重复，无需通知 |
| `ignoredStaleGeneration` | 否 | 丢弃旧交易对/周期异步结果 |
| `rejectedClosedCorrection` | 否 | 未授权修改已闭合 Kline |
| `rejectedDifferentSeries` | 否 | 当前 generation 收到其他序列 |
| `rejectedOutsideWindow` | 否 | 乱序过旧，`requiresReload=true` |

所有忽略或拒绝结果保持原 KlineSnapshot 身份和数据版本。

## 2. 幂等与闭合规则

- 相同身份且结构完全相同的事件视为 duplicate。
- 未闭合 Kline 可被同身份新值更新，并可转为闭合。
- 已闭合 Kline 默认不可修改；宿主处理交易所校正事件时必须逐次传 `allowClosedCorrection=true`。
- 不允许通过普通事件将闭合数据静默改写，避免历史指标和交易标记漂移。

## 3. 有限乱序窗口

Coordinator 使用 openTime 二分定位。缺失 Kline 若插入点之后的已有 Kline 数量不超过 `maxOutOfOrderCandles`，允许插入；超过窗口则不修改数据并要求宿主重新拉取快照。

窗口按 Kline 数量而非墙钟时间计算，适用于固定周期和自然月。默认窗口为 2，可配置为 0 以禁止所有历史插入。

## 4. Generation token

`KlineGeneration` 与数据版本职责不同：

- data version 标识同一序列的数据快照变化；
- generation 标识一次交易对/周期/价格源订阅生命周期。

切换订阅时调用 `beginNextGeneration`，先验证并提交替换快照，再原子推进 token。旧 REST、WebSocket 或 isolate 结果携带旧 token 时，在检查 payload 前直接丢弃。若替换数据校验失败，token 和原快照均保持不变。

## 5. 性能

- duplicate/stale/rejected 路径不分配新数据快照。
- 同身份更新使用 Store 的 O(log n) 二分定位。
- 窗口内插入预分配一次最终列表。
- 超窗事件只返回 reload 信号，不执行全量排序。

批量历史数据仍先在 adapter/策略层归一化，再一次性提交 Store；不得逐根 prepend 造成 O(n²) 复制。
