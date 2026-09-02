# m_k_chart 2.0：币安风格 K 线整改开发计划

> 文档状态：执行复审通过，可按任务清单推进
> 计划版本：v1.2
> 基线版本：v1.0.4 / `main`
> 建立日期：2026-08-24
> 最近更新：2026-08-24
> 适用范围：Flutter 插件、Example Demo、Android/iOS/Web
> 维护规则：每个开发任务必须关联本文任务编号；范围、接口或性能目标发生变化时，先更新本文再实施。

## 1. 文档目的

本文用于指导 `m_k_chart` 从当前 K 线组件升级为接近币安 App 专业交易页体验的通用 Flutter K 线插件，并作为需求、架构、开发顺序、验收和性能回归的统一依据。

目标是对标币安稳定的图表能力和交互模型，不复制 Binance 商标、素材或业务页面，也不在插件内部实现账户、鉴权和下单逻辑。

> 状态同步（2026-09-01）：Phase 任务的状态以
> `KLINE_V2_EXECUTION_ROADMAP.md` 为准；本章功能勾选仅表示对应的
> V2 能力已实现并有示例或自动化验证，不代表 Alpha/Stable 发布门禁已通过。

## 2. 审核结论

### 2.1 总体结论

计划整体可行，但必须采用“兼容式重构”，不建议继续在当前结构上直接增加大量指标和绘图工具。

原因如下：

1. 当前项目约 5,500 行 Dart 代码，规模可控，具备蜡烛图、分时线、深度图、常用指标和手势基础，重构成本低于完全重写。
2. 当前 `KLineEntity` 通过多个 mixin 和大量 `late` 字段保存计算结果，数据、指标和渲染高度耦合，继续扩展容易产生未初始化错误及内存膨胀。
3. 当前图表在 Widget 每次重建时创建新的 `ChartPainter`，`shouldRepaint()` 始终返回 `true`，拖动、缩放、动画和十字线都会触发全图重绘。
4. 当前可见区极值和副图极值在绘制周期内重复扫描；文本排版、Path 和部分 Paint 对象也会在高频绘制中创建。
5. 当前手势通过 `setState()` 刷新整个图表 Stack，十字线详情还通过绘制阶段向 Stream 写入数据，职责边界不清晰。
6. 当前指标主要采用全量计算，虽然已有更新最后一条数据的入口，但尚未形成统一的增量指标协议。
7. 测试只覆盖少量数据工具和 Demo 首次加载，缺少公式对照、手势、Golden、实时流和性能基准测试。

因此采用以下路线：

```text
冻结兼容基线
    ↓
架构契约、Controller 与状态骨架
    ↓
新数据模型与实时 Store
    ↓
独立指标引擎 + 视口/布局/手势状态机
    ↓
纯函数分层渲染内核
    ↓
币安式基础体验
    ↓
绘图、合约叠加、深度图增强
    ↓
跨平台性能与正式发布
```

### 2.2 可行性评级

| 范围 | 可行性 | 主要风险 | 结论 |
| --- | --- | --- | --- |
| 数据模型与实时 K 线 | 高 | 时间戳、乱序、重复事件 | 优先实施 |
| 现有指标迁移 | 高 | 公式口径、历史兼容 | 可控 |
| 分层渲染和手势 | 高 | 改动公共组件核心 | 需要 Golden 与性能门禁 |
| 多副图和动态布局 | 高 | 坐标联动、布局缓存 | 可控 |
| Heikin-Ashi、VWAP 等 | 高 | 合成价格与真实价格区分 | 可控 |
| 绘图工具 | 中高 | 命中测试、坐标持久化 | 独立阶段开发 |
| 合约仓位/订单叠加 | 高 | 业务模型差异 | 仅提供通用 Overlay API |
| TradingView/Pine Script 兼容 | 低 | 解释器、脚本生态和授权成本 | 不纳入 2.0 |
| Renko、Kagi、Point & Figure | 中低 | 数据重采样和交互模型不同 | 2.x 后续评估 |

### 2.3 工期审核

在不实现 Pine Script、策略回测和完整 TradingView 图表类型的前提下：

- 单人开发：约 11～15 周。
- 两人并行：约 7～10 周，其中指标引擎与视口/手势可在架构契约冻结后并行。
- 建议额外预留 20% 缓冲，用于跨平台差异、性能回归和 API 兼容。

若第一版仅要求“币安基础 K 线体验”，完成 Phase 0～6 即可，单人约 7～10 周。工期增加的原因是先偿还八项核心架构债务，不再把结构整改隐藏在功能开发中。

### 2.4 执行性复审结论

计划在范围和技术路线层面可执行，正式进入开发前补充以下控制条件：

1. Phase 0 的性能基线允许记录旧架构无法稳定输出原生 `FrameTiming` 的限制，但必须保留可重复的主机绘制耗时和真机 Profile 测量；Phase 5 必须恢复 UI/Raster 原生帧指标。
2. Phase 1 冻结模块依赖、状态切片、Controller 生命周期和公共 API allowlist；未冻结前不得大规模创建新目录或迁移 Renderer。
3. Phase 2 冻结 Kline/Store 输入协议后，Phase 3 指标与 Phase 4 视口手势才可并行；二者不得直接依赖对方实现。
4. Phase 5 是关键性能门禁。未达到帧预算时不得用关闭测试、减少指标或降低默认能力的方式直接进入 Phase 6，必须记录降级决策。
5. Phase 0～6 为 2.0 Alpha 必须范围；Phase 7～8 属于后续扩展，若关键路径延期可后置，但不得削弱 Phase 9 发布质量门禁。

具体开发清单、时间窗口和里程碑见 [m_k_chart 2.0 开发清单与时序线](KLINE_V2_EXECUTION_ROADMAP.md)。

## 3. 对标范围

### 3.1 信息与行情

- [ ] `BN-F01` 交易对、最新价、折算法币价格。
- [x] `BN-F02` 24h 涨跌额、涨跌幅、最高、最低、成交量和成交额。
- [x] `BN-F03` OHLC、涨跌额、涨跌幅、振幅和选中时间详情。
- [x] `BN-F04` 最新价格线、价格标签和当前 K 线收盘倒计时。
- [x] `BN-F05` 可见区最高价、最低价标记。

### 3.2 图表类型

- [x] `BN-F10` 标准蜡烛图。
- [x] `BN-F11` 分时折线图。
- [x] `BN-F12` 面积图。
- [x] `BN-F13` 实心/空心蜡烛。
- [x] `BN-F14` Heikin-Ashi 平均 K 线。
- [ ] `BN-F15` 深度图。
- [x] `BN-F16` 横屏和全屏。

首个 2.0 正式版不包含 Renko、Kagi、Range、Point & Figure。

### 3.3 周期体系

- [x] `BN-F20` 支持 `1s`。
- [x] `BN-F21` 支持 `1m/3m/5m/15m/30m`。
- [x] `BN-F22` 支持 `1h/2h/4h/6h/8h/12h`。
- [x] `BN-F23` 支持 `1d/3d/1w/1M`。
- [ ] `BN-F24` 自定义快捷周期和收藏。
- [x] `BN-F25` UTC、UTC+8 及宿主传入时区。
- [ ] `BN-F26` 周期切换时可配置是否保留缩放、指标和绘图。

### 3.4 手势与导航

- [x] `BN-F30` 单指平移和惯性滑动。
- [x] `BN-F31` 双指缩放，并以手势焦点为缩放中心。
- [x] `BN-F32` 长按十字线和 OHLC 磁吸。
- [x] `BN-F33` 价格轴、时间轴浮动标签。
- [x] `BN-F34` 左滑触发历史分页，具备 loading、noMore 和 retry 状态。
- [x] `BN-F35` 回到最新 K 线按钮。
- [x] `BN-F36` 双击或 Controller 复位。
- [x] `BN-F37` 正确处理父级滚动容器手势竞争。
- [x] `BN-F38` 鼠标滚轮、悬浮十字线和桌面/Web 指针事件。

### 3.5 指标

主图指标：

- [x] `BN-I01` MA。
- [x] `BN-I02` EMA。
- [x] `BN-I03` BOLL。
- [x] `BN-I04` SAR。
- [x] `BN-I05` VWAP。
- [ ] `BN-I06` Ichimoku。

副图指标：

- [x] `BN-I10` VOL。
- [x] `BN-I11` MACD。
- [x] `BN-I12` RSI。
- [x] `BN-I13` KDJ。
- [x] `BN-I14` WR。
- [x] `BN-I15` OBV。
- [x] `BN-I16` ATR。
- [x] `BN-I17` CCI。
- [x] `BN-I18` DMI。
- [x] `BN-I19` ROC。
- [x] `BN-I20` Stoch RSI。

指标公共能力：

- [x] `BN-I30` 参数、颜色、线宽和数据源配置。
- [x] `BN-I31` 同类指标支持多实例。
- [x] `BN-I32` 多副图显示、排序和高度调整。
- [ ] `BN-I33` 阈值线、零轴和区域填充。
- [x] `BN-I34` 指标配置序列化，由宿主决定持久化介质。
- [x] `BN-I35` 指标插件协议，新增指标无需修改核心枚举和 Painter。

### 3.6 绘图工具

- [ ] `BN-D01` 趋势线、水平线、垂直线和射线。
- [ ] `BN-D02` 矩形、平行通道。
- [ ] `BN-D03` 斐波那契回撤。
- [ ] `BN-D04` 文本和价格标记。
- [ ] `BN-D05` OHLC 磁吸。
- [ ] `BN-D06` 选中、移动、控制点、锁定和删除。
- [ ] `BN-D07` 撤销和重做。
- [ ] `BN-D08` 显示/隐藏所有绘图。
- [ ] `BN-D09` JSON 序列化和版本迁移。
- [ ] `BN-D10` 交易对、周期切换后的坐标恢复。

