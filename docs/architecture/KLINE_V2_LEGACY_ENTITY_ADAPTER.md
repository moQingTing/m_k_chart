# KLineEntity 兼容 Adapter

> 任务：P2-02  
> 状态：已实现  
> 日期：2026-08-24

## 1. 目的

`KLineEntityAdapter` 是 legacy `KLineEntity` 与不可变 `Kline` 之间的唯一转换边界。只有 `adapter` 模块允许依赖旧实体，新 model/data/indicator/render 模块不得直接引用 legacy 类型。

## 2. 字段映射

| Legacy | Kline | 说明 |
| --- | --- | --- |
| `id` | `openTime` | 默认 legacy 秒转 UTC 毫秒；可显式配置 legacy 已是毫秒 |
| `open/high/low/close` | 同名字段 | 进入新模型时执行有限值和 OHLC 校验 |
| `vol` | `baseVolume` | 基础资产成交量 |
| `amount` | `quoteVolume` | 计价资产成交额 |
| `count` | `tradeCount` | 成交笔数 |

legacy 不包含 symbol、interval、closeTime、isClosed、时区、价格源、主动买入量和交易 ID。symbol/interval/时区/价格源由 Adapter 实例配置；isClosed 必须逐次显式传入；其他字段由调用方按数据源补充。

## 3. 时间策略

- 当前 1.x `DataUtil` 将 `id * 1000` 传给 DateTime，证明默认 legacy 单位是秒。
- 固定周期未传 closeTime 时，使用 `openTime + durationMs - 1`。
- 自然月不能按固定 30 天推导，调用方必须传入 closeTime。
- 反向转为秒时，openTime 必须能被 1000 整除，否则抛出 `StateError`，禁止静默截断。

## 4. 有损字段

反向转为 `KLineEntity` 只能保存双方共有字段。symbol、interval、closeTime、isClosed、timeZoneOffset、priceSource、主动买入量和交易 ID 会丢失；需要保留这些字段的业务必须继续使用新 `Kline`，不能将 legacy 实体作为持久化中间格式。

Adapter 当前仍是 `lib/src` 内部能力。待 P2 Store 与新 Controller 用户 API 冻结后，再按公共 API 准入规则决定导出范围并给 `KLineEntity` 添加代码级 deprecated。
