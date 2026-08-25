# K 线 2.0 Phase 3 退出审查

> 审查任务：P3-06  
> 结论：通过  
> 日期：2026-08-25

## 1. 门禁证据

| 门禁 | 证据 | 结论 |
| --- | --- | --- |
| 注册式协议 | Definition/Config/Series/Descriptor/Registry 协议与自定义定义测试 | 通过 |
| 版本化缓存 | 配置、版本、价格源、快照身份键及 LRU 测试 | 通过 |
| 增量计算 | append/update 与全量逐 Series 等价，写时复制 520 次展平 | 通过 |
| Legacy 迁移 | MA/EMA/BOLL/SAR/VOL/MACD/KDJ/RSI/WR/OBV 共 24 条冻结序列 | 通过 |
| 新增指标 | VWAP/ATR/CCI/DMI/ROC/Stoch RSI 解析性和边界测试 | 通过 |
| 多实例 | 同定义不同参数/样式实例分别计算与缓存 | 通过 |
| 故障隔离 | 未知、抛错、NaN 实例失败不影响正常结果且不污染缓存 | 通过 |
| 不足/有限值 | 16 指标短数据、平盘、零量输入只输出有限值或 null | 通过 |
| 架构独立 | 无 legacy/Flutter/旧枚举依赖、无 switch 分发、无 Kline 回写 | 通过 |
| 末项性能 | 六实例 10,000 根 P95 2,776 μs | ≤8 ms，通过 |
| 指标内存 | 六实例 10,000 根 RSS 粗测增量约 6.27 MiB | ≤35 MiB，通过 |

## 2. ARCH-01 指标侧结论

Phase 2 已关闭行情模型侧耦合，Phase 3 关闭指标结果侧耦合：

- `Kline` 不包含 MA、MACD、RSI、VWAP 等结果字段，也不混入 legacy entity mixin；
- `VersionedKlineData` 是只读输入，指标公式不修改 Kline 或 Store；
- 可绘制结果只存在于独立 `IndicatorSeries`，递归延续量只存在于 Renderer 不可见的 `IndicatorComputationState`；
- Cache 按版本和配置持有结果，更新发布新 Result，不回写旧快照；
- indicator 模块不依赖 `KLineEntity`、`DataUtil`、ChartStyle、Flutter 或生产 Renderer。

因此 `ARCH-01` 在 v2 新链路上完整关闭。legacy 实体字段只为 1.x 兼容保留，不再进入 v2 计算链路。

## 3. ARCH-08 指标扩展侧结论

- 自定义指标实现 `IndicatorDefinition` 并注册即可计算；
- 10 个迁移指标和 6 个新增指标均使用相同注册机制；
- Registry、Engine 和内置注册入口没有指标 enum/switch 分发；
- instanceId 与 definitionId 分离，支持同定义多实例；
- RendererDescriptor 只声明 Series 语义，不暴露 Canvas/Color。

指标扩展侧 `ARCH-08` 已关闭。公共 API、Layer 插件和迁移文档部分仍属于 Phase 5、6、9，不在本审查中提前宣告完成。

## 4. 性能结论

| 场景 | P95 | 结论 |
| --- | ---: | --- |
| P3-02 单序列缓存末项路径 | 1,202 μs | 通过 |
| 十个 legacy 指标合并末项更新 | 1,942 μs | 通过 |
| 六个新增指标合并末项更新 | 1,689 μs | 通过 |
| 六实例 Engine 批量末项更新 | 2,776 μs | 通过 |

所有 Host Debug P95 均低于 8 ms。Phase 5 仍需在固定 Profile 设备把指标计算与 Renderer UI/Raster、GC、Picture/Text 缓存一起复测。

## 5. 退出限制

Phase 3 可以退出并开始 P4-01，但继续保持：

1. v2 indicator API 暂不加入正式 `m_k_chart.dart`，等待新 Widget/Controller 用户链路统一评审。
2. 生产 Painter 和 legacy Demo 不读取新 Series；视觉接入必须经过 Phase 5 Layer。
3. `RendererDescriptor` 的坐标输入等待 Phase 4 Viewport/Layout 冻结后再接 RenderSnapshot。
4. Phase 5 重新测量 Kline + 六指标 + Renderer 综合内存和 UI/Raster 帧预算。
