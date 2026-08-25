# K 线 2.0 LayoutModel 与网格协议

> 任务：P4-03
> 状态：已实现
> 日期：2026-08-25

## 1. 目标与坐标归属

`ChartLayoutModel` 是纯 Dart 不可变布局结果，所有矩形和网格位置均使用当前图表实例的 chart-local 逻辑像素。模型不读取 `BuildContext`、屏幕坐标、设备方向或 legacy Painter；Widget 只需把约束尺寸转换成显式输入。

布局输出包括：

- `drawingBounds`：排除左右 padding、顶部 padding 和底部时间轴后的总绘制区域；
- `timeAxisBounds`：底部时间轴区域；
- 一个主图 `ChartPanelLayout`；
- 按调用顺序排列的零个或多个副图；
- 精确的列网格 X 和逐 panel 行网格 Y；
- panel ID 到布局的只读索引。

## 2. Panel 分配规则

每个 `ChartPanelSpec` 声明稳定 ID、类型、正权重、正最小高度和正网格行数。第一项必须为 main，后续只能为 secondary，ID 必须非空且唯一。

```text
panelSpace = chartHeight - topPadding - bottomAxisHeight
             - panelSpacing * (panelCount - 1)
required = sum(panel.minHeight)
extra = panelSpace - required
panel.height = panel.minHeight + extra * panel.weight / sum(weights)
```

- `panelSpace < required` 时构造失败，不压缩到不可用高度，也不制造重叠；
- 只有主图时，主图占满全部 panelSpace；
- 多副图顺序与输入一致；
- 最后一个 panel 的 bottom 直接钉住 `drawingBounds.bottom`，消除累计浮点误差；
- 矩形命中采用半开区间 `[left,right) × [top,bottom)`，相邻区域不会重复命中边界；
- panel 间距独立于 panel 内容，不复用 legacy `childPadding` 的含混语义。

默认主图最小高度 120、权重 3、网格 4 行；默认副图最小高度 60、权重 1、网格 2 行。P6-04 可通过 spec 提供用户配置，但不得绕过最小高度门禁。

## 3. 网格数量

`gridColumns` 和 `gridRows` 均表示区间数，而不是线数或像素间距：

- 全宽竖线数量固定为 `gridColumns + 1`，包含左右边界；
- 每个 panel 的横线数量固定为 `panel.gridRows + 1`，包含上下边界；
- 坐标通过 `start + extent * index / intervals` 计算；
- 输出集合及嵌套集合均不可写。

此协议直接防止 legacy `for (i <= columnSpace)` 将像素间距误当循环次数的问题。P5 Renderer 只遍历模型给出的坐标，不自行重新计算网格数量。

## 4. Viewport 与状态事务

`ChartLayoutModel.applyTo(viewport)` 将 `drawingBounds.width` 写入新 Viewport，并复用 P4-01 的边界归一化。Controller 在处理任何事件批次后，只要已有 LayoutModel，就强制执行该宽度同步。

布局变化在一次原子事务中：

1. 更新 `KChartState.layout`；
2. 若绘制宽度变化，同时更新 `KChartState.viewport`；
3. 总 revision 只增加一次；
4. 分别增加实际变化的 layout/viewport 切片版本；
5. 结构相同的布局不通知监听器。

因此 Renderer 不会观察到“新布局 + 旧 Viewport 宽度”的中间状态。

## 5. 边界与后续

- Layout 输入的所有 double 必须有限且非负，总尺寸必须为正；
- 左右 padding 必须留下正绘制宽度；顶部 padding 和时间轴必须留下 panel 空间；
- `ChartLayoutRect` 只表达输出边界，不承担 Flutter `Rect` 生命周期；
- 价格范围、平盘 padding 和极值查询不是布局职责；
- P4-04 输入状态机消费 drawing/panel 边界；
- P4-06 在横屏、父滚动和双实例 Widget 场景验证约束输入；
- P5 Layer 使用只读 LayoutModel 生成网格、坐标轴和裁剪区域。

## 6. 验证

- 单主图填满与主图 + 两副图权重分配；
- 最小高度、间距、首尾边界和浮点闭合；
- 多尺寸、左右/顶部/底部 inset 与嵌套 chart-local 坐标；
- 网格区间数 `N` 精确生成 `N+1` 个位置；
- 所有输出集合不可写，结构相等可用于精确状态比较；
- 尺寸不足、重复 ID、错误 panel 类型、非正权重/高度/网格拒绝；
- Layout + Viewport 原子版本提交及相同布局空事务。