### 3.7 合约和交易叠加

- [ ] `BN-T01` 成交价、标记价格、指数价格数据源标识。
- [ ] `BN-T02` 仓位均价线、强平价格线。
- [ ] `BN-T03` 挂单、止盈、止损价格线。
- [ ] `BN-T04` 买入、卖出成交点。
- [ ] `BN-T05` 资金费率或业务事件时间标记。
- [ ] `BN-T06` 叠加对象点击、拖动和操作按钮回调。

插件仅渲染宿主传入的数据并回传用户操作，不保存密钥、不访问账户、不执行订单。

### 3.8 深度图

- [ ] `BN-O01` 买卖累计深度曲线。
- [ ] `BN-O02` 买一、卖一和价差。
- [ ] `BN-O03` 长按查询价格和累计数量。
- [ ] `BN-O04` 快照与增量事件合并。
- [ ] `BN-O05` update ID 连续性验证和失步通知。
- [ ] `BN-O06` 大档位数据裁剪与采样。

## 4. 数据和公共 API 设计

### 4.1 新 K 线模型

新模型使用不可变对象，至少包含：

```text
symbol
interval
openTime
closeTime
open/high/low/close
baseVolume
quoteVolume
tradeCount
takerBuyBaseVolume
takerBuyQuoteVolume
firstTradeId/lastTradeId
isClosed
timeZone
priceSource
```

约束：

- 时间戳内部统一使用 UTC 毫秒。
- 金额默认使用 `double` 以保持绘制效率，同时允许宿主在进入插件前用 Decimal 完成业务精度处理。
- 实体不保存 MA、MACD 等指标结果。
- 指标结果按数据版本和配置保存在独立缓存中。
- 保留旧 `KLineEntity`，通过 adapter 迁移；2.0 标记 deprecated，至少保留一个次版本周期。

### 4.2 实时合并规则

- 相同 `openTime + interval + symbol + priceSource` 更新最后一根 K 线。
- 更大的 `openTime` 追加新 K 线。
- 已闭合 K 线默认不可被普通事件回写，宿主可显式允许校正事件。
- 重复事件必须幂等。
- 乱序事件在有限窗口内排序，超出窗口通知宿主重新拉取快照。
- 周期切换、交易对切换必须取消旧订阅或通过 generation token 丢弃旧响应。

### 4.3 Controller API

`KChartController` 至少支持：

- 设置或追加历史数据。
- 更新当前 K 线。
- 切换图表类型、周期、主题和指标。
- 滚动到最新、滚动到指定时间。
- 设置缩放级别和复位视口。
- 进入/退出十字线模式。
- 添加、更新、删除绘图或交易叠加对象。
- 输出可见范围、选中数据、加载历史和交互事件。

不得要求业务层通过 `GlobalKey<KChartWidgetState>` 操作内部 State。

## 5. 目标架构

```text
lib/
  m_k_chart.dart                 # 稳定公共导出
  src/
    model/                       # Kline、Depth、Viewport、Overlay
    adapter/                     # 旧实体和 Binance 数据适配
    data/                        # 实时合并、分页状态、快照
    indicator/                   # 指标协议、实现、缓存
    controller/                  # KChartController 与状态
    viewport/                    # 坐标转换、可见区和极值
    render/
      layer/                     # 网格、主图、副图、标记、十字线、绘图
      cache/                     # Path、文本、极值和 Picture 缓存
    interaction/                 # 手势状态机和命中测试
    drawing/                     # 绘图模型、命令和序列化
    theme/                       # 完整主题与样式
    widget/                      # 对外 Widget 和 Overlay UI
```

### 5.1 八大架构问题与整改闭环

以下八项不是普通优化建议，而是 2.0 架构验收项。任何新功能不得绕过这些约束继续堆叠到旧结构。

| ID | 核心问题 | 当前表现 | 整改方向 | 主要任务 | 完成证据 |
| --- | --- | --- | --- | --- | --- |
| `ARCH-01` | 行情模型与指标结果耦合 | `KLineEntity` 混入大量指标字段并依赖 `late`，计算直接修改实体 | 不可变 Kline + 独立 IndicatorSeries/Cache | `P2-*`、`P3-*` | 新渲染链路不读取实体指标字段；快照与增量测试通过 |
| `ARCH-02` | Widget 承担过多运行职责 | 手势、动画、选中、滚动和 UI 状态集中在 `KChartWidgetState` | Controller + Store + InteractionState，Widget 只负责组合和生命周期 | `P1-*`、`P4-*` | 无需 `GlobalKey<State>` 控制；Controller 单测覆盖状态迁移 |
| `ARCH-03` | 绘制阶段存在副作用 | Painter 在 `paint()` 中向 Stream 写选择详情，形成反向状态更新 | Painter 纯函数化；选择事件由交互层产生 | `P1-04`、`P5-06` | paint 无 Stream/Event/状态写入；重复绘制不改变业务状态 |
| `ARCH-04` | 实例状态被全局共享 | `ChartPainter.maxScrollX` 为 static，多图表互相污染 | Viewport/边界状态归属每个 Controller 实例 | `P1-03`、`P4-06` | 双图表并行拖动测试互不影响 |
| `ARCH-05` | 重建与重绘粒度失控 | `shouldRepaint()` 恒 true，手势/动画 `setState()` 导致全图刷新 | 分层 Renderer + 版本比较 + RepaintBoundary/Listenable | `P5-*` | 十字线只重绘 Overlay；主数据层 repaint 次数有断言；帧预算达标 |
| `ARCH-06` | 布局、坐标和初始化存在正确性缺陷 | 网格循环误用像素间距、`mDataLen` 早于 `mPointWidth`、十字线使用全局坐标 | 独立 Layout/Viewport 计算，统一 local 坐标和确定性初始化 | `P4-02`、`P4-03`、`P5-02` | 坐标往返、嵌套布局、网格数量和多尺寸测试通过 |
| `ARCH-07` | 手势竞争机制不合规 | 自定义 recognizer 在 reject 后强制 accept，缩放与拖动可能同时触发 | 遵循 Gesture Arena 的显式交互状态机 | `P4-*` | 父滚动容器、单指、双指、长按互斥测试稳定 |
| `ARCH-08` | 扩展机制和公共 API 封闭 | 指标依赖 enum/switch；双入口导出不一致；样式可变且内部工具外泄 | 注册式指标/Layer 协议，统一入口，不可变配置和兼容适配层 | `P1-05`、`P3-01`、`P6-01`、`P9-04` | 新增测试指标无需修改核心 switch；API diff 与迁移指南通过 |

整改优先级：`ARCH-01`～`ARCH-04` 先建立边界，`ARCH-06`～`ARCH-07` 再统一坐标和输入，最后通过 `ARCH-05` 的分层渲染兑现性能；`ARCH-08` 贯穿所有阶段。

### 5.2 核心原则

核心原则：

- 数据、计算、视口、交互和绘制分离。
- 只重绘发生变化的 Layer。
- 指标和绘图采用注册机制，不采用持续扩大的 enum + switch。
- Widget 配置不可变；运行状态由 Controller 和内部 ValueNotifier/Listenable 管理。
- 不在 `paint()` 中发送 Stream 事件或修改应用状态。

## 6. 性能专项计划

### 6.1 性能预算

以下为 2.0 发布门槛，而非仅供参考：

| 场景 | 数据规模 | 目标 |
| --- | ---: | --- |
| 首次展示 | 2,000 根、1 主图 + 2 副图 | P95 首帧准备时间 ≤ 120 ms |
| 平移/缩放 | 2,000 根、可见约 80～200 根 | 60 Hz 设备 P95 UI/Raster 帧 ≤ 16.7 ms |
| 低端设备降级目标 | 同上 | P95 ≤ 24 ms，无连续 5 个严重掉帧 |
| 十字线移动 | 同上 | 输入到画面 P95 ≤ 32 ms |
| 更新最后一根 K 线 | 10,000 根、6 个指标 | P95 ≤ 8 ms，不允许全量重算 |
| 追加新 K 线 | 10,000 根、6 个指标 | P95 ≤ 12 ms |
| 历史数据合并 | 一次追加 1,000 根 | P95 ≤ 50 ms，可分帧提交 |
| 常驻内存 | 10,000 根、6 个指标 | 增量占用目标 ≤ 35 MB |
| 深度图更新 | 1,000 买档 + 1,000 卖档 | 10 Hz 更新稳定，无持续掉帧 |

性能测试必须使用 profile/release 模式；debug 模式结果不得作为验收依据。

### 6.2 当前已识别热点

- `PERF-H01` `BaseChartPainter.shouldRepaint()` 恒为 `true`。
- `PERF-H02` 手势和闪点动画通过 Widget `setState()` 触发整体重建。
- `PERF-H03` 每次 build 创建新的 `ChartPainter` 和各副图 Renderer。
- `PERF-H04` 可见区主图/副图极值在绘制周期重复遍历。
- `PERF-H05` 绘制阶段频繁创建 `TextPainter`、`TextSpan` 和 `Path`。
- `PERF-H06` 多副图对每根可见 K 线逐 Renderer 分发，指标数量增长时线性放大。
- `PERF-H07` 指标结果直接挂在实体上，无法按配置安全复用缓存。
- `PERF-H08` 高频 debug `print()` 会影响手势测试结果。
- `PERF-H09` 静态 `ChartPainter.maxScrollX` 使多个图表实例共享状态。
- `PERF-H10` 当前绘制与详情 Stream 存在反向状态更新，可能产生额外帧。

### 6.3 优化策略

#### 数据与计算

