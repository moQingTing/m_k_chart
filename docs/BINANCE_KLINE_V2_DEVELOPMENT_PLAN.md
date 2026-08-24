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
- [ ] `BN-F02` 24h 涨跌额、涨跌幅、最高、最低、成交量和成交额。
- [ ] `BN-F03` OHLC、涨跌额、涨跌幅、振幅和选中时间详情。
- [ ] `BN-F04` 最新价格线、价格标签和当前 K 线收盘倒计时。
- [ ] `BN-F05` 可见区最高价、最低价标记。

### 3.2 图表类型

- [ ] `BN-F10` 标准蜡烛图。
- [ ] `BN-F11` 分时折线图。
- [ ] `BN-F12` 面积图。
- [ ] `BN-F13` 实心/空心蜡烛。
- [ ] `BN-F14` Heikin-Ashi 平均 K 线。
- [ ] `BN-F15` 深度图。
- [ ] `BN-F16` 横屏和全屏。

首个 2.0 正式版不包含 Renko、Kagi、Range、Point & Figure。

### 3.3 周期体系

- [ ] `BN-F20` 支持 `1s`。
- [ ] `BN-F21` 支持 `1m/3m/5m/15m/30m`。
- [ ] `BN-F22` 支持 `1h/2h/4h/6h/8h/12h`。
- [ ] `BN-F23` 支持 `1d/3d/1w/1M`。
- [ ] `BN-F24` 自定义快捷周期和收藏。
- [ ] `BN-F25` UTC、UTC+8 及宿主传入时区。
- [ ] `BN-F26` 周期切换时可配置是否保留缩放、指标和绘图。

### 3.4 手势与导航

- [ ] `BN-F30` 单指平移和惯性滑动。
- [ ] `BN-F31` 双指缩放，并以手势焦点为缩放中心。
- [ ] `BN-F32` 长按十字线和 OHLC 磁吸。
- [ ] `BN-F33` 价格轴、时间轴浮动标签。
- [ ] `BN-F34` 左滑触发历史分页，具备 loading、noMore 和 retry 状态。
- [ ] `BN-F35` 回到最新 K 线按钮。
- [ ] `BN-F36` 双击或 Controller 复位。
- [ ] `BN-F37` 正确处理父级滚动容器手势竞争。
- [ ] `BN-F38` 鼠标滚轮、悬浮十字线和桌面/Web 指针事件。

### 3.5 指标

主图指标：

- [ ] `BN-I01` MA。
- [ ] `BN-I02` EMA。
- [ ] `BN-I03` BOLL。
- [ ] `BN-I04` SAR。
- [ ] `BN-I05` VWAP。
- [ ] `BN-I06` Ichimoku。

副图指标：

- [ ] `BN-I10` VOL。
- [ ] `BN-I11` MACD。
- [ ] `BN-I12` RSI。
- [ ] `BN-I13` KDJ。
- [ ] `BN-I14` WR。
- [ ] `BN-I15` OBV。
- [ ] `BN-I16` ATR。
- [ ] `BN-I17` CCI。
- [ ] `BN-I18` DMI。
- [ ] `BN-I19` ROC。
- [ ] `BN-I20` Stoch RSI。

指标公共能力：

- [ ] `BN-I30` 参数、颜色、线宽和数据源配置。
- [ ] `BN-I31` 同类指标支持多实例。
- [ ] `BN-I32` 多副图显示、排序和高度调整。
- [ ] `BN-I33` 阈值线、零轴和区域填充。
- [ ] `BN-I34` 指标配置序列化，由宿主决定持久化介质。
- [ ] `BN-I35` 指标插件协议，新增指标无需修改核心枚举和 Painter。

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

- [ ] `PERF-10` 只遍历可见 K 线，不绘制屏幕外元素。
- [ ] `PERF-11` 缓存坐标换算参数和可见起止索引。
- [ ] `PERF-12` 使用滑动窗口、分块 min/max 或 Segment Tree 缓存极值，避免每帧扫描全部副图数据。
- [ ] `PERF-13` 缩放期间使用轻量预览，手势结束后再完成非关键文本布局。

#### 绘制

- [ ] `PERF-20` 拆分静态背景、数据、Overlay、十字线和绘图 Layer。
- [ ] `PERF-21` 每个 Layer 独立 `RepaintBoundary`/Listenable，只重绘变化部分。
- [ ] `PERF-22` 正确实现 `shouldRepaint()`，比较数据版本、视口版本和样式版本。
- [ ] `PERF-23` 复用 Paint、Path 缓冲区和常用 TextPainter/Paragraph。
- [ ] `PERF-24` 网格、固定标签等静态内容缓存为 Picture，尺寸或主题变化时失效。
- [ ] `PERF-25` 依据屏幕密度和缩放级别做绘制抽稀，避免亚像素级无效细节。
- [ ] `PERF-26` 禁止无必要 `saveLayer()`，控制渐变、阴影和 clip 的使用。

#### 调度与交互

- [ ] `PERF-30` WebSocket 高频 tick 采用一帧最多提交一次的合并策略。
- [ ] `PERF-31` 十字线 Overlay 与主数据层分离，移动时不重绘全部蜡烛。
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

### Phase 1：架构契约与状态骨架，4～6 人日

