# ADR-002：V2 Widget / Controller 接入契约

> 决策日期：2026-10-13
> 实施更新：2026-10-22
> 任务：OPT-02
> 状态：基础接入契约已冻结；V2 公共 API 纳入 2.0.0 正式兼容面
> 实现：状态协调、Controller/Widget 封装和正式入口接线已落地；跨平台设备验收与包发布仍待完成

## 1. 本轮边界

目前可运行的是完整 Demo，不是完整公开 SDK。现有内部 KChartController 主要归约视口、
布局和选中事件，不拥有完整行情仓库，不能直接作为公开控制器导出。

本决策冻结基础命名、数据所有权、异步写入、配置、通知及组件生命周期。
下方 Widget/Controller 签名均已有仓库实现，并从 `package:m_k_chart/m_k_chart.dart` 正式导出。
这些类型由 2.0.0 纳入稳定兼容面。宿主编译探针 `test/contracts/fixtures/v2_candidate_host.dart` 只导入正式
入口，不使用假的 KChart Widget 充当实现。

2026-10-14：`KChartDataCoordinator` 已真正实现数据接口和只读内部快照，集中处理选中恢复、
时间锚定导航、会话失效与挂载约束；随后补齐历史加载、失败重试和迟到响应隔离。
指标配置与引擎也已纳入统一状态提交；KChartOptions 值对象及布局适配已实现。
内部 setOptions/视口策略应用已接通。2026-10-15 又补齐 KChartViewState 候选 DTO 投射和
会话级覆盖物集合管理；第七批新增候选 Controller 封装，但尚未接入 Demo 或正式导出。
OPT-04 首批已实现内部 KChartSurface/KChartFrame 的实际绘制、手势及挂载/切换生命周期；
2026-10-16 第二批补齐参数栏、信息面板、中间时间轴及内部文案/内容替换，并新增独立验收页；
2026-10-19 增加候选 `KChart` 包装，负责时钟/前后台暂停、选中与错误帧后回调；
基础图表无障碍语义已补，VoiceOver/TalkBack 人工验收、覆盖物逐项可访问性和默认 Demo 迁移
仍未完成，正式公共入口未变。
内部快照允许持有 ChartViewport，对宿主的只读视图则投射为下文的 KChartViewState /
KChartViewportInfo；公开 DTO 不包含像素视口、内部配置适配方法或可变 Store。

`package:m_k_chart/m_k_chart.dart` 仍是唯一正式入口。ADR-001 的准入条件继续有效。
指标插件元数据、交易事件和绘图工具的扩展签名
分别在 OPT-06/09/10 补充并验证后准入，不能直接导出内部 Renderer/Editor。

截至 2026-10-22，公开 `KChart`/`KChartController` 已接入独立最小示例和设置/绘图验收页；
候选绘图包含创建、编辑、历史命令和版本化快照，宿主可注入快照存储。Example 自动化及
iOS 模拟器集成已有通过记录，Android 真机已完成短时 Binance HTTP 行情视觉演示。V2 受控类型已
进入唯一正式入口，宿主探针已验证；2.0.0 兼容面以正式包为准，Web/Profile 后续质量改进单独跟踪。

## 2. 核心决策

| 事项 | 决策 | 理由 |
| --- | --- | --- |
| 新组件 | KChart，保留旧 KChartWidget | 新旧接入路径清晰分离 |
| 新控制器 | 正式 facade 名为 KChartController，组合内部控制器 | 不暴露 dispatch、StateSlice 等实现 |
| 数据所有者 | Controller 独占，Widget 不再接收 data | 避免两份输入互相覆盖 |
| 空窗口身份 | 显式 KlineSeries | 不能从空数组推测交易对/周期 |
| 异步写入 | 每条数据命令携带 KChartDataSession | 防止跨实例、换周期及 A→B→A 后旧结果写入 |
| 配置所有者 | Controller 管 options，Widget 管 theme / UI 回调 | 不同时维护同一配置的两份副本 |
| 挂载 | 一个 Controller 同时只能服务一张图 | 一份像素视口不能代表两张不同大小的图 |
| 监听 | 只读 ValueListenable<KChartViewState> | 不暴露容器、渲染快照和通知入口 |
| 刷新 | 聚合快照加内部细粒度依赖 | 倒计时不应迫使整张图重建 |

