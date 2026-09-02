# K 线 2.0 深度模型与累计曲线协议

> 任务：P8-04、P8-05
>
> 状态：已实现
>
> 日期：2026-09-02

## 1. 模型边界

V2 深度模型位于 `model` 模块，不依赖 Flutter、交易所 SDK、网络或旧 `DepthEntity`：

- `DepthLevel`：一个严格为正的有限价格和数量；
- `DepthBook`：不可变买卖档位，买盘按价格严格降序、卖盘按价格严格升序，均以最优价为首档；
- `DepthCumulativeLevel`：源档位及从最优价向外累计的数量；
- `DepthCurve`：一次性生成两侧累计序列和共享最大累计量。

两侧同时存在时要求 `bestBid < bestAsk`，拒绝重复价格、乱序档位和交叉盘口。空盘口、单边盘口和单档盘口均为有效状态。`DepthBook` 直接提供买一、卖一、中间价、价差和价差百分比；任意一侧缺失时，两侧行情派生值返回 null。

模型集合在构造时复制为只读列表，并提供结构相等语义，便于宿主按版本或值稳定判断重绘。

## 2. 累计规则

每侧从最优价向外累加原始数量：

```text
累计量[i] = quantity[0] + ... + quantity[i]
```

买卖曲线共享 `maxCumulativeQuantity` 作为 Y 比例尺，避免两侧各自缩放后产生虚假的流动性对比。单档累计量等于该档原始数量，累计溢出为非有限值时拒绝生成曲线。

## 3. 布局与投影

`DepthChartLayout` 将区域拆为买盘半区、中间价差间隙、卖盘半区和底部价格轴。布局尺寸、顶部留白、轴高度和中间间隙都要求有限且能形成正面积绘图区。

`DepthCurveProjection` 使用真实价格距离计算 X，而不是像旧版一样按档位索引等宽分布：

- 买一位于中间间隙左侧，价格越低越靠左；
- 卖一位于中间间隙右侧，价格越高越靠右；
- 单档盘口固定在靠近价差的一侧；
- Y 使用两侧共享最大累计量，累计越大越靠上。

投影结果保持模型的“最优价向外”顺序并冻结集合，Renderer 只负责按屏幕方向连接阶梯曲线。

## 4. 纯渲染

`DepthRenderSnapshot` 独立于 K 线 `RenderSnapshot`，只包含不可变盘口、累计曲线、主题、布局和非负版本号。`StandardDepthCurveRenderer`：

- 绘制主题背景和轻量网格；
- 绿色买盘、红色卖盘分别限制在自己的半区；
- 使用阶梯线和半透明面积表达累计量；
- 底部显示外侧价格和中间价，右上显示共享最大累计量；
- 不保存 Canvas、不修改模型、不发布事件或业务状态。

V2 中文 Demo 根据当前 K 线最新价生成确定性示例盘口，并显示买一、卖一和价差。旧 `DepthChart` 与 `DepthEntity` 本阶段保持兼容，不改写其行为。

## 5. 快照、增量与连续性

P8-05 在 `data` 模块提供交易所无关的同步协议：

- `DepthBookSnapshotEvent`：交易对、最后 update ID 和完整标准化盘口；
- `DepthDeltaEvent`：交易对、首末 update ID、可选上一事件末 ID，以及两侧档位更新；
- `DepthLevelUpdate`：数量大于零表示插入或覆盖，数量为零表示删除；
- `DepthBookState`：最后有效盘口、交易对、update ID、版本和同步状态；
- `DepthRealtimeCoordinator`：每实例 generation、预快照缓冲、合并、连续性判断和恢复。

核心连续性规则与 Binance 官方本地订单簿同步规则一致，但类型不依赖 Binance SDK：

1. `finalUpdateId <= localUpdateId`：旧事件或重复事件，忽略且不推进版本；
2. `firstUpdateId <= localUpdateId + 1 <= finalUpdateId`：事件覆盖下一期望 ID，可以应用；
3. `firstUpdateId > localUpdateId + 1`：存在 update ID 缺口，保留最后有效盘口并进入 `outOfSync`；
4. 精确续接事件携带 `previousFinalUpdateId` 时，它必须等于本地 update ID；
5. 合并后若形成交叉盘口，同样进入失步状态并请求干净快照。

快照到达前，增量事件按到达顺序缓冲。应用快照时先丢弃已被 `lastUpdateId` 覆盖的事件，再重放能够桥接的事件；无法桥接的事件继续保留，供更新快照恢复。缓冲容量有硬上限，溢出后清除不安全事件并要求重新获取快照。同一 generation 不允许混入不同交易对；切换 generation 会使旧快照请求和旧流事件失效。

参考：[Binance 官方本地订单簿同步规则](https://developers.binance.com/zh-CN/docs/products/spot/testnet/web-socket-streams)。

## 6. 后续边界

P8-04/P8-05 已冻结静态模型、累计数学、纯渲染和同步恢复。以下内容不在本任务内：

- P8-06：1,000 买档 + 1,000 卖档、10 Hz 更新的裁剪、采样、缓存与 Profile 门禁；
- BN-O03：长按命中价格和累计数量。

## 7. 自动门禁

- 价格、数量、排序、唯一性和交叉盘口校验；
- 空、单边、单档和正常双边盘口；
- 集合不可变、结构相等和累计溢出拒绝；
- 买卖累计结果与共享最大量；
- 真实价格距离 X 投影和共享数量 Y 投影；
- 买卖颜色分区的离屏像素输出；
- Render 纯度和模块依赖方向；
- 中文 Demo 的买一、卖一、价差和 Canvas 装配；
- 快照前缓冲、快照覆盖丢弃和连续事件重放；
- 插入、更新、零数量删除及排序恢复；
- 重复事件、区间桥接、ID 缺口和 `pu` 连续性；
- 失步保留最后有效盘口并由更新快照恢复；
- 缓冲上限、交易对隔离和 generation 隔离；
- 中文 Demo 的正常增量、模拟丢包和重新同步闭环；
- 完整 Flutter 回归保持通过。
