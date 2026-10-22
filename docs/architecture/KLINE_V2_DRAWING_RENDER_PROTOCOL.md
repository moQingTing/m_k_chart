# V2 基础绘图渲染协议

P7-03 将 `ChartDrawing` 接入标准 Render Layer。`RenderSnapshot.anchoredDrawings` 保存不可变的时间/价格锚点对象；`RenderSnapshotVersions.drawings` 是独立版本切片，因此只改变绘图时只会使 `drawing` Layer 失效，不会重绘蜡烛、指标或十字线。

绘制时 `ChartDrawingRenderer` 使用当前 `ChartXTransform` 和主图 `ChartPriceTransform` 重新投影锚点，并裁剪到主图 drawable bounds。这样水平滚动、缩放、尺寸变更和价格范围变化都不会改变已保存对象的锚点含义。

基础对象行为如下：

- 趋势线、水平线、垂直线和射线；
- 矩形与三锚点平行通道；
- 两锚点区间内的 0、23.6、38.2、50、61.8、78.6、100% 斐波那契回撤；
- 文本与右侧价格标记。

`ChartDrawingStyle` 的线宽、可见性和虚线节奏在渲染时生效。颜色 key 仍保持为模型层的语义引用，当前标准主题使用 `drawingColor` 作为默认解析结果；宿主主题的专属颜色映射会在后续主题扩展中接入，避免将 Flutter `Color` 写入持久化 JSON。

旧的 `RenderLineDrawing` 保留为兼容性输入，和 `anchoredDrawings` 并行绘制；新功能应使用后者。P7-04 将在本协议和 P7-02 命中协议之上提供创建、选择、磁吸、移动、锁定与删除。
