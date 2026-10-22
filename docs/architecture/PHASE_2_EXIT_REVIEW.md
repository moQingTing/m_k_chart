# K 线 2.0 Phase 2 退出审查

> 审查任务：P2-06  
> 结论：通过  
> 日期：2026-08-24

## 1. 门禁证据

| 门禁 | 证据 | 结论 |
| --- | --- | --- |
| 不可变行情模型 | Kline/Interval/PriceSource/DataVersion 单测与模型契约 | 通过 |
| legacy 兼容 | KLineEntity 双向字段往返与精度拒绝测试 | 通过 |
| 版本化 Store | replace/prepend/append/update、旧快照稳定和只读视图测试 | 通过 |
| 实时幂等 | duplicate 不增加版本、不创建快照 | 通过 |
| 乱序与闭合 | 有限窗口、重拉信号、闭合授权测试 | 通过 |
| 异步隔离 | stale generation 丢弃、失败替换原子性测试 | 通过 |
| Binance 示例 | 官方 REST/WebSocket payload、16 周期和时间单位测试 | 通过 |
| 核心解耦 | 无 HTTP/WebSocket/Binance SDK 依赖 | 通过 |
| legacy Demo 桥接 | 新 Kline → Adapter → DataUtil → KChartWidget 构建测试 | 通过 |
| 历史合并性能 | prepend P95 955 μs、append P95 546 μs | 通过 |
| Store 内存基线 | 10,000 根 RSS 增量约 1.63 MiB | 通过（后续复测综合指标） |

## 2. ARCH-01 行情侧结论

新行情链路已经关闭“行情实体与指标结果耦合”的数据侧风险：

- `Kline` 不继承 legacy mixin，不包含 MA/BOLL/MACD/KDJ/RSI 等字段；
- 所有字段 final，更新产生新 Kline 和新版本快照；
- data 模块只依赖 model，不依赖 indicator、render 或 widget；
- 旧 `KLineEntity` 只能经 adapter 进入/离开新链路；
- Renderer 迁移前仍可通过 adapter 驱动 legacy Demo。

ARCH-01 的指标侧最终关闭仍依赖 Phase 3：指标 Series/Cache 不得回写 Kline。

## 3. 退出限制

Phase 2 可以退出并开始 P3-01，但继续保持：

1. `lib/src` 不加入正式公共入口，直到 Controller 用户操作和新 Widget facade 一并评审。
2. 不提前改写生产 Painter；legacy Demo 继续作为视觉和行为基线。
3. Binance Adapter 保持纯 payload 映射，网络生命周期归宿主。
4. Phase 3 指标缓存键必须包含 KlineDataVersion、配置和价格源。
5. Phase 3/5 重新测量 Kline + 多指标综合内存和实时更新 P95。