双图使用两个 Controller，由宿主分发同一不可变行情。序列身份使用 symbol、完整 interval、
priceSource，与 Kline.hasSameSeries 一致；显示时区不改变原始 UTC 时间。多交易所同名 symbol
由宿主命名约定或独立 Controller 隔离。SDK 不擅自修改 symbol 大小写。

## 3. Widget 基础签名（OPT-04 进行中，仓库内候选包装已实现）

```dart
KChart({
  Key? key,
  required KChartController controller,
  KChartTheme? theme,
  KChartLabels labels = const KChartLabels.zhCN(),
  bool interactionEnabled = true,
  WidgetBuilder? emptyBuilder,
  KChartSelectionBuilder? selectionBuilder,
  ValueChanged<KChartSelection?>? onSelectionChanged,
  ValueChanged<KChartIssue>? onIssue,
  int Function()? currentTimeMilliseconds,
})

typedef KChartSelectionBuilder = Widget Function(
  BuildContext context,
  KChartSelection selection,
);
```

- 父级提供有限宽高，Widget 自动布局，宿主不创建 Painter 或计算面板矩形。
- theme 未指定时使用 KChartTheme.light()；主副图格式、小数位和十字线样式复用 KChartTheme。
- KChartLabels 提供中文默认及本地化替换，保留语义缩放与返回最新操作。
- 默认信息面板按命中点左右避让；selectionBuilder 仅替换内容，Widget 负责定位和边界。
- emptyBuilder 处理空窗口；网络加载、网络错误由宿主呈现，不伪造数据。
- interactionEnabled 只禁止用户输入，不禁止程序导航与更新。
- 不在 build/paint 中触发业务回调；完整状态提交后安全派发，相同状态重建不重复派发。
- 点击选中持久化、长按结束隐藏、悬浮离开隐藏；实时更新保留身份，平移按 OPT-01 清除。
- onSelectionChanged(null) 表示取消；已选柱内容变化时提供新的 candle，不保留过期 OHLC。
- 候选实现的可选时钟注入仅用于倒计时，默认设备时间；后台和 `TickerMode` 禁用时暂停计时，
  恢复时同步。Controller 由宿主销毁，组件卸载只解绑。时钟注入是否进入正式 API 留待 OPT-12 审核。

## 4. Controller 基础签名（候选实现已落地，待组件接线与准入）

```dart
KChartController({
  required KlineSeries series,
  Iterable<Kline> initialData = const [],
  KChartOptions? options,
  KChartHistoryLoader? historyLoader,
})

// 实现 ValueListenable<KChartViewState>；不公开 notifyListeners/dispatch。
KChartViewState get value;
bool get isDisposed;
KChartDataSession get session;

void setOptions(KChartOptions options);
void clearSelection();
void scrollToLatest();
void scrollToTime({required int epochMilliseconds, double alignment = 0.5});
void resetViewport();
Future<void> retryHistory();
void retryIndicators();
void dispose();
```

数据方法完整签名以 **KChartDataCommands** 为准：

| 方法 | 数据行为 | 选中 / 视口 |
| --- | --- | --- |
| beginSeries(series, initialData:) | 先校验再切换会话，同序列刷新也换令牌 | 清除选中，重置到最新及重置历史/序列覆盖物 |
| replaceData(data, session:, viewportPolicy:) | 同序列权威窗口替换，允许清空 | 默认保留有效身份和可见时间锚；resetToLatest 清除选中并返回最新 |
| appendData(data, session:) | 严格追加，拒绝重复/重叠 | 原来跟随最新才继续跟随，否则保持历史/未来留白锚定 |
| prependHistory(data, session:) | 严格前插，拒绝重复/重叠 | 保持已有柱位置，重新解析选中下标 |
| updateKline(candle, session:, allowClosedCorrection:) | 同身份替换、新增最新或有限乱序插入 | 保留有效选中；默认拒绝已收盘柱修正 |

统一规则：

1. 实现复制可变输入，只暴露不可修改列表；原始 Kline 不携带指标结果。
2. 先检查令牌，再遍历输入。过期、跨实例或已 dispose 的数据命令返回 ignoredStaleSession，
   不读取失效 payload，不推进版本，不通知，不触发 UI 错误提示。
