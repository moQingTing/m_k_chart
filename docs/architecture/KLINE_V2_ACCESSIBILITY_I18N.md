# K 线 V2 无障碍、RTL、时区与国际化约定

> 任务：P9-03  
> 状态：已完成  
> 日期：2026-09-03

## 1. Canvas 无障碍边界

K 线主体由 Canvas 绘制，不能依赖每个像素元素自动生成语义节点。`ChartGestureRegion.semantics` 因此接收 Host 已本地化的 `label`、`value` 和 `hint`，将当前周期、图表类型、最新或所选 OHLC 汇总为一个稳定语义节点。

Host 可以同时提供：

- `onTap`：浏览历史时返回最新 K 线；
- `onIncrease` / `onDecrease`：通过系统“调整”动作放大或缩小；
- `increasedValue` / `decreasedValue`：动作后的本地化播报；
- `liveRegion`：选中值变化时是否主动播报。

可调整动作要求对应播报值非空，避免生成 Flutter 不接受的不完整 Semantics 配置。交易叠加按钮仍保留自己的子语义，不被图表摘要屏蔽。

## 2. RTL 策略

工具栏、文字、按钮和详情卡遵循 Flutter 的 `Directionality`。K 线、网格和横坐标保持物理上的时间从左到右；RTL 只改变界面语言方向，不镜像金融时间序列。`ChartSemanticsConfiguration.textDirection` 由 Host 传入，使屏幕阅读器按当前语言方向朗读。

## 3. 时间格式与时区

`RenderSnapshot` 提供两个 Host 格式入口：

- `ChartAxisTimeFormatter`：滚动横坐标标签；
- `ChartCrosshairTimeFormatter`：十字线选中时间。

回调同时收到 UTC epoch 和 `timeZoneOffset`。Host 可使用自己的 locale、历法或格式库；Renderer 不依赖 `intl`，也不读取设备本地时区。默认格式通过“UTC 时间戳 + 显示偏移”计算，保证测试与跨平台结果一致。

显示偏移必须是 UTC-12:00～UTC+14:00 范围内的整分钟值。这样既覆盖 UTC+05:30 等非整点时区，也会拒绝秒和毫秒级偏移。Demo 的时间轴、十字线和详情卡共享同一个偏移来源。

## 4. 定向失效

`RenderSnapshotVersions.locale` 表示语言、日期格式或显示时区变化。标准 Layer 中只有 Axis 与 Crosshair 依赖该切片，因此切换 locale 或时区不会重录 K 线、指标、网格、交易叠加和最新价。

Host 在替换 formatter、locale 或时区后必须推进 `locale` version；若只更新时间倒计时，应推进原有 `clock` version。

## 5. 验证门禁

- 自定义格式回调会收到原始 epoch、周期代码和分钟级偏移；
- 默认格式在 UTC+05:30 下不受运行设备时区影响；
- UTC-12:00 和 UTC+14:00 接受，越界或非整分钟值拒绝；
- locale-only 更新仅重录 Axis 与 Crosshair；
- 阿拉伯语 RTL 语义包含点击和调整动作；
- 中文 Demo 在 RTL、2 倍系统字体和 UTC+05:30 下可构建且无异常。
