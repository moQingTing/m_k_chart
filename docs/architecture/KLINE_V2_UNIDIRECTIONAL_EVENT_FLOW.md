# K 线 2.0 单向事件流与纯渲染契约

> 任务：P1-04  
> 状态：已实现  
> 日期：2026-08-24

## 1. 唯一数据流向

```text
行情 Store / Interaction / Widget 输入
                ↓ typed KChartEvent
          KChartController
                ↓ reduce once
       immutable KChartState
                ↓ read-only snapshot
        Renderer / Widget listeners
```

Renderer 不存在回指 Controller 的边；绘制结果也不作为修改业务状态的触发器。选择计算、命中测试和手势解释必须在 Interaction/Controller 提交状态之前完成。

## 2. 事件契约

- `KChartEvent` 是 Controller 接受的类型化输入协议。
- 当前提供 data、viewport、selection、history、layout、theme 六类语义事件，与状态切片一一对应。
- 单事件通过 `dispatch`，同一用户输入引发的复合变化通过 `dispatchBatch`。
- 批量事件先合并变化切片，再原子发布一次快照和一次通知。
- Viewport、Layout、crosshair 和 history paging 载荷已由 P4-01/P4-03/P4-04/P4-05 补充；后续载荷仍不得用无类型 `Map` 或动态回调绕过协议。
- `dispatchInteraction` 只负责把 sealed interaction intent 映射到现有类型化事件，不允许 Interaction 直接修改 Controller。
- Controller 销毁后拒绝所有事件。

## 3. Painter/Renderer 纯度

新 `lib/src/render` 只能读取 RenderSnapshot、模型、主题、指标、绘图和视口结果。绘制调用必须满足：相同输入产生相同可见输出，且不会改变业务状态。

P5-01 已实现该协议边界：后续 Widget 装配层必须把 Controller/Interaction 状态投影为 Renderer 自有的选择、历史和版本值；RenderSnapshot 不 import 状态生产者，Layer 只接收 Canvas 与只读快照。指标结果只投影可绘制 Series，不携带递归计算私有状态。

禁止行为：

- import Controller、Data Store、Interaction 或 Widget 模块；
- 创建或写入 StreamController；
- 调用 Controller dispatch/commit 或 `notifyListeners`；
- 调用 Widget `setState`；
- 在 `paint` 中发送选中详情、行情事件或宿主回调。

允许的内部优化包括 Paint、Path、TextPainter 和 Picture 缓存，但缓存失效只能由输入版本决定，不能成为业务状态源。

## 4. 自动门禁

- `module_dependency_test.dart` 阻止 Renderer 反向 import 状态生产者。
- `render_purity_test.dart` 扫描新 Renderer，阻止常见状态写入和异步事件出口。
- Controller 测试断言复合事件只生成一个修订版本和一次通知。

legacy Painter 中已知的 Stream 写入将在 P5-06 迁移时移除；本契约从现在起约束所有新 Renderer 代码，避免新增技术债。