3. 有效令牌携带不同序列、重复时间、逆序或非法参数时抛 ArgumentError，所有状态和令牌不变。
4. 回执 KChartDataUpdateResult 包含事务后的 dataRevision 和状态：applied、unchanged、
   ignoredStaleSession、rejectedClosedCorrection、rejectedOutsideWindow。
   只有 rejectedOutsideWindow 的 requiresReload 为 true。
5. 相同数据、空追加/前插不推进数据版本；一次有效命令至多通知一次。
   resetToLatest 即使数据未变也可能改变视口/选中，数据回执仍为 unchanged。
6. 导航不重算指标；尚无布局时记录最后一个导航目标，首次有布局和数据后执行。
   scrollToTime 使用 UTC 毫秒，alignment 为 0～1；稀疏时间沿用现有坐标映射，不虚构新柱。
7. 主动 scrollToLatest/scrollToTime/resetViewport 清除选中；纯布局变化和缩放保留。
   beginSeries 清除旧序列的待执行导航；空窗口不尝试访问数据索引。
8. SDK 不内置 HTTP/WebSocket，也无法判断同 session 的两份 REST 快照谁更新。
   宿主串行化权威快照加载，或重载时 beginSeries 并重建订阅；实时流在初始快照之后接入。
9. 乱序默认最多允许跨过 2 根更新的柱，通过 options 配置；沿用 KlineRealtimeCoordinator。

切换序列清理的是当前运行时覆盖物，不删除宿主保存的绘图；恢复由 OPT-10 的隔离协议负责。

## 5. 配置与只读状态

KChartOptions 是不可变运行时配置，具备 copyWith、结构相等和严格校验，不等于 JSON 偏好。
冻结的配置分组（值对象及内部 setOptions 已实现，正式 Widget 接线在 OPT-04 完成）：

- mainMode：六种现有模式，默认 candlestick；沿用 ChartMainMode 语义。
- mainPanel：参数区最小高度、自动换行、绘图区最小高度和网格行数。
- secondaryPanels：有序配置，每项有稳定 id、高度、参数区高度和网格行数。
- indicators：panelId 绑定与 instanceId/definitionId/parameters/seriesStyleKeys。
  instanceId 全图唯一、panelId 必须存在、main 是保留 id；多个指标允许绑定同一副图。
- viewport：初始可见数量、槽位宽度限制、右留白和未来拖动上限；默认沿用 Demo/旧版约定。
- timeZoneOffset、mainTimeAxisHeight、gridColumns、maxOutOfOrderCandles。

初始布局沿用 Demo：90 根可见，主图绘图区最小高 220，主副参数区最小高 18，
副图高度 108，时间区 18，竖向分段 2，主图 gridRows=4，副图 gridRows=2。
SDK 不默认添加 MA/VOL/MACD，由示例显式配置；计算参数默认值由指标定义提供。

options 只通过 setOptions 改变；theme 是 Widget 纯呈现配置，不在 Controller 再存一份。
未知指标/计算错误隔离失败实例并发出 onIssue；重复 id、缺失面板、非法尺寸等结构错误在
提交前失败。修改 options 不隐式切换 series。
KChartUserConfig 恢复需显式解析周期/指标，再 beginSeries/setOptions；既有 JSON schema 不变。

KChartViewState 至少提供 revision、dataRevision、session、不可变 data、options、
selection、viewportInfo、historyStatus、不可变 issues；不暴露 StateSliceVersions、
ChartLayoutModel、RenderSnapshot、Store 或 IndicatorEngine。

- KChartSelection：命中 Kline、前一根 Kline（可空）、panelId、所选面板数值；时间来自 candle。
- KChartViewportInfo：挂载/布局状态、是否最新/最旧、可见数据起止时间（空时为 null）。
- KChartIssue：类别、关联实例 id、原异常和 stackTrace，不保存 BuildContext 或账户对象。
- 历史快照不随下次事务改变；宿主通过 addListener/removeListener 与 value 读取。
- 快照 DTO 已在 OPT-03 内部落地，细分订阅在 OPT-05 实现；尚未从正式入口导出。

