# K 线 2.0 RenderSnapshot 与 Layer 协议

> 任务：P5-01
>
> 状态：已实现，P5-05 已迁移内部 V2 主图模式与 legacy 指标视觉语义
>
> 日期：2026-08-25

## 1. 目标

新 Renderer 只读取一个完整、稳定且经过校验的 `RenderSnapshot`。Layer 只能把该快照转换为 Canvas 可见输出，不能修改 Controller、Store、Interaction 或 Widget 状态。

P5-01 冻结输入与扩展协议；P5-02 已实现内部标准 Layer Stack，P5-03 已接入实例级缓存，P5-04 已按依赖版本保留并重录独立 Layer Picture，P5-05 已补齐蜡烛、分时、面积和 legacy 指标视觉语义，但仍不修改 production Painter。

## 2. RenderSnapshot

`RenderSnapshot<TTheme>` 包含：

- 稳定的 `VersionedKlineData`，直接持有只读视图，不复制完整 Kline 列表；
- 与数据长度一致的 `ChartViewport`；
- drawing width 与 Viewport 一致的 `ChartLayoutModel`；
- 调用方保证不可变的泛型主题值；P6-01 将其收敛为正式 `KChartTheme`；
- data/viewport/selection/history/layout/theme 六类 Renderer 版本；
- 只包含可绘制结果的指标投影；
- chart-local 选择状态和最小历史加载显示状态。
- chart-local 绘图线段投影；在 P7 完整绘图状态建立前，其变化归入 data 版本。

Snapshot 构造时一次性验证跨模块不变量，paint 阶段不再修复非法输入。

## 3. 指标投影

`RenderIndicatorSnapshot.fromResult` 从 Engine Result 投影：

- instance/definition/data version 和结果长度；
- `IndicatorRendererDescriptor`；
- 目标 panel ID；
- 不复制数值存储的不可变 `IndicatorSeries` 列表。

投影必须保证 Result Series ID 与 Descriptor 完全一致。装配到完整快照时继续校验数据版本、长度、实例唯一性、panel 存在性以及 main/separate placement。

`IndicatorComputationState` 不进入投影。Renderer 无法读取递归指标的 continuation state，避免把计算缓存误作绘制状态。

## 4. 选择与历史投影

Render 模块不允许依赖 Interaction，因此装配层把状态转换为 Renderer 自有值对象：

- `RenderSelectionSnapshot` 使用 chart-local X/Y；snap index、price、OHLC kind 必须全有或全无；
- visible 选择必须使用有限坐标和价格，snap index 必须位于当前数据；
- `RenderHistorySnapshot` 只携带 idle/loading/noMore/failure 显示语义，不暴露分页控制命令。

该投影保持 `Interaction → Controller/Widget assembly → RenderSnapshot → Layer` 单向流动。

## 5. Layer 协议

每个 `ChartRenderLayer<TTheme>` 必须声明：

- 非空稳定 ID，作为排序、查找和后续缓存身份；
- 非空 `RenderSnapshotSlice` 依赖集合；
- 只接受 `RenderLayerContext` 的 `paint` 方法。

Context 只提供当前 Canvas 与只读 Snapshot。Layer 可以持有由输入版本控制的 Paint/Path/Text/Picture 缓存，但不得保留 Canvas、发布业务事件或写入应用状态。

`RenderLayerStack` 冻结绘制顺序和 ID 查找表，拒绝重复 ID。P5-02 已注册 grid/main/secondary/axis/marker/drawing/crosshair；P5-04 的保留式 Compositor 只比较每个 Layer 声明的版本依赖，重录变化层并按固定顺序合成全部 Picture。

## 6. 自动门禁

- Snapshot：数据/Viewport/Layout/选择/指标版本与面板不变量；
- 不可变性：外部输入集合后续修改不影响 Snapshot/Stack，公开集合不可写；
- Layer：ID、依赖、顺序、查找与 Canvas Context；
- 模块依赖：render 不得 import controller/data/interaction/widget 或 legacy；
- 纯度扫描：禁止 Stream、dispatch、notifyListeners、setState 和指标 continuation state；
- 正式公共入口不导出本阶段内部协议。
- runtime 实例隔离扫描覆盖 render，禁止用 mutable static 共享缓存。

## 7. 后续边界

- P5-02：已实现网格、主图、副图、轴、标记、绘图和十字线 Layer；
- P5-03：已实现可见区、极值、Text/Path/Picture 有界缓存；
- P5-04：已按 Layer 依赖切片实现精确失效、保留式 Picture 合成与 repaint 计数；
- P5-05：已实现 `candlestick`/`line`/`area` 主图模式及 Descriptor 驱动的 Volume、MACD、SAR 视觉语义；
- P5-06：新链路完成后移除 legacy paint 写状态和 static 边界；
- P6-01：将泛型主题收敛为完整不可变 KChartTheme。