- [ ] `PERF-01` 指标采用 O(1) 或与周期相关的增量更新，禁止实时 tick 全量重算。
- [ ] `PERF-02` 数据列表使用版本号和不可变视图，避免每帧复制 `List`。
- [ ] `PERF-03` 对分页合并进行去重、预分配和批量提交。
- [ ] `PERF-04` 指标缓存键包含数据版本、指标类型、参数和数据源。
- [ ] `PERF-05` 计算量较大的全量指标支持 `Isolate.run`；少量增量计算留在 UI isolate，避免 isolate 通信成本反而更高。

#### 视口与极值

- [x] `PERF-10` 只遍历可见 K 线，不绘制屏幕外元素。
- [x] `PERF-11` 缓存坐标换算参数和可见起止索引。
- [ ] `PERF-12` 使用滑动窗口、分块 min/max 或 Segment Tree 缓存极值，避免每帧扫描全部副图数据。
- [ ] `PERF-13` 缩放期间使用轻量预览，手势结束后再完成非关键文本布局。

#### 绘制

- [x] `PERF-20` 拆分静态背景、数据、Overlay、十字线和绘图 Layer。
- [ ] `PERF-21` 每个 Layer 独立 `RepaintBoundary`/Listenable，只重绘变化部分。
- [x] `PERF-22` 正确实现 `shouldRepaint()`，比较数据版本、视口版本和样式版本。
- [ ] `PERF-23` 复用 Paint、Path 缓冲区和常用 TextPainter/Paragraph。
- [x] `PERF-24` 网格、固定标签等静态内容缓存为 Picture，尺寸或主题变化时失效。
- [ ] `PERF-25` 依据屏幕密度和缩放级别做绘制抽稀，避免亚像素级无效细节。
- [x] `PERF-26` 禁止无必要 `saveLayer()`，控制渐变、阴影和 clip 的使用。

#### 调度与交互

- [ ] `PERF-30` WebSocket 高频 tick 采用一帧最多提交一次的合并策略。
- [x] `PERF-31` 十字线 Overlay 与主数据层分离，移动时不重绘全部蜡烛。
- [ ] `PERF-32` 手势状态使用专用 Listenable，不刷新外围业务 Widget。
- [ ] `PERF-33` 文本详情由选中索引变化触发，不从 `paint()` 内发送事件。
- [ ] `PERF-34` 后台、不可见和 Offstage 状态暂停动画与非必要刷新。

### 6.4 性能基准工具

- Flutter DevTools Performance、CPU Profiler、Memory。
- `integration_test` + `FrameTimingSummarizer` 记录 UI/Raster P50、P95、P99。
- `benchmark_harness` 或 Dart benchmark 测试指标与数据合并。
- Golden 测试确认缓存和分层优化没有造成视觉回归。
- Android 至少覆盖一台中低端真机；iOS 至少覆盖一台 60 Hz 设备；Web 覆盖 CanvasKit。

每个 Phase 合并前保存基准 JSON，后续阶段不得比上一个已接受基线退化超过 10%；超过时必须说明原因并获得确认。

## 7. 重新规划后的分阶段实施计划

### 7.1 依赖关系

```text
Phase 0 基线
    ↓
Phase 1 架构契约与状态骨架
    ├──→ Phase 2 数据模型与 Store ──→ Phase 3 指标引擎 ──┐
    └──→ Phase 4 视口、布局与手势 ────────────────────────┤
                                                         ↓
                                              Phase 5 分层渲染
                                                         ↓
                                              Phase 6 币安核心体验
                                                         ↓
                                      Phase 7/8 扩展能力 → Phase 9 发布
```

Phase 3 和 Phase 4 可在 Phase 1 契约冻结、Phase 2 核心模型稳定后并行。Phase 5 不得在数据、指标、视口和交互输入接口未冻结前启动主体迁移。

### Phase 0：冻结基线与测量，2～3 人日（已完成）

- [x] `P0-01` 保存当前公共 API 清单和 Demo 截图。
- [x] `P0-02` 建立 100/2,000/10,000 根标准数据集。
- [x] `P0-03` 为现有 MA、EMA、BOLL、SAR、MACD、KDJ、RSI、WR、VOL、OBV 建立结果基线。
- [x] `P0-04` 建立拖动、缩放、十字线的 profile 性能基线，并记录旧动画生命周期对 FrameTiming 的限制。
- [x] `P0-05` 完成 Android/iOS/Web 构建矩阵；不可用环境明确记录原因。
- [x] `P0-06` 输出 2.0 API 草案和 deprecated 清单。
- [x] `P0-07` 冻结 `ARCH-01`～`ARCH-08` 问题清单、代码证据和验收映射。

阶段门禁：有可重复的计算/绘制基线、视觉基线和 API 基线。禁止在门禁完成前改写生产 Painter。

### Phase 1：架构契约与状态骨架，4～6 人日（已完成）

- [x] `P1-01` 建立 `src/model|data|indicator|drawing|controller|viewport|render|interaction|theme|widget|adapter` 模块边界和依赖规则。
- [x] `P1-02` 定义不可变 `KChartState`、StateSlice 和版本号协议，区分数据、视口、选择、布局和主题变化。
- [x] `P1-03` 实现最小 `KChartController` 生命周期与每实例状态容器，禁止 static 运行状态。
- [x] `P1-04` 定义单向事件流：输入/数据 → Controller/Store → State → Renderer；Painter 必须无副作用。
- [x] `P1-05` 统一 `m_k_chart.dart` 公共入口，建立 public API allowlist、deprecated 和兼容导出策略。
- [x] `P1-06` 建立架构守护测试：依赖方向、双实例隔离、dispose 和 API surface。

阶段门禁：关闭 `ARCH-02`、`ARCH-03`、`ARCH-04` 的结构风险；Controller 骨架可独立单测；旧组件行为不变。

### Phase 2：不可变数据模型与实时 Store，5～7 人日（已完成）

- [x] `P2-01` 实现不可变 Kline、Interval、PriceSource 和数据版本。
- [x] `P2-02` 实现旧 `KLineEntity` 双向 adapter，旧 API 继续可用。
- [x] `P2-03` 实现 replace/prepend/append/update 和只读数据视图。
- [x] `P2-04` 实现重复、乱序、闭合校正和 generation token 规则。
- [x] `P2-05` 实现 Binance REST/WebSocket 示例 adapter，但核心包不依赖 Binance API。
- [x] `P2-06` 完成 10,000 根数据合并 benchmark、内存基线和异常输入测试。

阶段门禁：`ARCH-01` 的行情侧整改完成；事件幂等；旧 Demo 可经 adapter 运行；历史合并满足 50 ms 预算。

### Phase 3：独立指标引擎，6～8 人日（已完成）

- [x] `P3-01` 定义注册式 Indicator、IndicatorConfig、IndicatorSeries 和 RendererDescriptor 协议。
- [x] `P3-02` 实现以数据版本、参数和数据源为键的缓存及增量更新协议。
- [x] `P3-03` 迁移现有指标并与 Phase 0 快照对照。
- [x] `P3-04` 增加 VWAP、ATR、CCI、DMI、ROC、Stoch RSI。
- [x] `P3-05` 支持同类多实例、数据不足状态、NaN/Infinity 隔离。
- [x] `P3-06` 删除新链路对实体 `late` 指标字段及核心 enum/switch 的依赖。

阶段门禁：关闭 `ARCH-01` 的指标侧风险和 `ARCH-08` 的指标扩展风险；最后一根更新 P95 ≤ 8 ms；注册一个测试指标无需修改核心代码。

### Phase 4：视口、布局与手势状态机，6～8 人日（已完成）

- [x] `P4-01` 实现每实例 ChartViewport、可见范围和缩放/滚动边界。
- [x] `P4-02` 实现数据坐标、图表 local 坐标、价格和时间的双向转换。
- [x] `P4-03` 实现确定性 LayoutModel，修复网格数量、初始化顺序、多副图尺寸和嵌套偏移问题。
- [x] `P4-04` 实现遵循 Gesture Arena 的单指平移、焦点缩放、长按十字线互斥状态机。
- [x] `P4-05` 实现惯性、磁吸、回到最新、指定时间定位和历史分页状态。
- [x] `P4-06` 实现双图表隔离、父滚动容器、横屏、鼠标和触控板策略。
- [x] `P4-07` 完成坐标往返、手势竞争和输入延迟自动化测试。

阶段门禁：关闭 `ARCH-06`、`ARCH-07`，并验证 `ARCH-04`；不得强制接受已被 Gesture Arena 拒绝的手势。

### Phase 5：纯函数分层渲染与性能整改，8～12 人日

- [x] `P5-01` 定义 RenderSnapshot 和 Layer 协议，Renderer 只读状态且无副作用。
- [x] `P5-02` 实现网格、主图、副图、轴标签、标记、十字线和绘图独立 Layer。
- [x] `P5-03` 实现可见区裁剪、极值缓存、文本/Path/Picture 缓存。
- [x] `P5-04` 用数据、视口、样式和 Layer 版本正确实现重绘判定。
- [x] `P5-05` 迁移蜡烛、分时、面积图及现有指标绘制。
- [x] `P5-06` 移除 paint 内 Stream 写入、全局 maxScrollX 和 Widget 全量 setState 链路。
- [x] `P5-07` 建立多尺寸、多主题、多副图 Golden 和 repaint 计数测试。
- [x] `P5-08` 完成 2,000 根 + 2 副图的 Profile 帧性能、内存与 GC 门禁。

阶段门禁：关闭 `ARCH-03`、`ARCH-05`；十字线只重绘 Overlay；Golden 通过；新 Renderer 达到第 6 节性能预算。旧组件可选择 legacy 或 v2 Renderer。

### Phase 6：币安式核心体验与主题，5～7 人日