2026-10-15 只读状态与覆盖物实施补充（第六批）：

- 协调器提供稳定的 `ValueListenable<KChartViewState> view`，只读桥和内部 value 共用同一
  通知列表。每次提交先同时生成两个版本一致的视图，再通知；不重复通知，也不提供写入口。
  同配置/同数据/同覆盖物的无操作保留快照身份。销毁后保留最后快照供诊断，拒绝新增监听。
- DTO 复用已冻结的行情/配置/覆盖物，不为选中/导航复制全部数据；选择包含当前柱、前柱、
  panelId 和该面板命中数值，不以主图 close 代替副图值。前插和实时修正后投射最新信息。
- viewportInfo 的 hasLayout 表示存在非零宽度，与 isAttached 独立；解绑保留最后尺寸。
  无布局或空行情时 isAtLatest/isAtOldest 为 false；可见起止时间仅取实际可见柱（含部分
  可见槽位），没有可见数据时成对为 null，不向虚拟留白推算时间。
- issues 投射当前指标失败和历史失败，保留类别、实例 id、原异常与堆栈；不是追加式日志。
  重试成功或移除失败指标后清除对应问题；原异常引用不深拷贝，不保证宿主自定义异常内部不可变。
  onIssue Widget 回调仍待 OPT-04，细分通知和更细的 DTO 复用仍待 OPT-05。
- 内部 setOverlays 以必传 session 接收 priceLines/events/valueMarkers/drawings 四组 Iterable，
  一次替换完整集合；只更新部分时须显式带上其他要保留的集合。全空调用清空当前覆盖物。
  返回 applied/unchanged/ignoredStaleSession，覆盖物变化不推进 dataRevision、不重算指标。
- KChartOverlays 冻结输入，按结构比较；四类覆盖物共用唯一 id 空间。重复 id 或输入遍历
  失败在提交前回滚。旧覆盖物模型的相等行为不改变，绘图直接复用已有不可变 ChartDrawing。
- beginSeries（同序列也算）原子清空运行时覆盖物；普通行情替换、增量、历史前插、窗口裁剪/
  清空、配置、导航和解绑不删除覆盖物。窗口外锚点留存，显示裁剪由后续投射处理。
  旧会话、跨实例或销毁后的回调在枚举载荷前忽略；错误的 beginSeries 不影响原覆盖物。
- 此处不发送交易，不删除宿主已保存绘图；编辑器、撤销栈、绘图变化 UI 回调及持久化恢复仍由
  OPT-09/10 接线。仅建立运行时集合所有权和会话清理，不宣称绘图交互已完成。
- DTO/覆盖物以 part 文件共享协调器私有构造边界，避免暴露“接管可变列表”入口；正式 API
  准入仍按受控类型清单执行，不直接整文件导出内部协调器或含几何适配方法的配置类型。

2026-10-15 Controller 封装及候选入口实施补充（第七批）：

- `k_chart_facade.dart` 的 KChartController 真正组合唯一 KChartDataCoordinator，实现
  KChartDataCommands 和 ValueListenable<KChartViewState>；转发数据、配置、导航、历史/指标
  重试、会话覆盖物和生命周期命令，不复制状态，也不添加第二层通知器。
- 保留原 `k_chart_controller.dart` 的同名内部事件归约器，旧 barrel/Demo 无需迁移；两个库
  通过不同入口隔离，宿主候选入口只指向新封装，不能同时无前缀导入两个内部实现文件。
- 新封装不公开 dispatch、notifyListeners、attach、select、applyViewport 或 runtime getter。
  Widget 用 `@internal runtimeForKChartWidget` 获取内部桥；候选 show 导出显式排除此函数。
  宿主拥有 dispose，Widget 只挂载/解绑，沿用一控制器一张图的约束。
- createLayout/resolveViewport 移到独立 `k_chart_options_geometry.dart` 扩展，参数区、尺寸、
  留白算法原样复用；配置类本身不再具备返回内部几何的成员方法。内部消费者显式导入扩展，
  候选入口不导出扩展。槽宽默认常数仍引用既有 ChartViewport 常量，不复制两份默认值。
