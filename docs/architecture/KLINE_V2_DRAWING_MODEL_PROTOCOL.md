# V2 绘图模型协议

P7-01 定义内部不可变 `ChartDrawing`，其锚点始终是 UTC 毫秒与价格，不使用画布像素。因此缩放、尺寸变化和周期切换可以在后续阶段重新投影，而不会把一次屏幕布局固化到数据中。

每个对象包含稳定 ID、工具类型、至少所需数量的 `ChartDrawingAnchor`、语义样式 `ChartDrawingStyle` 和可选文本。样式只使用颜色 key、线宽、虚线节奏和可见性，不携带 Flutter `Color`、Canvas 或 Widget。

`toJson()` 当前输出 schema v1；未带版本的旧 shape 自动迁移：`type` → `kind`、`points` → `anchors`、`color/width` → `style`。未来 schema 会明确抛出 `UnsupportedError`，避免旧代码静默丢失工具数据。

P7-01 冻结模型和 JSON；P7-02 已加入与 viewport 解耦的控制点投影和命中协议。具体工具渲染、编辑命令与跨周期恢复分别在 P7-03～P7-06 完成。
