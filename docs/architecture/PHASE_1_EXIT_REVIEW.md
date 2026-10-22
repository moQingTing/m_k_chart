# K 线 2.0 Phase 1 退出审查

> 审查任务：P1-06  
> 结论：通过  
> 日期：2026-08-24

## 1. 门禁证据

| 门禁 | 证据 | 结论 |
| --- | --- | --- |
| 模块目录与依赖方向 | `module_dependency_test.dart` 检查 11 个入口、依赖矩阵和 legacy 隔离 | 通过 |
| 不可变状态与版本 | `k_chart_state_test.dart` 检查空事务、版本单调、切片隔离和值语义 | 通过 |
| 单向事件流 | `k_chart_event_test.dart` 检查类型事件和复合输入单事务 | 通过 |
| 双实例隔离 | `k_chart_controller_test.dart` 独立更新两个 Controller | 通过 |
| dispose 生命周期 | Controller 幂等销毁、销毁后拒绝事件 | 通过 |
| 无全局运行状态 | `runtime_state_isolation_test.dart` 禁止新运行模块声明可变 static 字段 | 通过 |
| Renderer 纯度 | `render_purity_test.dart` 禁止反向状态写入和异步事件出口 | 通过 |
| 公共 API surface | `public_api_surface_test.dart` 检查正式入口、兼容入口和公共符号 allowlist | 通过 |
| legacy 行为不回归 | 全量 `flutter test` | 通过 |
| 静态质量 | 定向 `dart analyze`、`git diff --check` | 通过 |

## 2. 八项架构问题的阶段状态

| 问题 | Phase 1 结果 | 后续关闭点 |
| --- | --- | --- |
| `ARCH-01` 模型与指标耦合 | 模块依赖已阻止新链路重新耦合 | P2、P3 完成实体迁移 |
| `ARCH-02` Widget 职责过载 | Controller/状态/事件所有权已冻结 | P4、P6 接入新 Widget |
| `ARCH-03` Painter 副作用 | 新 Renderer 纯度守卫生效 | P5-06 移除 legacy Stream 写入 |
| `ARCH-04` 全局共享状态 | 新 Controller 实例隔离且禁止 mutable static | P4/P5 移除 legacy `maxScrollX` |
| `ARCH-05` 重绘失控 | 状态切片版本可供 Layer 精确比较 | P5 分层渲染兑现 |
| `ARCH-06` 坐标/布局缺陷 | Viewport/Layout 所有权边界已冻结 | P4 实现与验证 |
| `ARCH-07` 手势竞争 | Interaction 只产出意图的边界已冻结 | P4 状态机实现 |
| `ARCH-08` API/扩展封闭 | 唯一入口和 API allowlist 已冻结 | P3/P6 扩展协议落地 |

Phase 1 关闭的是新链路的结构风险和准入规则，不宣称 legacy Renderer 已完成迁移。旧实现仍作为行为基线保留，按任务依赖逐步由 adapter 替换。

## 3. 性能审查

- 状态提交使用 O(事件数 + 固定切片数) 的小集合合并，不复制 K 线数据。
- 空事务不创建新状态、不通知监听器。
- 局部 Layer 可比较单个切片版本，避免以总 revision 全量重绘。
- 每个复合输入最多发布一次通知，减少中间无效帧。
- Renderer 缓存允许存在，但不能成为业务状态源，且必须由输入版本失效。

上述为结构性能保证；帧耗时仍以 Phase 0 基线为参照，在 P5 Profile 门禁中验证实际收益。

## 4. 退出结论

P1-01～P1-06 已满足退出条件，可以开始 P2-01 不可变 Kline、Interval、PriceSource 和数据版本。继续遵守以下限制：

1. P2 只建设模型、Store 和 adapter，不提前迁移生产 Painter。
2. legacy 公共行为必须继续通过现有测试。
3. 新 API 未通过所属 Phase 门禁前不加入正式公共入口。
4. allowlist、依赖矩阵或状态协议变化必须先更新架构文档再实现。