- `k_chart_candidate_api.dart` 是仓库内审核用的显式 show 集合，并非新的正式公共入口。
  候选宿主探针只导入此文件完成控制器、指标、覆盖物/绘图创建；没有真实 Widget 替身。
  导出候选符号有独立守护，正式 m_k_chart.dart / allowlist / 包版本均不变。
- 此批不新增指标插件注册/元数据能力，继续使用既有内置定义；可扩展算法 API 在 OPT-06 审核。
  Widget、Demo 接入与真机手势/绘制/前后台验证仍待执行，不能把 Controller 集成测试当作真机验收。

2026-10-14 指标装配实施细则（内部，不是新增正式公共 API）：

- `KChartIndicatorBinding` 组合 panelId 和既有不可变 IndicatorConfig，支持 copyWith/结构相等。
  参数、样式键不复制为另一套模型，后续由 KChartOptions.indicators 承载。
- 协调器构造时注册全部 18 种内置指标，但默认不启用任何指标；通过 indicatorDefinitions
  一次性注入自定义定义，注册表和有界缓存按图表私有，重复定义 id 不允许覆盖。
  自定义定义应为纯计算对象，不应在多个图表之间共享可变算法状态。
- 内部 `setIndicators(bindings, panelIds:)` 可原子更新配置及面板身份；重复实例 id、缺失面板
  和非法面板列表在计算前失败。`setPanels` 删除面板时同时移除其绑定和失效选中。
- RuntimeState 保存不可变绑定列表与 indicatorBatch；数据版本、结果长度、配置、选中及面板
  在同一次通知中保持一致。更新配置不隐式改变行情会话、数据版本或视口。
- 未知定义、定义支持的参数校验失败及计算异常隔离到 failures，不阻断其他实例；通过内部
  `retryIndicators()` 显式重试，成功实例复用缓存。尚未接入 Widget 的 onIssue 和错误界面。
- 同配置无操作、选中、平移/缩放、挂载、分页 loading/failed 不进入计算引擎；仅显示重排和
  面板移动也复用原批次。数据或计算配置改变才解析结果；换会话主动清缓存后重算。
  seriesStyleKeys 仍沿用既有完整配置缓存键，样式变更的更细粒度复用留待 OPT-05。
- 自定义计算器同步调用图表写入、导航、配置、解绑或销毁会被拒绝，并作为该指标计算失败
  隔离；计算成功提交之后的监听器仍可以正常发起下一事务，不允许计算中途覆盖完整状态。
- 这不等于完整 KChartOptions、公共快照、指标元数据设置 UI 或渲染投射已完成；这些职责继续
  由 OPT-03/04/06 接线。SDK 默认指标算法及 Demo 原有周期、配色、可见序列均未修改。

2026-10-14 配置值对象实施补充：

- `k_chart_options.dart` 已提供 KChartOptions、KChartPanelOptions、
  KChartSecondaryPanelOptions 和 KChartViewportOptions，均严格校验、不可变且支持 copyWith/
  结构相等。指标配置校验复用协调器的同一函数，缺失面板和重复实例规则不分叉。
- 主图默认 minHeight=220、headerHeight=18、weight=3、gridRows=4，副图内容最小高度为
  108、headerHeight=18、weight=1、gridRows=2；参数区高度额外预留，不含在内容高度中。
  主图默认自动增高，副图沿用现有固定高度，可单独启用自动增高；网格边界语义不改变。
- createLayout 在已有 ChartLayoutModel 上转换配置，不重写布局算法。Widget 提供文字测量
  高度，自动模式取配置最小值与测量值较大者；固定模式保留配置高度，数据区不覆盖参数区。
  无副图时时间区位于底部，有副图时位于主副图之间。空间不足明确拒绝，不静默重叠。
- 时区默认 UTC+8，限制为 UTC-12～UTC+14 的整分钟；时间区默认 18、间距 0、gridColumns=2。
- 视口配置保存首屏 90 根、现有槽位宽度上下限、旧版默认 1/5 右侧虚拟留白策略及允许最新柱
  拖至左侧的开关。第四批仅提供策略值，第五批已应用到内部协调器；适配沿用旧版换算逻辑，
  不得将留白实现为缩窄绘图区。createLayout 始终保留完整可用宽度。
