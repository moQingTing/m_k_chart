# K 线 2.0 Layer 精确重绘协议

> 任务：P5-04
>
> 状态：已实现
>
> 日期：2026-08-25

## 1. 核心语义

`RetainedRenderLayerCompositor` 为每个 Layer 保留一张最新 `Picture` 和只包含该 Layer 依赖切片的版本戳。首帧录制全部 Layer；后续帧只要依赖版本戳相同，就复用 Picture，不再次调用该 Layer 的 `paint()`。

复用不等于省略输出。每一帧仍把 grid → main → secondary → axis → marker → drawing → crosshair 的全部 Picture 按固定顺序绘制到目标 Canvas，因此新 Canvas 上不会丢失未变化图层。

## 2. 标准 Layer 失效矩阵

| Layer | data | viewport | selection | history | layout | theme |
| --- | :---: | :---: | :---: | :---: | :---: | :---: |
| grid |  |  |  |  | ✓ | ✓ |
| main | ✓ | ✓ |  |  | ✓ | ✓ |
| secondary | ✓ | ✓ |  |  | ✓ | ✓ |
| axis | ✓ | ✓ |  |  | ✓ | ✓ |
| marker | ✓ | ✓ |  |  | ✓ | ✓ |
| drawing | ✓ |  |  |  | ✓ | ✓ |
| crosshair |  |  | ✓ |  | ✓ | ✓ |

当前标准 Stack 没有 history 可见 Layer，因此 history-only 变化不会触发误重绘。后续加载提示 Layer 必须显式声明 history 依赖。

## 3. 版本规则

- `RenderLayerVersionStamp` 对未声明依赖的切片保存 null，使无关版本变化不参与相等比较。
- 第一帧报告该 Layer 的全部依赖切片；后续只报告实际变化的依赖切片。
- 同一 Compositor 接受的六类版本必须单调不减；任一版本倒退都抛出 `StateError`。
- 相同版本必须代表相同切片载荷。Compositor 不做大对象深比较，也不以总 revision 代替切片版本。
- `RenderSnapshot.mainMode` 属于 theme 可见配置；切换蜡烛、分时或面积时调用方必须推进 theme 版本，因此依赖 theme 的标准 Layer 会一致重录。
- `clear()` 只释放保留 Picture，不重置累计诊断或已接受的单调版本基线。

## 4. 事务与生命周期

变化 Layer 先录制到候选 Picture。只有全部候选均成功后，才统一替换旧 Picture、推进版本戳和 repaint/reuse 计数；任一 Layer 抛错时，本帧候选全部释放，旧的完整帧状态保持不变。

`StandardChartRenderPipeline` 的释放顺序是先释放每层保留 Picture，再释放 P5-03 的 TextPainter/Path/Picture 缓存。dispose 幂等，之后 paint/clear 均拒绝访问。每个 Pipeline 独立持有 Compositor、Picture 与计数，不存在跨图表 static 状态。

## 5. 诊断协议

每个成功帧返回不可变 `RenderLayerFrameReport`：

- 递增的 frame number；
- 按 Stack 顺序排列的 repainted/reused Layer ID；
- 每个重录 Layer 的实际失效切片。

累计 `RenderLayerRepaintStats` 提供每层 repaint/reuse 次数。P5-07 可直接用该协议建立 Widget/Golden repaint 门禁，无需从日志推断。

## 6. 自动化证据与边界

- 六切片标准失效矩阵与首帧/无变化帧；
- selection-only 完整像素合成：背景保留、Crosshair 更新；
- 录制失败事务回滚与成功重试；
- 版本倒退拒绝、报告/统计不可修改；
- clear、幂等 dispose、双实例隔离；
- 2,000 根 + 2 副图无变化和 selection-only Host Debug 基准；
- P5-07 Widget 宿主：selection-only 只重录 crosshair、相同 Snapshot 无 CustomPainter 重绘、viewport 只重录 main/secondary/axis/marker。

V2 Pipeline 尚未接入 production Widget；P5-06 已在 legacy Widget 建立 `RepaintBoundary` 和局部 `ListenableBuilder`，P5-07 已通过测试宿主建立 V2 Widget repaint 计数与 Golden。真机 UI/Raster、内存和 GC 仍由 P5-08 判定。
