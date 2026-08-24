# Kline V2 指标协议（P3-01）

状态：已冻结基础协议；缓存、增量计算和 legacy 公式迁移分别由 P3-02、P3-03 完成。

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
| `IndicatorRendererDescriptor` | Renderer 中立的绘制描述 | 只包含主图/副图、line/histogram/points、量程语义；不含 Color/Canvas |
| `IndicatorRegistry` | 实例级定义注册和契约校验 | 无全局可变注册表；拒绝重复 ID、未知定义和不符合描述符的结果 |

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

## 5. 后续冻结点

- P3-02：增加缓存键、变更范围和增量更新协议；缓存键至少包含定义、配置、价格源和 `KlineDataVersion`。
- P3-03：将 MA/EMA/BOLL/SAR/VOL/MACD/KDJ/RSI/WR/OBV 迁移为定义，使用 Phase 0 快照对照。
- P3-05：在 Registry/Cache 边界细化单指标失败隔离与多实例压力测试。
- P5：RendererDescriptor 才接入 RenderSnapshot/Layer；此前生产 Painter 保持不变。

## 6. 验证

- 自定义测试指标无需修改核心 enum/switch 即可注册和计算。
- 覆盖配置不可变/值相等、同定义多实例、注册表隔离、未知/重复定义、输出长度/版本/Series 契约和非有限值拒绝。
- 模块依赖守卫确认 `indicator -> model`，没有 Flutter/legacy 反向依赖。
