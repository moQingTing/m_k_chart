# V2 内部核心模块

此目录中的代码是 K 线图 V2 的核心实现，不是稳定的公开导入入口。业务项目应从包的
公开导出文件接入，避免直接依赖 `lib/src` 中可能随架构演进调整的内部类型。

核心数据流为：`adapter/data` 将远端或本地数据整理为不可变 K 线快照；`indicator`
根据快照版本计算并缓存指标；`viewport/interaction` 把输入转换为不可变视口与选中状态；
`render` 只读取快照并绘制；`widget` 负责 Flutter 手势与语义接入。这样数据更新、计算、
交互和绘制可以独立测试与替换。

模块职责与允许的依赖方向定义在
`docs/architecture/KLINE_V2_MODULE_BOUNDARIES.md`，并由
`test/architecture/module_dependency_test.dart` 强制校验。除 `adapter` 外，内部模块都不得
导入 `lib/src` 外的旧版实现，防止新版渲染与旧状态模型产生隐式耦合。