- [x] `P6-01` 完整不可变 KChartTheme、样式注册和 ChartColors 兼容 adapter。
- [x] `P6-02` 实现实心/空心蜡烛、Heikin-Ashi、最新价、倒计时及高低点标记。
- [x] `P6-03` 实现周期和图表类型工具栏示例。
- [x] `P6-04` 实现指标选择、排序、参数面板和多副图高度配置。
- [x] `P6-05` 实现行情摘要、OHLC 信息栏、横屏/全屏 Demo。
- [x] `P6-06` 实现用户配置序列化接口和兼容迁移。

阶段门禁：`ARCH-01`～`ARCH-08` 全部有通过证据；Phase 0～6 可发布 `2.0.0-alpha`，具备完整基础交易图表体验。

### Phase 7：绘图工具，8～12 人日

- [x] `P7-01` 绘图对象、锚点、样式和版本化 JSON。
- [x] `P7-02` 绘图命中测试和控制点。
- [ ] `P7-03` 实现 BN-D01～BN-D04 工具。
- [ ] `P7-04` 实现磁吸、移动、锁定和删除。
- [ ] `P7-05` 实现 Command 模式撤销/重做。
- [ ] `P7-06` 实现跨周期恢复策略。
- [ ] `P7-07` 完成绘图 Golden 和序列化兼容测试。

阶段门禁：缩放、分页、旋转屏幕后锚点稳定；绘图 Overlay 不影响基础帧预算超过 10%。

### Phase 8：交易叠加与深度图，5～8 人日

- [ ] `P8-01` 通用 PriceLine、Marker 和 EventOverlay。
- [ ] `P8-02` 仓位、强平、挂单、止盈止损示例。
- [ ] `P8-03` 交易叠加点击和拖动回调。
- [ ] `P8-04` 重构深度模型与累计曲线。
- [ ] `P8-05` 实现深度快照/增量合并和失步事件。
- [ ] `P8-06` 深度高频更新性能测试。

阶段门禁：插件不耦合交易 SDK；深度 10 Hz 更新达标；断流和失步可恢复。

### Phase 9：发布质量，5～7 人日

- [ ] `P9-01` 全量 unit/widget/golden/integration/benchmark。
- [ ] `P9-02` Android/iOS/Web profile 和 release 构建。
- [ ] `P9-03` 无障碍、RTL、时区和国际化检查。
- [ ] `P9-04` API diff、迁移指南、架构决策记录和完整 Example。
- [ ] `P9-05` 发布 `dev → alpha → beta → rc → stable`。
- [ ] `P9-06` 每个预发布版本至少保留一轮真实项目接入反馈。

## 8. 测试与质量门禁

### 8.1 单元测试

- K 线解析、合并、乱序和去重。
- 每个指标的固定输入/输出和边界数据。
- 坐标转换、可见索引、缩放边界和极值。
- 绘图序列化和版本迁移。
- 深度快照和增量事件序列。

### 8.2 Widget 与 Golden

- 空数据、单条数据、数据不足和异常值。
- 明暗主题、不同涨跌色。
- 320/375/430 宽度及横屏。
- 蜡烛、分时、Heikin-Ashi 和多副图。
- 十字线、最新价、订单线和绘图对象。

### 8.3 集成与性能

- 真实手势序列：缩放、拖动、十字线、分页。
- 1～20 Hz 模拟实时 tick。
- 10,000 根数据和多个指标。
- 前后台切换、路由切换和多图表实例。
- 内存泄漏、Controller/Animation/Stream dispose。

### 8.4 合并门禁

每个功能 PR 必须满足：

- `flutter analyze` 无新增 error/warning。
- 单元和 Widget 测试通过。
- 涉及视觉变化时更新并审核 Golden。
- 涉及渲染、数据或指标时提供性能前后对比。
- 公共 API 变化同步更新本文、CHANGELOG 和迁移指南。
- 不得无说明突破性能预算或破坏旧 API。

## 9. 风险与控制措施

| 风险 | 概率 | 影响 | 控制措施 |
| --- | --- | --- | --- |
| 重构导致现有接入方无法升级 | 中 | 高 | adapter、deprecated 周期、legacy renderer |
| 指标公式与 Binance/TradingView 口径不同 | 中 | 高 | 固定标准数据、记录公式和默认参数 |
| 功能持续扩张拖延 2.0 | 高 | 高 | Phase 0～6 先发布，绘图和交易叠加后置 |
| 高频行情造成掉帧 | 高 | 高 | 帧合并、增量指标、分层重绘、性能门禁 |
| 多副图导致主图可用空间过小 | 中 | 中 | 最小高度、滚动或限制同时展示数量 |
| Web CanvasKit 与移动端视觉差异 | 中 | 中 | 跨平台 Golden 与字体策略 |
| 绘图跨周期恢复不一致 | 中 | 高 | 用时间+价格作为锚点，索引仅作运行时缓存 |
| 大量对象增加 GC | 中 | 高 | Paint/Path/Text 缓存、对象池仅在基准证明有效后使用 |
| isolate 优化反而增加延迟 | 中 | 中 | 设置任务阈值，小任务留 UI isolate |
| Binance 产品界面变化 | 中 | 中 | 对标稳定交互模型，不绑定具体页面布局 |

## 10. 明确不做

2.0 范围明确排除：

- Binance 账户登录、API Key 管理和下单。
- 交易策略建议或金融决策。
- Pine Script 解释器和 TradingView 插件兼容。
- 云端保存、提醒推送和社交分享服务。
- 完整回测系统。
- 对 Binance UI、图标或品牌素材的直接复制。

上述能力可以由宿主应用或后续独立包实现。

## 11. 版本与交付建议

| 版本 | 包含阶段 | 交付目标 |
| --- | --- | --- |
| `1.1.x` | Phase 0～3 的兼容部分 | 稳定数据与指标，保留当前 UI |
| `2.0.0-alpha` | Phase 0～6 | 八项架构整改闭环，新内核和币安式核心 K 线 |
| `2.0.0-beta` | Phase 7 | 绘图工具可用 |
| `2.0.0-rc` | Phase 8～9 | 交易叠加、深度和跨平台验收 |
| `2.0.0` | 全部门禁通过 | 稳定公共 API |

## 12. 后续跟进方式

后续每次开发从本文选择任务编号，例如 `P1-01`。开始和完成时更新复选框，并在下方增加记录：

```text
日期：YYYY-MM-DD
任务：P1-01
状态：进行中 / 已完成 / 阻塞
变更：关联文件或提交
验证：测试、Golden、性能结果
决策：API 或范围调整
```

若任务被阻塞，不跳过依赖门禁；先在文档中记录原因、备选方案和最终决策。

### 2026-08-24 / P1-01

- 状态：已完成。
- 变更：新增 11 个内部模块入口、模块职责与依赖矩阵、自动化依赖守卫测试。
- 验证：`flutter test test/architecture/module_dependency_test.dart`、`dart analyze lib/src test/architecture/module_dependency_test.dart` 均通过。
- 决策：`adapter` 是新架构中唯一允许依赖 legacy 实现的模块；`drawing` 独立于 Renderer，避免绘图模型再次与手势和画布实现耦合。
- 后续：进入 `P1-02`，在状态协议冻结前不迁移生产 Renderer。

### 2026-08-24 / P1-02

- 状态：已完成。
- 变更：新增不可变 `KChartState`、五类 `StateSlice`、切片版本向量和状态版本协议文档。
- 验证：状态协议 6 组单测、模块依赖守卫和定向静态检查通过。
- 决策：一次非空事务只增加一次总修订号；仅实际变化切片增加版本；空事务保持快照实例不变。
- 性能：后续 Layer 只比较其依赖的切片版本，不复制数据列表，也不使用总修订号触发无差别重绘。
- 后续：进入 `P1-03`，实现每图表实例独立的最小 Controller 生命周期。

### 2026-08-24 / P1-03

- 状态：已完成。
- 变更：新增每实例 `KChartController`、只读 `ValueListenable<KChartState>`、原子通知和幂等销毁契约。
- 验证：5 组 Controller 单测覆盖单事务通知、空事务、双实例隔离、初始快照和 dispose；模块守卫与静态检查通过。
- 决策：Controller 不保存 static 运行状态；销毁后事务抛出 `StateError`；外部注入与 Widget 内建 Controller 的所有权在 P1-05 Widget API 中落实。
- 后续：进入 `P1-04`，以类型化事件替换临时内部提交桥，并冻结 Painter 只读边界。

### 2026-08-24 / P1-04

- 状态：已完成。
- 变更：新增五类 `KChartEvent`、Controller 单事件/批量事件入口、单向事件流文档和 Renderer 纯度守卫。
- 验证：类型化事件映射、复合事件单事务、Controller 生命周期、模块依赖与 Renderer 纯度测试通过；定向静态检查无问题。
- 决策：复合输入先合并变化切片，再发布一次快照；新 Renderer 禁止 Stream 写入、Controller dispatch、`notifyListeners` 和 `setState`。
- 边界：legacy Painter 的已知 Stream 副作用保留至 `P5-06` 迁移，本任务阻止新 Renderer 继续引入同类问题。
- 后续：进入 `P1-05`，冻结公共入口、allowlist 与兼容导出策略。

### 2026-08-24 / P1-05

- 状态：已完成。
- 变更：冻结正式入口的导出文件与公共符号 allowlist；旧 `flutter_k_chart.dart` 改为 deprecated 单向转发；归档 2.0 API 准入和兼容策略。
- 验证：正式入口、旧入口转发、23 个公共声明快照测试和定向静态检查通过。
- 决策：当前 `lib/src` 不提前公开；只有替代 API 已可用时才给 legacy 符号添加代码级 deprecated，避免产生无法消除的迁移警告。
- 后续：进入 `P1-06`，汇总依赖、实例隔离、dispose、Renderer 纯度和 API surface 门禁，完成 Phase 1 退出审查。

### 2026-08-24 / P1-06