- [x] `P1-01` 建立 `src/model|data|indicator|drawing|controller|viewport|render|interaction|theme|widget|adapter` 模块边界和依赖规则。
- [ ] `P1-02` 定义不可变 `KChartState`、StateSlice 和版本号协议，区分数据、视口、选择、布局和主题变化。（进行中）
- [ ] `P1-03` 实现最小 `KChartController` 生命周期与每实例状态容器，禁止 static 运行状态。
- [ ] `P1-04` 定义单向事件流：输入/数据 → Controller/Store → State → Renderer；Painter 必须无副作用。
- [ ] `P1-05` 统一 `m_k_chart.dart` 公共入口，建立 public API allowlist、deprecated 和兼容导出策略。
- [ ] `P1-06` 建立架构守护测试：依赖方向、双实例隔离、dispose 和 API surface。

阶段门禁：关闭 `ARCH-02`、`ARCH-03`、`ARCH-04` 的结构风险；Controller 骨架可独立单测；旧组件行为不变。

### Phase 2：不可变数据模型与实时 Store，5～7 人日

- [ ] `P2-01` 实现不可变 Kline、Interval、PriceSource 和数据版本。
- [ ] `P2-02` 实现旧 `KLineEntity` 双向 adapter，旧 API 继续可用。
- [ ] `P2-03` 实现 replace/prepend/append/update 和只读数据视图。
- [ ] `P2-04` 实现重复、乱序、闭合校正和 generation token 规则。
- [ ] `P2-05` 实现 Binance REST/WebSocket 示例 adapter，但核心包不依赖 Binance API。
- [ ] `P2-06` 完成 10,000 根数据合并 benchmark、内存基线和异常输入测试。

阶段门禁：`ARCH-01` 的行情侧整改完成；事件幂等；旧 Demo 可经 adapter 运行；历史合并满足 50 ms 预算。

### Phase 3：独立指标引擎，6～8 人日

- [ ] `P3-01` 定义注册式 Indicator、IndicatorConfig、IndicatorSeries 和 RendererDescriptor 协议。
- [ ] `P3-02` 实现以数据版本、参数和数据源为键的缓存及增量更新协议。
- [ ] `P3-03` 迁移现有指标并与 Phase 0 快照对照。
- [ ] `P3-04` 增加 VWAP、ATR、CCI、DMI、ROC、Stoch RSI。
- [ ] `P3-05` 支持同类多实例、数据不足状态、NaN/Infinity 隔离。
- [ ] `P3-06` 删除新链路对实体 `late` 指标字段及核心 enum/switch 的依赖。

阶段门禁：关闭 `ARCH-01` 的指标侧风险和 `ARCH-08` 的指标扩展风险；最后一根更新 P95 ≤ 8 ms；注册一个测试指标无需修改核心代码。

### Phase 4：视口、布局与手势状态机，6～8 人日

- [ ] `P4-01` 实现每实例 ChartViewport、可见范围和缩放/滚动边界。
- [ ] `P4-02` 实现数据坐标、图表 local 坐标、价格和时间的双向转换。
- [ ] `P4-03` 实现确定性 LayoutModel，修复网格数量、初始化顺序、多副图尺寸和嵌套偏移问题。
- [ ] `P4-04` 实现遵循 Gesture Arena 的单指平移、焦点缩放、长按十字线互斥状态机。
- [ ] `P4-05` 实现惯性、磁吸、回到最新、指定时间定位和历史分页状态。
- [ ] `P4-06` 实现双图表隔离、父滚动容器、横屏、鼠标和触控板策略。
- [ ] `P4-07` 完成坐标往返、手势竞争和输入延迟自动化测试。

阶段门禁：关闭 `ARCH-06`、`ARCH-07`，并验证 `ARCH-04`；不得强制接受已被 Gesture Arena 拒绝的手势。

### Phase 5：纯函数分层渲染与性能整改，8～12 人日

- [ ] `P5-01` 定义 RenderSnapshot 和 Layer 协议，Renderer 只读状态且无副作用。
- [ ] `P5-02` 实现网格、主图、副图、轴标签、标记、十字线和绘图独立 Layer。
- [ ] `P5-03` 实现可见区裁剪、极值缓存、文本/Path/Picture 缓存。
- [ ] `P5-04` 用数据、视口、样式和 Layer 版本正确实现重绘判定。
- [ ] `P5-05` 迁移蜡烛、分时、面积图及现有指标绘制。
- [ ] `P5-06` 移除 paint 内 Stream 写入、全局 maxScrollX 和 Widget 全量 setState 链路。
- [ ] `P5-07` 建立多尺寸、多主题、多副图 Golden 和 repaint 计数测试。
- [ ] `P5-08` 完成 2,000 根 + 2 副图的 Profile 帧性能、内存与 GC 门禁。

阶段门禁：关闭 `ARCH-03`、`ARCH-05`；十字线只重绘 Overlay；Golden 通过；新 Renderer 达到第 6 节性能预算。旧组件可选择 legacy 或 v2 Renderer。

### Phase 6：币安式核心体验与主题，5～7 人日

- [ ] `P6-01` 完整不可变 KChartTheme、样式注册和 ChartColors 兼容 adapter。
- [ ] `P6-02` 实现实心/空心蜡烛、Heikin-Ashi、最新价、倒计时及高低点标记。
- [ ] `P6-03` 实现周期和图表类型工具栏示例。
- [ ] `P6-04` 实现指标选择、排序、参数面板和多副图高度配置。
- [ ] `P6-05` 实现行情摘要、OHLC 信息栏、横屏/全屏 Demo。
- [ ] `P6-06` 实现用户配置序列化接口和兼容迁移。

阶段门禁：`ARCH-01`～`ARCH-08` 全部有通过证据；Phase 0～6 可发布 `2.0.0-alpha`，具备完整基础交易图表体验。

### Phase 7：绘图工具，8～12 人日

- [ ] `P7-01` 绘图对象、锚点、样式和版本化 JSON。
- [ ] `P7-02` 绘图命中测试和控制点。
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
