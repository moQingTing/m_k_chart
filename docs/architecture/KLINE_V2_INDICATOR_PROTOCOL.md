# Kline V2 指标协议（P3-01）

状态：基础协议、缓存/增量扩展及 P3-03 legacy 公式迁移已冻结。

## 1. 目标与边界

指标引擎采用“定义注册 + 实例配置 + 版本化输入 + 独立输出 + 声明式渲染描述”模型。指标模块只依赖 `model`，不依赖 Store、Widget、主题、Flutter Canvas 或 legacy `KLineEntity`。

本任务不修改生产 Painter，不迁移现有公式，也不从正式包入口公开新 API。

## 2. 核心协议

| 类型 | 职责 | 关键约束 |
| --- | --- | --- |
| `VersionedKlineData` | 指标的只读行情输入 | 数据在视图生命周期内稳定；携带 `KlineDataVersion`；避免 10,000 根读路径复制 |
| `IndicatorDefinition` | 一个可注册的指标算法 | 唯一字符串 ID；声明 RendererDescriptor；计算不回写 Kline |
| `IndicatorConfig` | 一个指标实例的不可变配置 | 实例 ID 与定义 ID 分离；参数必须有限；样式只存语义 key |
| `IndicatorSeries` | 单条输出序列 | `null` 表示数据不足；禁止 NaN/Infinity；长度与输入严格一致 |
| `IndicatorResult` | 一次完整计算结果 | 绑定实例、定义、数据版本、长度与多条 Series |
| `IndicatorComputationState` | 递归公式的不可变延续状态 | Renderer 不可见；长度与结果一致；只允许有限值或 null |
| `IndicatorRendererDescriptor` | Renderer 中立的绘制描述 | 只包含主图/副图、line/histogram/points、量程语义；不含 Color/Canvas |
| `IndicatorRegistry` | 实例级定义注册和契约校验 | 无全局可变注册表；拒绝重复 ID、未知定义和不符合描述符的结果 |
| `IndicatorEngine` | 实例级批量计算与故障隔离 | 组合 Registry/Cache；按 instanceId 返回不可变结果和 failure |

## 3. 数据流

```text
KlineStore.snapshot (VersionedKlineData)
             + IndicatorConfig
             ↓
       IndicatorRegistry
             ↓ resolve
      IndicatorDefinition.calculate
             ↓ validate
        IndicatorResult
             + RendererDescriptor
             ↓
      后续 RenderSnapshot / Layer
```

`KlineSnapshot` 直接实现 `VersionedKlineData`。指标读取 Store 已有的不可变列表，不创建第二份 Kline 集合。计算结果单独存储，不向 `Kline` 或 legacy 实体写入 `late` 指标字段。

## 4. 扩展和隔离规则

1. 新指标通过实现 `IndicatorDefinition` 并注册完成，核心模块不增加 enum/switch。
2. 同一定义可以通过不同 `instanceId`、参数和样式 key 创建多个实例。
3. 注册表由 Chart/Controller 实例持有，两个图表之间不共享可变定义集合。
4. Renderer 只能读取描述符和 Series；颜色、线宽等由后续主题层解析语义 style key。
5. Registry 在算法返回后校验身份、版本、长度和 Series ID，阻止错误结果进入渲染链路。

## 5. P3-02 缓存与增量扩展

1. `IndicatorCacheKey` 包含完整 `IndicatorConfig`（定义、实例、参数和样式语义）、`KlineDataVersion`、`KlinePriceSource` 以及列表身份。列表身份用于隔离拥有相同版本计数的独立 Store。
2. `IndicatorCache` 由单个 Chart/Controller 实例持有，默认最多保留 32 项；精确命中更新 LRU 次序，超限淘汰最旧项，可显式清空。
3. `IndicatorDataChange` 通过不可变快照的公共前缀/后缀识别 `unchanged/append/prepend/update/replace`，并提供新旧半开变更区间。算法按自身 lookback 扩展重算起点。
4. 支持增量的算法实现 `IncrementalIndicatorDefinition`，逐类声明可处理的变更；未声明的变更由 Cache 回退 `calculate` 全量路径。
5. 增量结果与全量结果使用同一 Registry 契约校验。身份、版本、长度或 Series 不匹配立即失败，不使用可能错误的旧结果静默恢复。
6. 相同内容但新版本的快照可复用不可变 Series 并重新绑定数据版本；精确相同快照直接返回同一个 Result。

P3-03 为递归指标补充 `IndicatorComputationState`。MACD 的 EMA12/26、RSI 的平滑分子/分母、SAR 的趋势/AF/EP 和 KDJ 的内部 K/D 保存在该状态中，不污染可绘制 Series。增量输出使用写时复制值列表：未变化前缀共享，稀疏覆盖超过 512 项时自动物化，限制查找层级和长期持有成本。

P3-04 增加六个内置定义并冻结默认口径：VWAP 累计典型价成交量加权、ATR Wilder 14、CCI 20/0.015、DMI 14+14、ROC 12、Stoch RSI 14/14/3/3。`registerBuiltInIndicatorDefinitions` 一次注册 10 个 legacy 和 6 个新增定义，仍不使用核心 enum/switch。

后续扩展新增 AVL 与 SUPER：AVL 使用 K 线提供的累计成交额/成交量，SUPER 使用 Wilder ATR(10) 与乘数 3 的追踪上下轨。二者同样通过注册接入，支持 append 与最新柱 update，不给核心模块添加 enum/switch。

P3-05 增加实例级 `IndicatorEngine.resolveAll`。一个批次要求 instanceId 唯一；每个配置独立经过 Cache/Registry，异常被记录为 `IndicatorCalculationFailure`，其他实例继续。失败结果不写缓存，下一批可重试。Engine 不使用全局注册表或缓存，因此双图表之间不会传播定义、结果或 failure。

缓存协议性能见 `PERFORMANCE_P3_INDICATOR_CACHE_BASELINE.md`，十类迁移指标性能见 `PERFORMANCE_P3_LEGACY_INDICATORS_BASELINE.md`，六类新增指标性能见 `PERFORMANCE_P3_ADDITIONAL_INDICATORS_BASELINE.md`，多实例与内存见 `PERFORMANCE_P3_INDICATOR_ENGINE_BASELINE.md`。

## 6. P5-05 绘制语义

P5-05 将 legacy 指标视觉所需的颜色和柱形规则写入中立 Descriptor，而不是把 definition ID 判断带回 Renderer：Volume 使用 candle direction，MACD 使用 value sign 与 value trend 空心规则，SAR 使用相对 close 的 price position；普通 Series 保持稳定 palette 色。该实现只影响内部 V2 Layer，生产 Painter 与正式入口仍未接线。

## 7. 后续冻结点

- P3-06：指标独立性守卫已冻结，禁止 legacy 实体、旧枚举/switch 分发和输入回写。
- P5-02/P5-05：RendererDescriptor 已由主图/副图 Layer 统一消费 line/histogram/points 及中立颜色/柱形语义；生产 Painter 仍保持不变。

## 8. 验证

- 自定义测试指标无需修改核心 enum/switch 即可注册和计算。
- 覆盖配置不可变/值相等、同定义多实例、注册表隔离、未知/重复定义、输出长度/版本/Series 契约和非有限值拒绝。
- 模块依赖守卫确认 `indicator -> model`，没有 Flutter/legacy 反向依赖。
