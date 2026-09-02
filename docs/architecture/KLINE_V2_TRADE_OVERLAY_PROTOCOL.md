# K 线 2.0 交易叠加协议

> 任务：P8-01、P8-02、P8-03
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

P8-01 负责通用叠加原语，P8-02 负责仓位、强平、挂单、止盈止损的业务组合。P8-03 在不引入交易 SDK 的前提下补齐命中、点击、拖动和操作回调。

## 4. 业务组合示例

P8-02 在 Example 支持层提供 `buildDemoTradeOverlays`，将确定性的演示仓位和订单映射成五条通用 PriceLine：

- 多仓均价和强平价；
- 买入挂单；
- 多仓止盈和止损。

价格从当前 K 线窗口推导并约束在数据高低范围内，确保真实 OKX 数据和离线数据都能看到示例。ID 使用 `demo-position-*` 与 `demo-order-*` 稳定命名，为 P8-03 的命中回调提供身份。组合器只导入内部 V2 Example 桥接库，不导入 OKX、Binance、HTTP 或账户 SDK。

Demo 的 `trade-overlay-examples` 开关只推进 overlays 版本；开关交易示例不会伪造 data、theme 或 indicator 变化。所有文案使用中文，并明确这是演示数据而非真实账户状态。

## 5. 命中与交互协议

`ChartTradeOverlayHitTester` 使用与 Renderer 相同的主图价格值域和时间 X Transform，返回包含稳定 ID、对象类型、买卖方向、价格、距离及可选事件时间的 `ChartTradeOverlayHit`：

- PriceLine 在主图宽度内按 Y 距离命中，隐藏线不参与；
- ValueMarker 只在可配置的右侧标记带内命中；
- EventOverlay 同时计算时间 X 与价格 Y 的二维距离，并拒绝可见时间窗外事件；
- 命中容差和右侧标记带宽度可配置；重叠时遵循后绘制对象优先。

`ChartTradeOverlayInteraction` 统一表达 `tap`、`dragStart`、`dragUpdate`、`dragEnd` 和 `action`。拖动事件携带当前价格，操作事件必须携带非空 `actionId`，从而让宿主自行完成改价、撤单或其他业务动作；核心包不执行订单。

`ChartGestureRegion` 将交易对象垂直拖动识别器放入原有 Flutter Gesture Arena。只有 pointer-down 命中叠加对象时该识别器才参赛；命中后的点击不会继续打开 K 线详情，垂直拖动不会同时触发图表平移或父列表滚动，未命中区域保持原有点击、横向平移、双指缩放、长按十字线和父级纵向滚动行为。

Demo 使用同一协议实现选中操作区、实时拖价和“取消”按钮。Demo 只修改示例对象的本地价格/显隐状态并推进 overlays 版本；切换交易对、周期或完整替换数据时会清理交互状态。

## 6. 自动门禁

- 模型坐标和标识校验；
- Snapshot 三类集合不可变及跨类型重复 ID 拒绝；
- 标准 Layer 顺序与依赖集合；
- 买入、卖出、中立三种主题色的离屏像素输出；
- overlays-only 帧只重录 `tradeOverlay`；
- data、viewport、layout、theme 变化时正确重新投影；
- 五类业务线的稳定 ID、中文标签、有限可见价格和集合不可变；
- 业务组合器无交易所客户端和网络依赖；
- Demo 开关可关闭并恢复交易叠加示例；
- 价格线、右侧标记和事件点共享 Renderer 坐标投影并按容差命中；
- 点击交易对象抑制普通详情点击，点击空白区域仍进入普通详情；
- 交易线垂直拖动排除图表平移和父列表滚动；
- Demo 覆盖选中、拖价、取消操作完整闭环；
- 完整 Flutter 回归保持通过。
