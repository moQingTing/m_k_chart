# K 线 2.0 Viewport 与边界协议

> 任务：P4-01
> 状态：已实现
> 日期：2026-08-25

## 1. 所有权与坐标单位

`ChartViewport` 是纯 Dart 不可变值对象，由每个 `KChartState/KChartController` 实例独立持有。Viewport 模块不读取 Widget、Painter、GestureRecognizer 或 legacy `ChartPainter.maxScrollX`。

- `width`：可绘制区域的逻辑像素宽度；
- `itemExtent`：当前缩放下一个数据槽占用的逻辑像素；
- `scrollOffsetItems`：可见右边界距最新端的数据槽数，`0` 表示贴近最新数据，正值表示向历史方向移动；
- `itemCount`：当前数据快照的 Kline 数量。

滚动状态使用数据槽而非像素保存，使 Viewport 不依赖设备像素比，也避免仅改变缩放比例就重新解释历史位置。P4-02 在此基础上定义 data/local/时间/价格转换。

## 2. 边界不变量

1. `itemCount >= 0`、`width >= 0`，所有 double 输入必须有限。
2. `0 < minItemExtent <= maxItemExtent`，`itemExtent` 自动约束到该区间。
3. `scrollOffsetItems` 自动约束到 `[0, maxScrollOffsetItems]`。
4. `maxScrollOffsetItems = max(0, itemCount - width / itemExtent)`；数据不足一屏时不允许产生人工滚动空白。
5. 宽度、数据量或缩放变化均创建新对象，并在提交前重新执行全部边界约束。
6. 不声明 mutable static 运行状态；两个图表实例的缩放和滚动互不影响。

## 3. 可见范围

`VisibleIndexRange` 使用半开区间 `[start, end)`：

- 完全或部分进入 Viewport 的数据槽都包含在范围内；
- 范围始终位于 `[0, itemCount]`；
- 零数据或零宽度返回 `[0, 0)`；
- 最新端示例：100 根数据、宽 80、每槽 8，返回 `[90, 100)`；
- 向历史滚动 0.5 槽后返回 `[89, 100)`，两端部分可见项均纳入查询。

该范围只负责裁剪索引，不提供像素中心、价格或时间坐标；这些属于 P4-02。

## 4. Controller 事务

`ChartViewportChanged` 携带完整 Viewport 快照。Controller 批量处理时采用最后一个 Viewport 载荷，并只在最终值确实变化时：

1. 更新 `KChartState.viewport`；
2. 将总 `revision` 增加一次；
3. 将 `StateSlice.viewport` 增加一次；
4. 向监听器通知一次。

相同值保持状态身份且不通知。由此 Viewport 变化可在 Phase 5 被 Renderer 按切片版本精确失效。

## 5. 后续冻结点

- P4-02：数据槽边界/中心、local X、时间和价格转换已冻结，见 `KLINE_V2_COORDINATE_PROTOCOL.md`。
- P4-03：`drawingBounds.width` 已通过 `ChartLayoutModel` 原子接入 Viewport，见 `KLINE_V2_LAYOUT_PROTOCOL.md`。
- P4-04/P4-05：交互状态机把像素输入转换成 Viewport 意图，并实现焦点缩放、惯性与历史锚定。
- P4-06：在 Widget 场景验证双实例、父滚动、横屏、鼠标和触控板策略。

## 6. 验证

- 最新端、最旧端、分数槽滚动和不足一屏范围；
- 缩放上下限、尺寸/数据量变化后的边界重算；
- 非有限值及非法尺寸拒绝；
- 结构相等、相同 Viewport 空事务、批次最后值提交；
- 双 Controller 实例隔离与 mutable static 架构守卫。
