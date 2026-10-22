# K 线 2.0 Phase 4 退出审查

> 审查任务：P4-07
>
> 结论：通过
>
> 日期：2026-08-25

## 1. 门禁证据

| 门禁 | 证据 | 结论 |
| --- | --- | --- |
| Viewport 实例所有权 | Viewport/边界由每个 Controller 独立持有，双实例触摸和桌面输入互不影响 | 通过 |
| 坐标往返 | 448 组 data/local、54 组不规则 time/local、54 组多面板 price/local 性质矩阵 | 通过 |
| 确定性布局 | 多尺寸、嵌套偏移、网格 N+1 端点、单/双副图和最小高度测试 | 通过 |
| Gesture Arena 合规 | 新链路不覆写 accept/reject，不强制接受已拒绝手势 | 通过 |
| 完整竞争矩阵 | slop、横向、纵向父级、静止长按、移动抢先、双指、取消序列稳定互斥 | 通过 |
| 跨平台输入 | 鼠标 hover/wheel、trackpad pan-zoom、横屏 resize 和禁用策略测试 | 通过 |
| 导航与分页 | 惯性、磁吸、时间定位、prepend 锚定和历史状态流测试 | 通过 |
| Host 输入状态延迟 | pan/scale/crosshair P95 为 16.42/3.46/3.89 μs | ≤1,000 μs，通过 |

## 2. ARCH-06 结论

V2 的 Viewport、X/Price Transform 和 LayoutModel 只消费 chart-local 坐标，不读取屏幕全局位置、RenderBox 或 legacy Painter 状态。不规则时间轴按实际 openTime 插值；网格、面板与尺寸均由确定性模型计算。坐标性质矩阵覆盖缩放、滚动、屏宽、数据外推、时间缺口、价格范围与面板位置。

因此 `ARCH-06` 在 V2 的坐标、布局和输入范围内关闭。Renderer 的视觉像素正确性、文字布局与多主题 Golden 由 Phase 5 继续验证，不把尚未实现的视觉链路计入本阶段结论。

## 3. ARCH-07 结论

- 单指先经过方向门禁，横向由图表 pan 获胜，纵向 reject 后由父 Scrollable 获胜；
- 双指进入标准 scale 连续序列，长按只在静止且未被移动 winner 抢先时产生 crosshair；
- pan、scale、crosshair 由每实例状态机互斥，end/cancel 后恢复 idle；
- 新链路架构扫描禁止 `acceptGesture(`、`rejectGesture(` 强制接管实现。

完整 Widget 竞争矩阵与纯状态机测试均通过，`ARCH-07` 在 V2 输入路径关闭。

## 4. ARCH-04 验证

Controller、Viewport、InteractionMachine、NavigationMachine、Ticker 和输入策略均归属单个图表实例。双图表测试分别验证触摸与桌面输入只改变命中实例，尺寸变化与 dispose 不向其他实例泄漏状态。

`ARCH-04` 对 V2 链路验证通过。legacy `ChartPainter.maxScrollX` 仍作为 1.x 行为基线存在，并明确由 P5-06 随 production Renderer 迁移移除；它不进入 V2 状态链路，本审查不提前宣告 legacy 全局清理完成。

## 5. 性能结论与限制

Phase 4 的 Host Debug benchmark 只覆盖 interaction state → intent → controller state。三条路径的 P95 均低于 1 ms 内部门槛，但这不是 UI/Raster 或 input-to-frame 测量。

Phase 5 必须在固定 Profile 设备继续验证 16.7 ms 常规帧、24 ms 低端帧和 32 ms crosshair 输入到帧预算；未达到时不得用本次 Host 数据替代。

## 6. 退出结论

Phase 4 的 Viewport、坐标、Layout、导航和跨平台输入接口已经冻结，`ARCH-06/07` 在 V2 范围内关闭，`ARCH-04` 验证通过，单指、双指、长按和父容器竞争稳定互斥。

允许进入 P5-01，定义只读 RenderSnapshot 和 Layer 协议。生产 Painter 在新 Renderer 就绪前保持不变。