- 状态：已完成，Phase 1 退出审查通过。
- 变更：新增运行状态 static 守卫和 Phase 1 退出审查文件，汇总依赖、版本、事件、实例、生命周期、纯渲染与 API 证据。
- 验证：架构/Controller 定向测试 20 项通过；全量测试、定向静态检查和 diff 检查通过。
- 决策：新链路不得声明可变 static 运行字段；Phase 1 关闭结构契约风险，legacy `maxScrollX` 和 paint Stream 副作用仍分别由 P4/P5 实际移除。
- 性能：冻结空事务零通知、复合事件单通知、切片版本重绘和禁止状态列表复制等结构保证。
- 后续：进入 `P2-01`，实现不可变 Kline、Interval、PriceSource 和数据版本；继续禁止提前迁移生产 Painter。

### 2026-08-24 / P2-01

- 状态：已完成。
- 变更：新增不可变 `Kline`、固定/自然月 `KlineInterval`、`KlinePriceSource` 和单调 `KlineDataVersion`，归档模型契约。
- 验证：15 组模型测试覆盖字段、UTC、身份、复制、相等、周期、版本和异常输入；架构守卫与定向静态检查通过。
- 决策：内部时间统一 UTC 毫秒；月线使用自然月；枚举源码名采用 `indexPrice`、传输代码保持 `index`；构造校验在 release 同样执行。
- 性能：Kline 不保存指标字段；热路径依靠身份和数据版本，不通过复制大列表比较状态。
- 后续：进入 `P2-02`，建立 legacy `KLineEntity` 双向 adapter 与精度/缺省映射规则。

### 2026-08-24 / P2-02

- 状态：已完成。
- 变更：新增 `KLineEntityAdapter`、legacy 秒/毫秒时间策略、固定周期 closeTime 推导和有损字段说明。
- 验证：7 组 adapter 测试覆盖共有字段正反映射、自然月、毫秒输入、往返、精度拒绝和异常 legacy 值；静态检查与架构守卫通过。
- 决策：legacy 默认时间单位保持现状的秒；自然月必须显式传 closeTime；反向秒转换不能整除 1000 时抛错，不静默截断。
- 边界：adapter 是唯一允许依赖 `KLineEntity` 的新模块；当前仍不从正式入口导出，待 Store 和新用户 API 冻结后再评审。
- 后续：进入 `P2-03`，实现版本化 KlineStore 的 replace/prepend/append/update 和只读视图。

### 2026-08-24 / P2-03

- 状态：已完成。
- 变更：新增版本化 `KlineStore`、不可变 `KlineSnapshot`、replace/prepend/append/update 和二分查找更新。
- 验证：11 组 Store 测试覆盖只读视图、版本、无操作、旧快照稳定、批量边界、系列隔离和异常输入；静态检查与架构守卫通过。
- 决策：Store 是严格有序的底层提交器，不在本层静默排序/去重；重复、乱序和闭合校正由 P2-04 策略层处理。
- 性能：读路径零复制；批量合并预分配一次；update O(log n) 定位并只复制一次；空操作不创建快照或增加版本。
- 后续：进入 `P2-04`，实现幂等事件、有限乱序窗口、闭合校正授权与 generation token。

### 2026-08-24 / P2-04

- 状态：已完成。
- 变更：新增 `KlineRealtimeCoordinator`、generation token、有限乱序窗口、闭合校正授权和结构化合并结果。
- 验证：11 组策略测试覆盖追加、更新、duplicate、闭合拒绝/授权、窗口插入、超窗重拉、旧 token、跨序列和失败原子性；静态检查通过。
- 决策：所有忽略/拒绝路径保持快照和版本不变；超窗返回 `requiresReload`；替换快照成功后才推进 generation。
- 性能：实时定位使用二分查找；duplicate/stale/rejected 零快照分配；窗口插入只预分配一次最终列表。
- 后续：进入 `P2-05`，实现无网络依赖的 Binance REST/WebSocket payload adapter 和 Example 接入示例。

### 2026-08-24 / P2-05

- 状态：已完成。
- 变更：新增纯 `BinanceKlinePayloadAdapter`、REST 12 元组、raw/combined WebSocket、16 个周期和毫秒/微秒映射。
- 验证：11 组 Binance 解析测试覆盖批量闭合判断、时区、价格源、官方周期、异常字段和无网络依赖；静态检查通过。
- 决策：核心只接受已解码 Map/List；HTTP/WebSocket/JSON/retry/heartbeat 归宿主；异常 OHLC 不自动修正。
- 依据：2026-08-24 复核 Binance 官方 Spot REST 与 WebSocket Streams 文档。
- 后续：进入 `P2-06`，执行 10,000 根合并耗时、内存、异常输入与 Phase 2 退出门禁。

### 2026-08-24 / P2-06

- 状态：已完成，Phase 2 退出审查通过。
- 变更：新增 10,000 根 opt-in Store benchmark、RSS 基线、v2→legacy Demo 桥接测试和退出审查。
- 性能：replace P95 1,726 μs；prepend 1,000→9,000 P95 955 μs；append P95 546 μs；last update P95 656 μs；RSS 增量约 1.63 MiB。
- 验证：历史合并 P95 ≤ 50 ms 门禁通过；异常模型/Store/实时/Binance 输入均有拒绝测试；legacy Widget 经 adapter 构建通过。
- 决策：行情侧 `ARCH-01` 已关闭；指标侧由 Phase 3 完成；RSS 是 Host Debug 粗测，加入多指标后必须复测综合内存。
- 后续：进入 `P3-01`，定义注册式 Indicator/Config/Series/RendererDescriptor 协议。

### 2026-08-24 / P3-01

- 状态：已完成，指标基础协议冻结。
- 变更：新增实例级 `IndicatorRegistry`、不可变 Config/Series/Result、版本化输入边界和 RendererDescriptor；`KlineSnapshot` 零复制接入指标输入协议。
- 验证：8 组协议测试覆盖自定义注册、同定义多实例、不可变配置、注册冲突、结果身份/版本/长度/Series 校验和非有限值拒绝；模块依赖守卫通过。
- 决策：指标层只依赖 model；RendererDescriptor 不携带 Canvas/Color；计算结果独立存储，不回写 Kline；新协议暂不从正式入口导出。
- 性能：行情输入复用不可变 snapshot，不复制 10,000 根 Kline；缓存和最后一根增量计算由 P3-02 落地并单独建立 P95 基线。
- 边界：未修改 legacy 公式和生产 Painter；缓存、增量失败恢复、legacy 迁移不在本任务范围。
- 后续：进入 `P3-02`，实现以数据版本、配置和价格源为键的缓存与增量更新协议。

### 2026-08-25 / P3-02

- 状态：已完成，指标缓存与增量协议冻结。
- 变更：新增实例级有界 LRU `IndicatorCache`、显式缓存键、结构化 `IndicatorDataChange` 和可选 `IncrementalIndicatorDefinition`；注册表统一校验全量与增量结果。
- 验证：缓存测试覆盖精确命中、append、末项 update、prepend 全量回退、配置/价格源/Store 隔离、LRU 淘汰和清空；原 P3-01 协议测试继续通过。
- 性能：10,000 根 Host Debug：全量 P95 582 μs，最后一根 Store+指标增量 P95 1,202 μs，精确缓存命中 P95 5 μs；低于 8 ms 门禁。
- 决策：缓存键包含完整配置、数据版本、价格源和快照身份；变更范围通过稳定前后缀推导；定义必须显式声明支持的变更类型，否则全量回退；错误增量结果不静默吞掉。
- 内存：缓存默认最多 32 项并按 LRU 淘汰；6 个单序列指标 Host Debug RSS 粗测增量 4 KiB，仅作本机观测，Phase 3/5 仍需用真实多序列指标复测综合内存。
- 边界：未迁移 legacy 公式、未修改生产 Painter、未从正式包入口导出新协议。
- 后续：进入 `P3-03`，迁移现有 10 类指标并与 Phase 0 快照对照。

### 2026-08-25 / P3-03

- 状态：已完成，10 类 legacy 指标已迁移到独立引擎。
- 变更：新增 MA、EMA、BOLL、SAR、VOL、MACD、KDJ、RSI、WR、OBV 注册定义及统一注册入口；递归指标状态保存在 Renderer 不可见的不可变 `IndicatorComputationState` 中。
- 兼容：Phase 0 索引 29/59/99 的 24 条序列全部在 `1e-9` 容差内一致；保留 WR 实际 15 根窗口等历史口径；数据不足由旧占位零改为协议规定的 `null`。
- 增量：十类定义均支持 append 和无稳定后缀的 update；写时复制序列共享未变前缀，小变更稀疏保存并在 512 项后自动展平，避免每 tick 复制 10,000 点。
- 性能：10,000 根 Host Debug，十指标全量 P95 10,413 μs；Store + 十指标末项增量合计 P95 1,942 μs，各单指标 P95 465～2,720 μs，均低于 8 ms 门禁。
- 验证：注册数量、历史公式对照、不足状态、append/update 等价、参数拒绝、状态长度、写时复制不可变性和 520 次展平路径均通过。
- 边界：未修改 legacy `DataUtil` 和生产 Painter；新定义仍仅从内部 indicator 模块导出。
- 后续：进入 `P3-04`，新增 VWAP、ATR、CCI、DMI、ROC 和 Stoch RSI。

### 2026-08-25 / P3-04