- ChartMainMode 移到纯模型层；旧 render 路径仅转导出，枚举类型身份与行为保持相同，避免
  Controller 依赖 Renderer 或复制另一套模式枚举。正式公共导出不变。
- 第四批未实现 Controller.setOptions，第五批已接入内部协调器，仍未将配置类型公开。公开准入时应将
  返回内部 ChartLayoutModel 的适配入口留在内部，不能直接整文件导出为稳定 SDK。

2026-10-14 配置事务及视口策略实施补充（第五批）：

- 内部快照新增 options，乱序窗口与历史阈值从该唯一配置读取；setOptions 原子提交面板、
  指标、有效选中与结果批次。不改变 session/dataRevision；配置等价不通知，纯布局不重算指标。
- 首屏根数变化重新适配槽宽，其他策略变更保持用户缩放（受新上下限约束）；几何调整保持
  可见时间锚的像素位置，最新态仍跟随最新。到达数据/未来边界时允许正常夹取。
- setViewportSize 接收可用宽度：首次非零尺寸按配置根数适配；后续 resize 不重置用户缩放。
  resetViewport/beginSeries 重新适配；零宽时延迟适配与时间定位，先布局再执行定位。
- resolveViewport 逐项对应旧版 marginRight/minTranslateX，保留不足一屏的左对齐；先夹取
  实际槽宽再计算留白和未来边界，避免缩放极限的比例错配。数据数量变化会重算虚拟留白。
  createLayout 不扣除右侧宽度；默认未来边界使最新蜡烛中心可到左侧半个槽宽的位置。
- setPanels/setIndicators 是内部过渡适配，统一复制 options，保留既有副图几何；主图始终
  排在副图之前。构造 options 不允许与旧扁平配置参数混用。旧调用显式传 initialViewport
  且未传 options 时暂保留手工边界；首次 setOptions 后永久移交策略管理，正式 facade 不保留
  这组底层入口。有尺寸的自定义初始视口与 options 同传时保留初始缩放，但边界由 options 推导。
- 调整历史阈值安排下一轮检查，不取消在途请求，也不因修改布局而重试失败历史；参数区、
  时区和主图模式目前只提交配置，真正呈现由 OPT-04 Widget/投射接线负责。
- 此阶段仍非正式 Controller；公开快照、覆盖物生命周期与 Widget/Demo 接线继续推进。

## 6. 历史加载契约

```dart
typedef KChartHistoryLoader = Future<KChartHistoryPage> Function(
  KChartHistoryRequest request,
);
```

- 请求包含 session、唯一 requestId、beforeOpenTime（早于当前首条，UTC 毫秒）。
  响应是不可变 candles 与 hasMore；零条且 hasMore=true 视为无进展失败，避免循环加载。
- 初始空窗口由宿主加载；自动历史请求在靠近最旧边界时触发，每个 Controller 最多一个在途请求。
- 完成时验证 session、requestId、请求边界；换序列、替换窗口、卸载/销毁后迟到结果丢弃。
  replaceData 失效历史请求，但不隐式失效当前实时 session。
- 校验成功后一并提交前插数据和分页状态；网络/格式失败保留数据，可 retryHistory。
- 未挂载时不自动加载；重挂后按当前位置恢复。宿主仍负责取消实际网络请求。
- 手动 prependHistory 不完成自动请求；实现要失效已冲突的历史请求，不能重复前插。

2026-10-14 内部实现细则：

- 数据契约位于 `k_chart_history_contract.dart`，分页流程位于 `k_chart_history_coordinator.dart`，
  以 part 共享协调器的原子提交入口，不建立另一套 UI 通知通道。
- 预加载默认距最旧边缘 2 个槽位；`historyThresholdItems` 已由 options 统一提供，可动态更新。
  自动检查合并到微任务执行，并重新检查挂载、布局、数据和状态，避免在布局栈调用宿主。
- 请求 id 在同一实例内单调递增；判定结果有效还必须匹配当前操作身份、会话及首条数据边界。
  每实例最多一个有效在途分页；旧请求失效不等于底层 HTTP 已取消，可能与新网络请求重叠。
