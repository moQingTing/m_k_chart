# K 线 2.0 交互状态机与 Gesture Arena 协议

> 任务：P4-04
> 状态：已实现
> 日期：2026-08-25

## 1. 分层职责

交互链路分为两层：

```text
Flutter Gesture Arena / chart-local callbacks
                    ↓
          ChartGestureRegion adapter
                    ↓
       ChartInteractionMachine (pure Dart)
                    ↓ immutable intents
             KChartController
                    ↓
       Viewport / Selection state slices
```

- `ChartGestureRegion` 只把 Flutter 回调转换成状态机输入，不保存业务状态；
- `ChartInteractionMachine` 是每图表实例独立的纯 Dart 状态机，只依赖 Viewport；
- Controller 将 `ChartViewportIntent` 和 `ChartCrosshairIntent` 转换成已有的类型化事件；
- Renderer 后续只读取 `KChartState`，交互和 Painter 之间不存在 Stream 或反向状态写入。

## 2. Gesture Arena 规则

新适配器使用 Flutter 标准 recognizer，不覆写 `rejectGesture`，也不调用 `acceptGesture` 强制接管失败手势。

一个标准 Scale recognizer 负责同一连续序列：

- `pointerCount == 1`：解释为水平 pan；
- `pointerCount >= 2`：结束 pan 后进入 focus scale；
- 手指数从 2 降为 1时，不在同一序列重新开启 pan，直到本次 scale end；
- 标准 LongPress recognizer 与 Scale recognizer 在 Arena 中竞争；静止长按胜出后独占 crosshair，移动/缩放不会同时产生十字线意图。

P4-06 已通过轴向门控 recognizer 验证父滚动让行，并补充鼠标与触控板策略，见 `KLINE_V2_CROSS_PLATFORM_INPUT_PROTOCOL.md`。本协议继续冻结图表内部单指/双指/长按互斥规则。

## 3. 状态机

`ChartInteractionMode` 只有四种互斥状态：

| 状态 | 接受更新 | 结束/取消结果 |
| --- | --- | --- |
| `idle` | begin pan/scale/crosshair | 无 |
| `panning` | local X delta | 回到 idle |
| `scaling` | cumulative scale + local focal X | 回到 idle |
| `crosshair` | local X/Y | 发送 hidden 后回到 idle |

冲突 begin 返回 false/null，不抢占当前 winner。错误模式的 update/end 是 no-op；cancel/reject 只结束当前状态，绝不自动启动另一状态。所有连续坐标和 scale 必须有限，scale 必须大于零。

## 4. Pan 与焦点缩放

Pan 使用 P4-01 的数据槽滚动单位：

```text
deltaItems = deltaLocalX / itemExtent
nextScroll = clamp(currentScroll + deltaItems)
```

手指向右移动产生正 scroll，显示更旧数据；所有边界仍由 `ChartViewport` 统一约束。

Scale 在 begin 时冻结焦点下的数据位置：

```text
anchor = visibleLeft + focalLocalX / startItemExtent
nextExtent = clamp(startItemExtent * cumulativeScale)
nextLeft = anchor - currentFocalLocalX / nextExtent
nextScroll = itemCount - (nextLeft + width / nextExtent)
```

因此缩放与焦点平移可同时发生；未碰到 Viewport 首尾边界时，焦点下的数据位置保持不变。

## 5. Crosshair 与 Controller

长按只使用 `localPosition`，不接受 legacy `globalPosition.dx`。状态机产生：

- visible `ChartCrosshairState(localX, localY)`：显示或移动；
- hidden state：结束或取消；隐藏状态的零坐标不参与绘制判断。

Controller 的 `dispatchInteraction` 将 Viewport 与 crosshair 意图分别提交到 viewport/selection 切片。相同载荷保持空事务；一次意图最多产生一次 revision 和一次通知。

## 6. 自动门禁与验证

- 纯状态机：pan 边界、焦点锚定、移动焦点、缩放上下限、冲突 begin、取消和非法输入；
- Widget Arena：单指只 pan、双指只 scale、静止长按只 crosshair；
- Controller：意图进入正确切片，crosshair 不由 Painter/Stream 产生；
- 架构扫描：`lib/src/interaction` 不依赖 Flutter/Widget/Controller；
- Arena 扫描：新 interaction/widget 链路禁止 `rejectGesture(` 和 `acceptGesture(`；
- 实例隔离扫描：interaction 不声明 mutable static 状态。

## 7. 后续边界

- P4-05：已使用 pan end 速度实现惯性，并补充磁吸、回到最新、时间定位与分页锚定，见 `KLINE_V2_NAVIGATION_PROTOCOL.md`；
- P4-06：已验证父滚动、横屏、鼠标、触控板与双实例 Widget 场景；
- P4-07：输入延迟和完整竞争矩阵；
- P5/P6：新 Renderer/Widget 正式消费该适配器；当前 production `KChartWidget` 仍保留 legacy 行为作为迁移基线。