- 状态：已完成，六类新增指标已接入注册式引擎。
- 变更：新增 VWAP、ATR、CCI、DMI（+DI/-DI/ADX）、ROC、Stoch RSI（K/D）定义；增加一次注册全部 16 个内置指标的入口。
- 口径：VWAP 使用累计典型价成交量加权；ATR 为 Wilder RMA(14)；CCI 为 20/0.015；DMI 为 14+14 Wilder；ROC 为 12 周期百分比；Stoch RSI 为 14/14/3/3。
- 边界：预热不足返回 `null`；成交量或指标分母为零时输出 `null` 或有限值 0，不产生 NaN/Infinity；周期和常数参数拒绝零、负数及非整数周期。
- 增量：六类定义均支持 append 和末项 update；VWAP、DMI、Stoch RSI 的递归中间量进入 Renderer 不可见状态，结果不回写 Kline。
- 性能：10,000 根 Host Debug，六指标全量 P95 10,516 μs；Store + 六指标末项增量合计 P95 1,689 μs；单指标 P95 377～853 μs，全部低于 8 ms 门禁。
- 验证：解析性平盘/上涨序列、VWAP 手算、预热边界、注册 6/16 项、append/update 全量等价、参数拒绝和 opt-in benchmark 通过。
- 边界：本任务只提供指标计算与描述符，BN-I05/I16～I20 的最终产品勾选待 Phase 5/6 Renderer 和配置 UI 接入后完成。
- 后续：进入 `P3-05`，完成多实例、不足状态和非有限值故障隔离门禁。

### 2026-08-25 / P3-05

- 状态：已完成，多实例与故障隔离门禁通过。
- 变更：新增实例级 `IndicatorEngine`，统一持有 Registry/Cache；`resolveAll` 返回不可变结果与 failure 映射，单个未知定义、算法异常或非法输出不再中断其他实例。
- 多实例：同一定义可按不同 instanceId、参数和样式语义同时计算并独立命中缓存；批次内重复 instanceId 在任何计算前原子拒绝。
- 隔离：失败实例不进入缓存且可在后续批次重试；两个 Engine 的注册表、缓存和 failure 完全隔离；批量结果与 failure 映射不可写。
- 有限值：16 个内置指标在 1 根短数据及 100 根平盘、零成交量数据上逐项检查可绘制 Series 和私有状态，只允许有限值或 `null`；注入 NaN、主动抛错和未知定义均被实例级隔离。
- 性能：10,000 根、MA/MACD/RSI/VOL/DMI/Stoch RSI 六实例，Host Debug RSS 粗测增量 6,574,080 bytes（约 6.27 MiB，目标 ≤35 MiB）；末项批量更新 P95 2,776 μs（目标 ≤8 ms）。
- 验证：多实例缓存、失败重试、短数据/平盘有限值、重复 ID 原子性、双 Engine 隔离及 opt-in 性能/RSS benchmark 通过。
- 边界：RSS 为进程级粗测，不代表精确 retained size；Phase 5 仍需在 Profile 场景复测完整 Kline + 6 指标 + Renderer 内存。
- 后续：进入 `P3-06`，增加新链路实体字段/enum/switch 守卫并执行 Phase 3 退出审查。

### 2026-08-25 / P3-06

- 状态：已完成，Phase 3 退出审查通过。
- 变更：新增指标独立性架构守卫，扫描整个 v2 indicator 模块及 Kline 模型，阻止 legacy 实体/计算器、Flutter、旧指标枚举、switch 分发、实体指标字段和输入回写重新进入新链路。
- ARCH-01：行情侧由 Phase 2 关闭；指标侧确认所有结果和递归状态独立于 Kline，公式只读输入，完整关闭该架构风险的新链路部分。
- ARCH-08：指标扩展侧确认 16 个内置定义和自定义测试定义均通过注册接入，无需修改核心 enum/switch；公共 API、Layer 和迁移指南部分仍按 Phase 6/9 推进。
- 门禁：Phase 3 六项任务全部完成；历史 24 序列兼容、16 指标有限值、故障隔离、多实例、增量等价、10,000 根性能与 6 实例 RSS 均通过。
- 边界：生产 Painter、legacy DataUtil、正式包入口和 Demo 均未改动；新指标仍需 Phase 5 Renderer 与 Phase 6 配置 UI 才能目测。
- 证据：`docs/architecture/PHASE_3_EXIT_REVIEW.md`。
- 后续：进入 `P4-01`，实现每实例 ChartViewport 和边界。

### 2026-08-25 / P4-01

- 状态：已完成，每实例 Viewport 和边界协议已冻结。
- 变更：新增不可变 `ChartViewport` 与半开区间 `VisibleIndexRange`；Viewport 以数据槽保存距最新端的滚动量，并按数据量、逻辑宽度和单项宽度统一计算可见范围与最大滚动边界。
- 边界：缩放自动约束到 min/max item extent；滚动自动约束到最新/最旧端；宽度、数据量和缩放变化都会重新归一化，不足一屏不制造可滚动空白。
- 状态：`KChartState` 开始持有 Viewport 载荷；`ChartViewportChanged` 支持批次最后值原子提交，相同载荷不增加 revision、不通知监听器。
- ARCH-04：新 Viewport 无 static 运行状态，双 Controller 分别持有独立快照；legacy `ChartPainter.maxScrollX` 暂保留到 P5-06，不进入新链路。
- 验证：覆盖最新/最旧/分数槽可见范围、缩放上下限、尺寸/数据量重算、非法输入、结构相等、Controller 空事务/批次提交、双实例隔离和模块依赖。
- 边界：本任务不实现 data/local/时间/价格转换、焦点缩放或历史分页锚定，不修改生产 Painter 和 Demo。
- 证据：`docs/architecture/KLINE_V2_VIEWPORT_PROTOCOL.md`。
- 后续：进入 `P4-02`，实现坐标双向转换和往返测试。

### 2026-08-25 / P4-02

- 状态：已完成，data/local/时间/价格坐标协议已冻结。
- X 轴：新增不可变 `ChartXTransform`；第 i 根数据占 `[i, i+1]` 且中心为 `i+0.5`，结合 Viewport 的 visible left 和 item extent 完成连续 data/local 双向转换。
- 时间：以稳定 `VersionedKlineData` 的实际 openTime 建立严格有序时间轴；二分查找后按相邻 Kline 插值，不假设固定周期，支持缺口及 calendar interval；端点外约束到首尾。
- 价格：新增 `ChartPriceTransform`，统一 chart-local、Y 向下为正的 panel 价格映射；最高价对应 top、最低价对应 bottom，范围外保持线性外推供 Renderer 裁剪。
- 正确性：data/local 测试往返误差 ≤1e-12，time/local ≤1 ms，price/local ≤1e-9；覆盖槽边界选中、端点约束、空数据、乱序、长度不匹配、退化范围和非有限值。
- ARCH-06：新增 viewport 独立性守卫，禁止 Flutter/dart:ui、globalToLocal、RenderBox、legacy Painter/Widget 进入坐标模块；嵌套图表只消费自身 local 坐标。
- 边界：平盘价格 padding、panel top/bottom、网格与多副图布局属于 P4-03；焦点缩放和时间定位属于 P4-04/P4-05；生产 Painter 和 Demo 未修改。
- 证据：`docs/architecture/KLINE_V2_COORDINATE_PROTOCOL.md`。
- 后续：进入 `P4-03`，实现确定性 LayoutModel、网格和多副图尺寸。

### 2026-08-25 / P4-03

- 状态：已完成，确定性 LayoutModel、网格和多副图尺寸协议已冻结。
- 布局：新增不可变 `ChartLayoutModel`、`ChartPanelSpec/Layout` 和 chart-local `ChartLayoutRect`；显式计算 drawing/time-axis/main/secondary 边界，不读取 Widget、屏幕坐标或 Painter 状态。
- 多副图：主图和副图按“正最小高度 + 剩余空间权重”分配，保持输入顺序和稳定 ID；尺寸不足直接拒绝，最后一个 panel 钉住绘制底边消除累计误差。
- 网格：columns/rows 统一表示区间数，分别精确输出 N+1 个 X/Y 坐标且集合不可写，关闭 legacy 按 `columnSpace` 像素值循环导致的数量错误。
- 状态：`KChartState` 开始持有可空 LayoutModel；Controller 在同一事务把 drawing width 应用到 Viewport，尺寸变化精确增加 layout/viewport 切片，相同结构不通知。
- ARCH-06：多尺寸 inset、嵌套 chart-local 边界、单/双副图、网格端点与最小高度均有确定性测试；生产 Painter 和 Demo 未修改。
- 边界：极值/平盘价格 padding 属于后续 Renderer 输入；Gesture Arena、横屏和父滚动实测属于 P4-04/P4-06。
- 证据：`docs/architecture/KLINE_V2_LAYOUT_PROTOCOL.md`。
- 后续：进入 `P4-04`，实现合规的交互状态机。

### 2026-08-25 / P4-04

- 状态：已完成，单指平移、双指焦点缩放和长按十字线互斥协议已冻结。
- 状态机：新增每实例 `ChartInteractionMachine`，仅包含 idle/panning/scaling/crosshair 四个互斥状态；冲突 begin 不抢占 winner，cancel/reject 只回到 idle。
- Arena：新增内部 `ChartGestureRegion`，使用标准 Scale + LongPress recognizer；单指/双指由 pointerCount 区分，不覆写 rejectGesture，也不在拒绝后调用 acceptGesture。
- 导航：pan 把 local X delta 转为数据槽滚动；scale 冻结焦点数据位置并同时处理 scale/focal 移动，继续复用 Viewport 的缩放和滚动边界。
- 选择：长按全程使用 localPosition；`ChartCrosshairState` 进入 KChartState selection 切片，Controller 通过 sealed interaction intent 映射类型化事件，不依赖 Painter Stream。
- 验证：纯状态机覆盖边界/锚定/互斥/取消/非法输入；Widget 测试覆盖单指只 pan、双指只 scale、静止长按只 crosshair；架构守卫禁止新链路 reject→accept 和 Interaction Flutter/Controller 依赖。
- ARCH-07：图表内部三类手势竞争已关闭；父滚动、鼠标和触控板策略仍由 P4-06 验证后完整关闭。
- 边界：惯性、磁吸、定位和历史分页属于 P4-05；production KChartWidget/Painter 未修改。
- 证据：`docs/architecture/KLINE_V2_INTERACTION_PROTOCOL.md`。
- 后续：进入 `P4-05`，实现导航与分页状态。

