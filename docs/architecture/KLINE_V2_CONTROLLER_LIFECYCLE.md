# K 线 2.0 Controller 生命周期

> 任务：P1-03  
> 状态：已实现  
> 日期：2026-08-24

## 1. 所有权

每个图表实例拥有一个独立 `KChartController`。Controller 持有自己的不可变 `KChartState` 快照、监听器和生命周期，不使用 static 字段保存滚动边界、选择、动画或其他运行状态。

宿主创建 Controller 时应明确所有权：

- Widget 内部创建：Widget 在自身 `dispose` 中销毁。
- 宿主注入：宿主负责销毁，Widget 不得越权 dispose。

后续 P1-05 冻结公共 Widget API 时，将通过构造参数和断言落实上述规则。

## 2. 通知契约

- Controller 实现只读 `ValueListenable<KChartState>`。
- 每个非空事务原子替换一次状态快照，并发送一次通知。
- 空事务保持原快照身份，不发送通知。
- 监听者只能读取状态，不得持有可变内部容器。
- P1-04 引入类型化事件后，所有公共操作均通过事件入口触发内部提交。

## 3. 销毁契约

- `dispose()` 可重复调用，实际资源只释放一次。
- 销毁后不再接受状态事务，调用会抛出 `StateError`。
- 后续引入的 AnimationController、StreamSubscription、Worker 或缓存句柄必须在同一生命周期中释放。

## 4. 实例隔离验收

自动化测试创建两个 Controller，仅更新其中一个，并断言另一实例的总修订号和所有切片版本均不变化。这是关闭 `ARCH-04` 的第一层结构证据；生产 Renderer 移除 static 状态后再完成最终关闭。
