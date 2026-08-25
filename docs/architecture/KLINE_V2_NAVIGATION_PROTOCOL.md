# K 线 2.0 导航、磁吸与历史分页协议

> 任务：P4-05
> 状态：已实现
> 日期：2026-08-25

## 1. 分层与状态归属

P4-05 在 P4-04 手势 winner 之后处理导航，不改变 Gesture Arena 竞争规则：

```text
pan end velocity → ChartNavigationMachine → ChartViewportIntent
Controller command → ChartViewportNavigator → ChartViewportIntent
local pointer + stable data → ChartOhlcSnapper → ChartCrosshairIntent
oldest threshold → ChartHistoryPagingState → ChartHistoryPagingIntent
```

- 惯性运行状态只属于每个图表实例的 `ChartNavigationMachine`，不进入 Renderer，也不使用 static；
- Viewport 仍是滚动、定位和 prepend 锚定的唯一持久载荷；
- OHLC 磁吸结果进入 selection 切片；
- 历史加载生命周期进入独立 history 切片，不伪装成行情 data 变化。

## 2. 惯性

`ChartGestureRegion` 将 pan end 的 local X 速度交给纯 Dart 导航机，并使用实例 Ticker 提供帧间 `Duration`。导航机使用恒定减速度：

```text
velocityItems = velocityLocalX / itemExtent
decelerationItems = decelerationLocalX / itemExtent
distance = sign(v) × (|v| × dt - 0.5 × deceleration × dt²)
```

帧间隔超过剩余停止时间时只积分到停止点。到达最新端、最旧端或速度归零时立即结束；弱速度、边界外向速度和无可滚动范围不会启动惯性。新手势开始、Widget 销毁或显式取消都会停止当前实例的惯性。

## 3. 确定性导航

`ChartViewportNavigator` 提供三项纯操作：

- `toLatest`：将 `scrollOffsetItems` 归零；
- `locateTime`：通过 `ChartXTransform` 对实际 openTime 二分/插值，并将目标放在 `[0, 1]` alignment 指定的位置，默认居中；
- `preserveAfterPrepend`：增加 itemCount 并保持 scrollOffsetItems 不变，使原 K 线在 prepend 后维持相同 local X。

时间定位遵循数据首尾和 Viewport 滚动边界，不假定固定周期，也不在 Controller 或 Widget 中复制坐标公式。

## 4. OHLC 磁吸

`ChartOhlcSnapper` 先用 X Transform 选择 local X 所在的数据槽，再将竖线固定到该 K 线中心；横向价格线从 open/high/low/close 的 local Y 中选择与输入 Y 最近者。结果包含：

- data index；
- `open/high/low/close` 字段；
- 精确 price；
- 磁吸后的 local X/Y。

`ChartCrosshairIntent.snapped` 将上述元数据完整写入不可变 selection 状态，宿主和后续 Overlay 无需通过 Painter 反查选中数据。

## 5. 历史分页

`ChartHistoryPagingState` 只有四种状态：`idle`、`loading`、`noMore`、`failure`。

- Viewport 距最旧端不超过阈值且处于 idle/failure 时，进入 loading 并递增 requestSerial；
- loading 期间重复触发保持同一状态，防止重复请求；
- 成功且仍有历史回到 idle；无更多数据进入终态 noMore；
- 失败进入 failure 并增加 failureCount，再次到达阈值可显式重试；
- symbol/interval/generation 切换时由宿主 reset。

数据 prepend 与 paging 完成可通过 Controller batch 原子提交 `data + viewport + history`；视觉锚点使用第 3 节规则保持稳定。

## 6. 验证与后续边界

- 惯性：减速积分、弱速度、双端边界、取消和非法参数；
- 导航：最新端、不规则时间定位、alignment 和 prepend 锚定；
- 磁吸：K 线中心、最近 OHLC、selection 元数据；
- 分页：阈值、重复抑制、成功、noMore、失败、retry、reset；
- Widget：释放速度在手势结束后继续产生有界 Viewport intent；
- Controller：history 版本与 data/viewport/selection 相互隔离。

P4-06 继续覆盖双实例、父滚动、横屏、鼠标和触控板策略；P4-07 负责完整输入延迟与竞争矩阵。production `KChartWidget`/Painter 仍保持 legacy 基线，待 P5/P6 新渲染和体验层消费本协议。