### 2026-08-25 / P4-05

- 状态：已完成，惯性、OHLC 磁吸、确定性定位和历史分页协议已冻结。
- 惯性：新增每实例 `ChartNavigationMachine`，按 pan end local X 速度和帧增量执行恒减速积分；弱速度、边界外向速度、新手势和 dispose 均正确停止。
- 导航：新增 `toLatest`、不规则 openTime 定位与 alignment、prepend 后保持 local X 的锚定操作，全部复用 Viewport/X Transform 边界。
- 磁吸：新增 `ChartOhlcSnapper`，选择数据槽中心及最近 open/high/low/close，并将 index/field/price/local 坐标写入 selection 状态。
- 分页：新增 idle/loading/noMore/failure 不可变状态、requestSerial、failureCount、阈值触发、重复抑制、retry 和 reset；Controller 使用独立 history 切片。
- 验证：覆盖惯性积分/边界、最新端/时间定位/锚定、OHLC 选择、分页完整状态流、Controller 切片隔离和 Widget 释放后惯性。
- 边界：功能矩阵等待 V2 Widget/Renderer 正式消费后勾选；双实例、父滚动、横屏、鼠标和触控板属于 P4-06；production KChartWidget/Painter 未修改。
- 证据：`docs/architecture/KLINE_V2_NAVIGATION_PROTOCOL.md`。
- 后续：进入 `P4-06`，验证多实例与跨平台输入策略。

### 2026-08-25 / P4-06

- 状态：已完成，双实例、父滚动、横竖屏 resize、鼠标和触控板策略已冻结。
- Arena：新增 axis-gated scale recognizer；单指横向复用 pan/scale 连续序列，单指纵向 rejected 后让父 Scrollable 获胜，第二指继续使用标准焦点缩放；不覆写接受/拒绝回调。
- 鼠标：支持 local hover crosshair、exit 隐藏、纵向滚轮焦点缩放、横向滚轮 pan 和水平拖动；PointerSignalResolver 只消费启用的行为。
- 触控板：原生 pan-zoom 由独立 Listener 路径处理，cumulative scale 与 local pan 同时进入焦点缩放；触摸 recognizer 不重复接管 trackpad。
- 尺寸：验证 600×260 嵌套宽屏 local 坐标及 240×360→600×260 resize 后的 Viewport 正规化与继续导航。
- 实例：两个 ChartGestureRegion 各自持有 InteractionMachine、NavigationMachine、Ticker、Viewport 与输入策略，触摸和桌面事件均不串扰。
- 验证：父 ListView 纵向让行/横向独占、双实例、hover/exit、滚轮、trackpad、策略禁用、Ticker dispose 和 Arena 架构守卫均通过。
- 风险：V2 新链路已提供 ARCH-04/06/07 的 P4-06 证据；legacy ChartPainter.maxScrollX 仍由 P5-06 移除，Phase 4 最终退出由 P4-07 审查。
- 边界：功能矩阵等待 V2 Widget/Renderer 正式消费后勾选；production KChartWidget/Painter 未修改。
- 证据：`docs/architecture/KLINE_V2_CROSS_PLATFORM_INPUT_PROTOCOL.md`。
- 后续：进入 `P4-07`，完成 Phase 4 自动化门禁与退出审查。

### 2026-08-25 / P4-07

- 状态：已完成，Phase 4 自动化门禁与退出审查通过。
- 坐标：新增确定性性质矩阵，覆盖 448 组 data/local 往返、54 组不规则 time/local 往返和 54 组多面板 price/local 往返；误差分别受控于 1e-10、1 ms 和按价格跨度 1e-10。
- 竞争：新增单指触摸阈值、横向 chart winner、纵向 parent winner、静止长按、移动抢先、双指缩放和 pointer cancel 矩阵；每个序列只存在一个 winner，结束后均回到 idle。
- 延迟：新增默认跳过、显式启用的 Host Debug state-to-controller benchmark；pan/scale/crosshair P95 分别为 16.42/3.46/3.89 μs，均低于 1,000 μs 主机状态管线门槛。
- 口径：Host benchmark 不代表真机 input-to-frame、UI 或 Raster 时间；16.7 ms 帧预算和 32 ms 十字线输入到帧预算仍由 Phase 5 固定 Profile 设备验证。
- 风险：V2 路径关闭 ARCH-06/07 并验证 ARCH-04；legacy `ChartPainter.maxScrollX` 与 production Painter 迁移仍由 P5-06 处理，不回流 V2 实例状态。
- 证据：`docs/PERFORMANCE_P4_INTERACTION_BASELINE.md`、`docs/architecture/PHASE_4_EXIT_REVIEW.md`。
- 后续：进入 `P5-01`，冻结 RenderSnapshot 和 Layer 协议。

### 2026-08-25 / P5-01

- 状态：已完成，Renderer 的只读输入、指标投影和 Layer 扩展边界已冻结。
- 快照：新增泛型不可变 `RenderSnapshot<TTheme>`，组合稳定 `VersionedKlineData`、Viewport、Layout、主题、版本向量、指标投影、选择和历史显示状态；P6 再以正式不可变 `KChartTheme` 收敛主题类型。
- 校验：装配时拒绝数据长度不一致、Viewport/Layout 宽度不一致、越界选择、过期指标版本、Series/Descriptor 不匹配、重复实例及指标面板放置错误。
- 指标：`RenderIndicatorSnapshot.fromResult` 只投影可绘制 Series 和 Descriptor，不保留 `IndicatorComputationState` 递归私有状态，也不复制 Series 数值列表。
- Layer：新增 `ChartRenderLayer`、`RenderLayerContext` 和 `RenderLayerStack`；Layer 只获得 Canvas 与快照，ID、依赖切片、绘制顺序和查找表均不可变且重复 ID 被拒绝。
- 架构：render 模块仍不依赖 Controller、Store、Interaction 或 Widget；纯度守卫新增禁止读取指标私有 continuation state，production Painter 未修改。
- 验证：覆盖完整快照、不复制数据、不可变集合、全部装配错误、选择元组、六切片版本、Layer 依赖/顺序/重复 ID、Canvas 上下文、模块依赖与纯度扫描。
- 证据：`docs/architecture/KLINE_V2_RENDER_PROTOCOL.md`。
- 后续：进入 `P5-02`，在本协议上实现独立绘制 Layer。

### 2026-08-25 / P5-02

- 状态：已完成，标准 Layer Stack 与 Phase 5 内部绘制样式已建立。
- 样式：新增不可变 `ChartRenderStyle` 最小接口和 `DefaultChartRenderStyle`；颜色、线宽、字号及指标 palette 均经过校验，Series 颜色按 instanceId/seriesId 稳定解析；P6-01 再扩展为完整公开主题。
- 值域：新增确定性 panel range 解析；主图合并可见 Kline high/low 与声明参与范围的指标，副图读取 Descriptor 的 includeInRange/includeZero，平值和空值使用有限 padding/fallback。
- Layer：标准顺序冻结为 grid → main → secondary → axis → marker → drawing → crosshair；主图支持涨跌蜡烛和主图线，副图统一消费 line/histogram/points Descriptor，轴使用实际时间转换，标记覆盖可见高低点与最新价。
- Overlay：十字线只读取 chart-local selection 且越界不绘制；绘图线段投影进入 RenderSnapshot，ID/坐标/集合均校验后由独立 Drawing Layer 裁剪绘制，变化暂归 data 版本，P7 再加入锚点工具状态。
- 性能边界：各 Layer 只遍历可见范围，不调用 `saveLayer`；P5-03 负责消除多 Layer 重复极值扫描并缓存 Text/Path/Picture，P5-04 负责精确重绘。
- 验证：离屏 Canvas 像素测试分别确认背景/网格、涨跌蜡烛、三种指标、价格/时间轴、marker/drawing/crosshair 独立出图；hidden/越界 crosshair 无输出；纯度门禁新增禁止 saveLayer。
- 边界：当前是内部 V2 参考绘制链路，未修改 production Painter；分时/面积和完整 legacy 视觉迁移属于 P5-05，Golden 属于 P5-07。
- 证据：`docs/architecture/KLINE_V2_STANDARD_LAYERS.md`。
- 后续：进入 `P5-03`，实现可见区与绘制缓存。

### 2026-08-25 / P5-03

- 状态：已完成，标准 Renderer 已接入每图表实例独立的有界缓存。
- 几何：同一 data/viewport key 复用可见范围与 X Transform；主图 OHLC 极值只扫描一次，panel range 按 layout/panel 缓存，selection-only 变化不使其失效。
- 绘制：指标 line 复用 Path，Axis/Marker/Crosshair 复用已布局 TextPainter，背景与网格录制为 Picture；所有缓存使用 LRU 上限。
- 生命周期：TextPainter/Picture 在淘汰、clear 和 dispose 时释放；Pipeline 取得缓存所有权；幂等 dispose、dispose 后访问拒绝、双实例隔离均有自动测试。
- 版本：data/viewport/layout/theme 的快照版本与结构值组成失效键；P5-04 继续用 Layer 依赖切片跳过整层 paint。
- 性能：2,000 根 + 2 副图 Host Debug 缓存热路径 P50/P95/P99 为 192.85/533.35/741.05 μs，P95 低于 10,000 μs 主机回归阈值。
- 边界：Host Canvas 录制不代表真机 UI/Raster；连续新窗口仍扫描可见值域，`PERF-12` 未关闭；Paint 复用尚未完成，因此 `PERF-23` 未关闭。
- 证据：`docs/architecture/KLINE_V2_RENDER_CACHE_PROTOCOL.md`、`docs/PERFORMANCE_P5_RENDER_CACHE_BASELINE.md`。
- 后续：进入 `P5-04`，实现按 Layer 依赖版本的精确重绘判定与计数。

