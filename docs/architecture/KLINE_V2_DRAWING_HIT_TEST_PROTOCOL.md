# V2 绘图命中与控制点协议

P7-02 将绘图的持久化锚点与屏幕几何明确分为两层：

- `ChartDrawingAnchor` 仍只保存 UTC 毫秒和价格；
- viewport 的 `ChartDrawingAnchorProjector` 依据当前 `ChartXTransform`、`ChartPriceTransform` 生成 chart-local `ChartDrawingControlPoint`；
- drawing 模块的 `ChartDrawingHitTester` 只接收已经投影的控制点和本地触点，不依赖 Flutter、Canvas 或 viewport。

这一分层保证缩放、滚动、切换副图与重绘后，命中行为总是以同一份时间/价格锚点重新计算；同时保持内部模块依赖方向为 `viewport -> drawing`，不反向耦合。

## 命中顺序与容差

`ChartDrawingHitTester.hitTest` 先尝试半径为 `controlPointTolerance` 的控制点，并返回距离最近的点；只有未命中控制点时才检查图形本体。命中本体的有效容差为 `bodyTolerance + strokeWidth / 2`，因此较粗的线不会出现“看得到却点不中”。不可见绘图不参与命中。

本阶段固定的基本几何规则如下：

- 水平线与竖线在对应方向上无限延伸；
- 趋势线和其它多锚点线按连续线段计算；
- 射线从第一个锚点沿第二个锚点方向无限延伸；
- 矩形以首两个锚点作为对角，只命中四条边；
- 文本和价格标记目前仅通过它们的控制点选中。

调用方必须为一个绘图提供与其锚点一一对应、连续编号的控制点；混入其他绘图或缺失控制点会立即抛出 `ArgumentError`，避免编辑状态串到错误对象。空行情数据无法投影控制点，投影器返回空列表。

P7-03 将复用这套命中协议实现基础工具的可视化；P7-04 在此基础上增加磁吸、拖动、锁定和删除生命周期。
