# K 线 2.0 交易叠加协议

> 任务：P8-01
>
> 状态：已实现
>
> 日期：2026-09-02

## 1. 模型边界

核心模型只表达图表语义，不依赖交易所 SDK、账户状态或下单接口：

- `ChartPriceLine`：价格、买卖方向、可选标题和显隐状态；
- `ChartValueMarker`：价格、文本和买卖方向；
- `ChartEventOverlay`：毫秒时间、价格、可选标题和买卖方向；
- `ChartOverlaySide`：`buy`、`sell`、`neutral` 三种视觉语义。

所有 ID 必须非空，价格必须为有限值，事件时间不得为负。`RenderSnapshot` 对输入集合做不可变复制，并要求三类对象共享一个唯一 ID 命名空间，避免后续点击、更新和删除协议产生歧义。

## 2. 快照与失效

`RenderSnapshotVersions.overlays` 是独立版本切片。交易对象变化只使 `tradeOverlay` Layer 失效，不重录网格、蜡烛、指标、最新价、绘图或十字线。

`tradeOverlay` 同时依赖 data、viewport、layout 和 theme：

- 数据或可见窗口变化时重新投影事件时间；
- 主图值域或布局变化时重新投影价格；
- 主题变化时重新解析买入、卖出和中立颜色。

版本由宿主单调推进；快照集合自身不可修改。

## 3. 绘制规则

标准栈顺序为 `marker → tradeOverlay → drawing → crosshair`，因此交易参考位于行情之上、用户绘图和交互十字线之下。

- PriceLine 横贯主图，并在右端显示可选标题与格式化价格；`visible=false` 时无输出；
- ValueMarker 位于主图右侧价格坐标，绘制实心点与文本；
- EventOverlay 使用与 K 线相同的时间 X Transform 和主图价格 Y Transform，事件不在可见窗口时无输出；
- `buy` 使用主题上涨色，`sell` 使用下跌色，`neutral` 使用标记色；
- 所有输出经主图 panel 裁剪，不覆盖副图或时间轴。

P8-01 仅负责通用、只读叠加原语。仓位、强平、挂单、止盈止损的业务组合属于 P8-02，命中、点击和拖动回调属于 P8-03。

## 4. 自动门禁

- 模型坐标和标识校验；
- Snapshot 三类集合不可变及跨类型重复 ID 拒绝；
- 标准 Layer 顺序与依赖集合；
- 买入、卖出、中立三种主题色的离屏像素输出；
- overlays-only 帧只重录 `tradeOverlay`；
- data、viewport、layout、theme 变化时正确重新投影；
- 完整 Flutter 回归保持通过。