### 2026-08-25 / P5-04

- 状态：已完成，标准 Renderer 已按 Layer 依赖版本精确重录并保留合成。
- 判定：每个 Layer 捕获只包含自身 dependencies 的版本戳；首帧全部录制，未依赖切片变化不失效，任一版本倒退立即拒绝。
- 合成：每层保留一张最新 Picture；变化层事务式重录，未变化层复用，但输出 Canvas 每帧仍按 grid → crosshair 固定顺序合成完整图像。
- 矩阵：selection 仅重录 crosshair；viewport 重录 main/secondary/axis/marker；data 额外重录 drawing；layout/theme 重录全部；当前 history 无可见消费者，因此不触发误重绘。
- 诊断：每帧报告 repaint/reuse Layer ID 与失效切片，并累计每层 repaint/reuse 次数；报告和统计集合不可修改。
- 可靠性：任一 Layer 录制失败时丢弃该帧全部候选 Picture，不推进版本与计数；clear 保留累计诊断，dispose 幂等且实例隔离。
- 性能：2,000 根 + 2 副图 Host Debug 下，无变化保留帧 P50/P95/P99 为 309.7/414.9/459.85 μs；selection-only 为 375.15/487.6/534.5 μs，均低于 3,000 μs 回归阈值。
- 边界：Host Picture 录制/复合不代表真机 Raster；production Painter/Widget 尚未接线，`PERF-21` 与 P5-08 真机门禁仍未关闭。
- 证据：`docs/architecture/KLINE_V2_LAYER_REPAINT_PROTOCOL.md`、`docs/PERFORMANCE_P5_LAYER_REPAINT_BASELINE.md`。
- 后续：进入 `P5-05`，迁移分时、面积及完整 legacy 绘制能力。

### 2026-08-26 / P5-05

- 状态：已完成，内部 V2 Layer 已覆盖实心蜡烛、分时线、面积图和全部 legacy 指标的声明式视觉语义。
- 主图：`RenderSnapshot` 增加 `candlestick`、`line`、`area` 三种模式；蜡烛以 high/low 定量程并绘制主图指标，分时/面积以 close 定量程且不叠加主图指标，保持 legacy 分时语义。
- 样式：最小只读 `ChartRenderStyle` 补充主图线、面积渐变、蜡烛/柱形比例和指标点半径，并冻结校验与防御性复制。
- 指标：Descriptor 增加中立颜色与柱形语义；Volume 由 candle direction 着色，MACD 使用正负色和 legacy 空心趋势柱，SAR 按价格位置着色；其余现有指标继续通过 line/points 统一路径消费，不引入 definitionId switch。
- 缓存：主图模式进入 extrema/range/Path key；可见窗口和 X 变换保持复用。模式切换按 theme 可见配置推进版本后触发正确 Layer 重录。
- 验证：离屏像素测试覆盖三主图模式和指标柱颜色；几何/缓存测试覆盖 close 值域、主图指标隐藏与 mode 精确失效；Descriptor/样式不变量测试通过。
- 边界：production Painter、正式入口与 Demo 未接线；P5-07 仍负责 Golden 与 Widget repaint 计数，P5-08 负责真机 Profile、内存和 GC 门禁。
- 证据：`docs/architecture/KLINE_V2_CHART_MODE_PROTOCOL.md`。
- 后续：进入 `P5-06`，移除 legacy paint 写状态、static 边界和 Widget 全量 setState 链路。

### 2026-08-26 / P5-06

- 状态：已完成，legacy 生产 Widget/Painter 已移除 paint 写状态、跨实例静态滚动边界和全 Widget `setState` 刷新。
- 实例：新增纯 `LegacyChartViewportMetrics`；滚动上限、夹取和选中映射由每个 Widget 自己计算，`ChartPainter.maxScrollX` 与 `BaseChartPainter.maxScrollX` 均已删除。
- 事件：InfoWindow 在长按事件阶段以 chart-local 坐标解析 Kline，独立 `ValueNotifier` 驱动 Overlay；Painter 不再引用 StreamSink 或在 Canvas 绘制期间发布事件。
- 重绘：手势/闪点动画仅递增本实例 paint notifier，由 `RepaintBoundary` 内 `ListenableBuilder` 重建 CustomPaint；详情 Overlay 使用独立 `ValueListenableBuilder`，外层 Widget 不再调用 setState。
- Painter：`shouldRepaint` 比较实际绘制输入，避免恒 true；legacy 可变数据仍要求调用方在更新后调用已有 `notifyChanged()` 请求局部刷新。
- 验证：纯几何、Painter/Widget 架构扫描和 legacy Demo adapter 回归通过。
- 证据：`docs/architecture/KLINE_V2_LEGACY_REPAINT_BOUNDARY.md`。
- 后续：进入 `P5-07`，补齐多尺寸、多主题、多副图 Golden 与 Widget repaint 计数。

### 2026-08-26 / P5-07

- 状态：已完成，内部 V2 Pipeline 已具备多尺寸/主题/副图 Golden 与 Widget 帧 repaint 门禁。
- Golden：冻结宽屏深色蜡烛（2 副图）、紧凑浅色面积（1 副图）、长屏深色分时（3 副图）三组实际 CustomPaint 像素基线；场景同时覆盖网格、轴、marker、crosshair 与声明式指标。
- 重绘：测试宿主直接调用真实 StandardChartRenderPipeline；selection 版本变化只报告 crosshair 重录，相同 Snapshot 不触发 Painter 再绘制，viewport 变化只重录 main/secondary/axis/marker。
- 稳定性：Golden 固定 test surface 为目标逻辑尺寸并截取 CustomPaint RenderBox，避免测试根节点留白；更新基线需要显式 `--update-goldens` 和人工审阅。
- 边界：production V2 Widget 尚未接线；Golden 不替代 P5-08 真机 UI/Raster、内存或 GC 证据。
- 证据：`docs/architecture/KLINE_V2_GOLDEN_REPAINT_GATE.md`、`test/render/goldens/`。
- 后续：进入 `P5-08`，执行 2,000 根 + 2 副图的 Profile、内存和 GC 门禁。

### 2026-08-26 / P5-08

- 状态：已完成，Android 真机上的内部 V2 Profile 宿主已记录 2,000 根 + 2 副图的 UI/Raster、进程内存与 GC 证据。
- 帧：SM-G986U1 / Android 13 / Flutter Profile 的连续 FrameTiming 批次中，UI build P95 最高 2.107 ms、Raster P95 最高 3.506 ms，低于 60 Hz 的 16.7 ms 预算。
- 内存/GC：稳定运行 PSS 175,092 KB、RSS 283,672 KB；进程 GC 记录释放 2,242 KB，暂停 42/12 μs。完整进程 PSS 含 engine/graphics，不能冒充 10,000 根六指标的增量内存预算。
- Host：同场景缓存热路径 P95 1,436.65 μs，保留无变化/selection-only P95 为 227.0/246.6 μs，保持主机回归阈值通过。
- 边界：Profile 宿主只用于内部门禁，不公开；完整六指标 10,000 根增量内存、iOS/Web Profile 和发布级端到端输入延迟仍在 P6/P9 复测。
- 证据：`docs/PERFORMANCE_P5_PROFILE_GATE.md`、`example/lib/v2_performance_main.dart`。
- 后续：进入 `P6-01`，冻结公开不可变 KChartTheme 与 ChartColors adapter。

## 13. 参考资料

- [Binance：TradingView 功能与图表设置](https://academy.binance.com/ka-GE/articles/a-beginner-s-guide-to-tradingview)
- [Binance：K 线与 WebSocket 行情流](https://developers.binance.com/zh-CN/docs/products/spot/testnet/web-socket-streams)
- [Binance：REST API 通用规则](https://developers.binance.com/en/docs/products/spot/rest-api)
- [Binance：订单簿与深度图](https://academy.binance.com/ur-PK/articles/what-is-an-order-book-and-how-does-it-work)
- [Binance：技术分析与常用指标](https://academy.binance.com/ur-PK/articles/what-is-technical-analysis)
- [Binance：蜡烛图与 Heikin-Ashi](https://academy.binance.com/ka-GE/articles/a-beginners-guide-to-candlestick-charts/)

## 14. 首轮执行建议

按本次复审结果，下一轮只启动以下任务：

1. 完成 `P0-04`、`P0-05`，关闭 Phase 0 剩余性能和跨平台基线。
2. 执行 `P1-01`～`P1-04`，先冻结模块依赖、状态切片、Controller 生命周期和单向事件流。
3. 评审 `P1-05`～`P1-06` 的公共 API allowlist 与架构守护测试。
4. Phase 1 门禁通过后再启动 `P2-01`，不提前删除旧实体或改写生产 Painter。

第一轮不得直接开发绘图工具、新增大量指标或重写 Painter。先证明八大问题具备可验证的整改路径，再进入数据、指标和渲染主体开发。

## 15. 计划修订记录

| 版本 | 日期 | 变更 |
| --- | --- | --- |
| `v1.0` | 2026-08-24 | 建立币安功能范围、性能预算和初始 Phase 0～8。 |
| `v1.1` | 2026-08-24 | 将现状归纳为 `ARCH-01`～`ARCH-08`，增加验收闭环；Controller/状态契约前移，拆分视口手势与分层渲染，调整为 Phase 0～9。 |
| `v1.2` | 2026-08-24 | 完成执行性复审；修正总体路线与 Phase 顺序不一致，补充测量口径、冻结点、关键门禁，并建立开发清单和周级时序线。 |