- `retryHistory` 在 loading 时返回同一个 Future；失败只记录 error/stackTrace，不自动反复重试。
  显式重试不要求接近最旧边缘，但仍要求已挂载、有布局、非空窗口和未到末页。
  未配置 loader 或暂不符合条件时直接完成；销毁后主动调用抛 StateError。
- 请求成功、失败或失效时完成等待 Future；失败信息从 history 读取，不另抛网络异常。
  失效立即结束逻辑等待，并继续消费旧网络 Future 的迟到成功/异常。
- 成功时以**当前**数据窗口校验前插，保留请求期间实时追加/替换；数据、选中、视口及
  idle/exhausted 分页状态一次提交。旧快照不被修改，末页空响应不推进数据版本。
- 权威 replaceData（即使内容未变）重置分页；手动前插或实时插入改变首条时取消旧游标。
  非法批次不取消有效请求；空前插不会取消；原请求期间只更新尾部仍可正常合并历史。
- 卸载取消在途分页但保留失败/末页状态；重挂后 idle 按当前位置恢复，failed 需显式重试。
  没有前进的响应（空页且 hasMore=true）、错序、重复、错序列及边界重叠都记为失败。

上述已由协调器单元/异步测试覆盖，尚不代表 Widget 自动接线、错误 UI 或真实 HTTP 已验收。

## 7. 生命周期、回调与兼容

1. 宿主创建并 dispose Controller；Widget 只挂载/解绑，不销毁外部实例。
2. 同时只允许一个 Widget；不同 Widget 重复挂载抛 StateError；同一 Widget 重建不重复订阅。
3. 更换 Controller 时先解绑旧实例再绑定新实例，旧实例通知不再影响当前图。
4. Widget 卸载停止绘制时钟、惯性、自动历史请求；Controller 仍可接收宿主推送。
5. dispose 幂等并使会话/挂载失效；宿主先卸载再销毁，已销毁实例再次挂载明确报错。
6. 销毁后 value 可读，主动导航/配置/监听抛 StateError，removeListener 安全；带旧令牌的
   迟到数据返回 ignoredStaleSession，不因页面关闭使网络回调崩溃。
7. 宿主回调抛异常按 Flutter 错误机制上报，不回滚已提交状态；同步回调中的新命令作为
   下一事务处理，不能产生半提交状态或递归重入通知。
   ValueListenable 不是逐事件日志：重入命令先提交完整快照，延后通知；本轮后续监听器
   可能读取到较新快照，连续重入通知可合并。命令回执仍固定为该命令提交时的数据版本。
   销毁后的 value 保留最后一份已提交快照（包括其挂载记录），实时销毁状态以 isDisposed 为准。
8. 交易操作仅发业务事件，绘图保存仅交付值对象/JSON；SDK 不下单、不访问账户或存储。

旧 KChartWidget、KLineEntity、DataUtil 与样式保留。正式 facade 使用根目录包装文件和
明确的 show 导出子集；准入前保持 allowlist。正式导出时同步 API diff、CHANGELOG、
迁移说明与 2.0 版本决策，发布另行执行。

## 8. 验收分工

| 阶段 | 必须交付 | 边界 |
| --- | --- | --- |
| OPT-02 | 本契约；编译探针；身份、令牌、挂载守卫测试；公共边界不变 | 守卫单测不等于真实 Controller / Widget 已接线 |
| OPT-03 | 数据命令、事务原子性、过期写入、重入与监听测试 | 不用测试替身代替真正实现 |
| OPT-04 | 双实例、换控制器、卸载、选中、缩放、空数据、历史加载 Widget 测试 | 宿主不接触 Painter / RenderSnapshot |
| OPT-05～10 | 细粒度更新、插件元数据、数据源生命周期与绘图扩展 | 完成前不承诺扩展稳定性 |
| OPT-12 | 正式入口独立宿主编译、迁移、平台/视觉门禁及真机 | 编译探针不能代替正式接入验收 |

关联：[优化计划](../KLINE_V2_SDK_OPTIMIZATION_PLAN.md)、[公共 API 策略](KLINE_V2_PUBLIC_API_POLICY.md)、
[ADR-001](ADR-001_PUBLIC_API_TRANSITION.md)、[历史 API 草案](../KLINE_V2_API_DRAFT.md)。
