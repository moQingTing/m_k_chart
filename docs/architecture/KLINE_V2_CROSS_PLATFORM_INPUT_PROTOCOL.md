# K 线 2.0 多实例与跨平台输入协议

> 任务：P4-06
> 状态：已实现
> 日期：2026-08-25

## 1. 输入分层

`ChartGestureRegion` 将输入按设备能力分为三条互不重叠的路径：

```text
touch/stylus/mouse drag → axis-gated scale recognizer → InteractionMachine
mouse hover/wheel       → pointer signal adapter       → intent
trackpad pan/zoom       → native pan-zoom events       → InteractionMachine
```

所有路径只读取当前实例的 Viewport，并向该实例发送不可变 intent。Widget 不读取 legacy Painter 静态边界，不使用 globalPosition 生成导航或 selection 坐标。

## 2. 父滚动与 Gesture Arena

单指输入先经过轴向门控：

- 移动未超过平台 pan slop 时保持 possible；
- 横向距离大于纵向距离后，沿用 Flutter `ScaleGestureRecognizer` 的标准回调，以 `pointerCount == 1` 执行 pan；
- 纵向距离大于等于横向距离时，本 recognizer 以 rejected 结束，让父级 `Scrollable` 的纵向 drag 赢得 Arena；
- 第二指在判轴前到达时跳过单指判轴，使用框架焦点和 span 进入 scale；
- 已开始的单指横向序列增加第二指时，P4-04 状态机从 pan 取消并切换 focus scale。

recognizer 不覆写 Arena 的接受/拒绝回调，不在失败后重新加入或强制接受。标准 LongPress recognizer 继续与同一序列竞争，因此 pan、scale、crosshair 仍保持互斥。

## 3. 鼠标

默认策略：

- 无按键 hover：发送 chart-local crosshair，可复用 P4-05 OHLC 磁吸 builder；
- 离开图表或按下鼠标：隐藏 hover crosshair；
- 纵向滚轮：以指针 local X 为焦点缩放，指数限制在 `exp(-4)..exp(4)` 后再由 Viewport 约束最终级别；
- 横向滚轮：转换为数据槽 pan；
- 鼠标水平拖动：复用轴向门控 pan。

只有实际处理的 PointerScrollEvent 才注册 pointer signal resolver；禁用 wheel zoom 后，纵向滚轮保持给父级/宿主处理。

## 4. 触控板

原生 `PointerPanZoomStart/Update/End` 只由 Listener 策略层消费，触摸 scale recognizer 明确不接管 trackpad：

- start 冻结当前焦点与 Viewport；
- cumulative scale 复用 P4-04 焦点缩放；
- cumulative local pan 改变焦点位置，因此两指平移和 pinch 可在同一序列同时生效；
- end/cancel/dispose 回到 idle；
- `trackpadPanZoom=false` 时整个序列无状态变化。

## 5. 配置与尺寸

`ChartPointerInputPolicy` 是每实例不可变配置，可独立控制 mouse hover、wheel zoom、trackpad pan-zoom 和滚轮缩放灵敏度。配置不使用平台全局变量。

横竖屏和窗口 resize 仍由 P4-03 LayoutModel 提供新的 drawable width；Viewport `copyWith(width:)` 重新计算容量与边界，并尽可能保持数据槽 scrollOffset。输入层始终使用事件的 localPosition，因此嵌套偏移和宽屏不会引入 global X 偏差。

## 6. 自动验证

- 父级 ListView：纵向 drag 只滚动父容器，横向 drag 只移动图表；
- 双图表：触摸或鼠标只改变命中的实例；
- 横屏嵌套：600×260 图表的 hover X/Y 保持 chart-local；
- portrait→landscape：240×360 切换 600×260 后 Viewport 正规化且仍可导航；
- 鼠标：hover/exit、纵向缩放、横向平移；
- trackpad：同一 pan-zoom 序列同时更新 scale/focal 并正确结束；
- 禁用策略：wheel/trackpad 不产生 intent；
- Arena 守卫：新 Widget 路径仍禁止强制接受失败手势。

## 7. 风险结论与后续

- `ARCH-07`：V2 的内部竞争与父滚动让行路径已有自动证据；P4-07 再补完整竞争矩阵和输入延迟门禁后完成 Phase 4 退出审查。
- `ARCH-04`：V2 Controller、Viewport、Interaction、Ticker 和策略均为每实例状态，双图表验证通过；legacy `ChartPainter.maxScrollX` 仍由 P5-06 移除。
- `ARCH-06`：local 坐标、多尺寸、嵌套布局和跨平台指针输入已验证；Renderer 视觉输出仍由 Phase 5 Golden 继续覆盖。

production `KChartWidget`/Painter 本任务未修改；P5/P6 的新 Widget/Renderer 将消费本协议。
