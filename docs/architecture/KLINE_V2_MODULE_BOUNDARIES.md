# K 线 2.0 模块边界与依赖规则

> 状态：P1-01 架构契约
> 日期：2026-08-24
> 适用目录：`lib/src/`

## 1. 目标

新内核使用单向依赖，避免数据、状态、手势和 Renderer 再次互相引用。`lib/src` 在迁移期间与 1.x 代码并存，但新模块除 `adapter` 外不得反向依赖 legacy 实现。

## 2. 模块职责

| 模块 | 职责 | 禁止承担 |
| --- | --- | --- |
| `model` | 不可变 Kline、区间、快照和通用值对象 | Flutter Widget、IO、指标计算 |
| `theme` | 不可变主题和绘制样式值对象 | Canvas 绘制、运行状态 |
| `data` | K 线/深度 Store、实时合并、分页、同步和数据版本 | Widget、指标公式、绘制 |
| `indicator` | 指标协议、计算、Series 和缓存 | 手势、Widget、Canvas 生命周期 |
| `drawing` | 绘图对象、锚点、命令和序列化 | 直接绘制、Controller 生命周期 |
| `viewport` | 可见范围、坐标转换、布局和极值查询 | GestureRecognizer、Widget 状态 |
| `interaction` | 平移、缩放、长按等输入意图和状态机 | 业务 Store、Renderer、Widget 构建 |
| `controller` | 聚合 Store、Viewport、指标和交互意图，发布只读状态 | Canvas 绘制、BuildContext、网络请求 |
| `render` | RenderSnapshot、Layer、缓存和纯绘制 | 修改 Controller/Store、发送业务事件 |
| `widget` | Flutter 生命周期、组合 Controller/Interaction/Render | 指标公式、数据合并、坐标算法 |
| `adapter` | 1.x 实体/样式/API 与 2.0 模型的兼容转换 | 新功能逻辑、长期状态保存 |

## 3. 允许依赖

同模块内部引用默认允许；下表只列跨模块依赖：

| 来源 | 允许依赖 |
| --- | --- |
| `model` | 无 |
| `theme` | 无 |
| `data` | `model` |
| `indicator` | `model` |
| `drawing` | `model`、`theme` |
| `viewport` | `model`、`indicator`、`drawing` |
| `interaction` | `model`、`viewport` |
| `controller` | `model`、`theme`、`data`、`indicator`、`drawing`、`viewport`、`interaction` |
| `render` | `model`、`theme`、`indicator`、`drawing`、`viewport` |
| `widget` | 所有新模块，但不得引用 legacy 实现 |
| `adapter` | 所有非 `widget` 新模块，并允许引用 legacy 实现 |

## 4. 不变量

1. `model` 和 `theme` 是最底层，不依赖其他内部模块。
2. `data` 不知道指标、视口或 UI。
3. `indicator` 只接受模型/数值输入，不读取 Controller。
4. `interaction` 产生意图，不直接修改 Controller。
5. `render` 只读取快照；不得 import `controller`、`data`、`interaction` 或 `widget`。
6. `widget` 负责装配，不承载核心算法。
7. 只有 `adapter` 可以从 `lib/src` 反向 import 1.x 文件。
8. 正式公共入口仍只有 `lib/m_k_chart.dart`；本阶段不导出 `lib/src`。

## 5. 迁移顺序

```text
model/theme
    ↓
data + indicator + drawing
    ↓
viewport + interaction
    ↓
controller
    ↓
render
    ↓
widget
```

`adapter` 随各阶段补充，但不得成为新模块之间的中转层。

## 6. 自动守护

`test/architecture/module_dependency_test.dart` 会：

- 确认所有模块入口存在；
- 解析 `lib/src/**/*.dart` 的内部 import；
- 拒绝未在允许表中的跨模块依赖；
- 拒绝除 `adapter` 外的新模块 import legacy 文件。

调整依赖表必须先更新主开发计划和本文，并在评审中说明为何不会形成反向依赖或循环。
