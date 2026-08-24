# K 线 2.0 版本化 Store

> 任务：P2-03  
> 状态：已实现  
> 日期：2026-08-24

## 1. 快照模型

`KlineStore` 每次有效事务发布一个新的 `KlineSnapshot`。快照包含：

- 不可修改的 `List<Kline>` 视图；
- 单调递增的 `KlineDataVersion`；
- length、firstOrNull、lastOrNull 和索引读取。

Store 不原地修改已发布列表。后续 append/update 生成新列表，因此旧快照在指标异步计算、Renderer 绘制或测试持有期间保持稳定。

## 2. 基础事务

| 操作 | P2-03 行为 |
| --- | --- |
| `replace` | 替换完整有序序列；相等数据不生成新版本 |
| `prepend` | 批量加入当前首根之前的数据 |
| `append` | 批量加入当前末根之后的数据 |
| `update` | 通过 openTime 二分查找并替换同一身份 Kline |

空批次、相等 replace 和相等 update 返回原快照实例，不增加版本。每个实际变化事务只增加一次版本。

## 3. P2-03 输入前置条件

- 一个 Store 只保存同一 `symbol + interval + priceSource` 序列。
- 输入必须按 openTime 严格递增且无重复。
- prepend/append 不得与现有范围重叠。
- update 必须命中已有 openTime。

本阶段的 Store 是确定性的底层提交器，不静默排序、去重或校正。P2-04 将在其上增加重复幂等、有限乱序窗口、已闭合校正规则和 generation token；这些策略完成前，调用方必须满足上述前置条件。

## 4. 性能策略

- 读路径直接复用快照的只读视图，不在 build/paint 每帧复制列表。
- prepend/append 按最终长度一次性预分配结果列表。
- update 使用 O(log n) 二分定位，仅复制一次列表，不线性搜索身份。
- 空操作零分配快照、零版本变化，供 Controller 避免无效通知。
- replace 的结构相等检查为 O(n)，用于快照/分页级操作；实时 tick 使用 update，不走全量 replace。

10,000 根批量合并的实测耗时和内存门禁在 P2-06 执行。
