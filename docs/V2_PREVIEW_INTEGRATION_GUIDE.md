# V2 接入说明（2.0.0）

> **状态：适用于 `m_k_chart: ^2.0.0`。** 从唯一正式入口
> `package:m_k_chart/m_k_chart.dart` 导入 `KChart` / `KChartController` 及受控模型；不要依赖
> `src` 深路径。图表库不负责交易所网络、后台刷新或宿主持久化。

## 运行接入示例

在仓库根目录运行：

```bash
cd example
flutter run -t lib/v2_minimal_chart_main.dart
```

这个离线示例展示 Controller 创建/销毁、分钟线尾柱替换、下一根追加和选中回调。需要真实
行情、指标设置与绘图工具时，运行 `flutter run -t lib/v2_sdk_acceptance_main.dart`；验收页
默认不联网，点“Binance 实时”才发出公开行情请求。页面及完整样例实现见
[`v2_minimal_chart_main.dart`](../example/lib/v2_minimal_chart_main.dart) 和
[`v2_sdk_acceptance_main.dart`](../example/lib/v2_sdk_acceptance_main.dart)。

最小接线只从正式包入口导入。宿主把行情转换成 `Kline` 后创建 Controller；同一根未收盘柱
用 `updateKline`，下一根柱用 `appendData`，每次异步请求都沿用发起时捕获的 session：

```dart
import 'package:m_k_chart/m_k_chart.dart';

final controller = KChartController(
  series: series, // KlineSeries(symbol, interval, priceSource)
  initialData: initialCandles,
);
final session = controller.session;

// 行情源返回同一根 K 线的新快照：更新而非替换整窗。
controller.updateKline(latestCandle, session: session);

// 页面 build 中：
KChart(
  controller: controller,
  theme: KChartTheme.light(),
  onSelectionChanged: (selection) {},
  onIssue: (issue) {},
)

// 页面销毁时，先取消宿主请求/订阅，再释放控制器。
controller.dispose();
```

该片段的宿主类型检查由仓库编译探针
[`v2_candidate_host.dart`](../test/contracts/fixtures/v2_candidate_host.dart) 覆盖；它只导入
`package:m_k_chart/m_k_chart.dart`，也编译检查历史加载、指标、自定义指标、覆盖物和绘图 API。

## 宿主与图表的职责

| 宿主负责 | 图表负责 |
| --- | --- |
| 创建唯一的 `KChartController`，提供 `KlineSeries` 与初始 K 线 | 绘制主图/副图、指标、坐标轴与叠加层 |
| REST 首屏/历史分页、WebSocket 订阅、重连、取消和请求代际 | 管理视口、手势、选中状态和只读状态快照 |
| 将外部数据转换为同交易对、周期、价格类型的 `Kline` | 验证数据命令的会话和序列身份 |
| 创建/取消 Timer、订阅和网络请求；最终销毁 Controller | 组件卸载时停止自身显示时钟并解除挂载，不销毁宿主 Controller |
| 保存用户配置、绘图快照和业务订单 | 提供配置、绘图/覆盖物值对象与版本化快照协议 |

## 行情数据接线

1. 所有 `openTime` / `closeTime` 使用 **UTC epoch 毫秒**；同一窗口按 `openTime` 严格递增、
   不重复。`KlineSeries` 固定 symbol、interval 和 price source，不能从空列表推断身份。
2. 首屏 REST 完成后，以该序列建立 Controller。每个异步请求开始时保存当前
   `KChartDataSession`；响应返回时仍传回这个令牌，不能重新读取新 session 来“复活”旧响应。
3. REST/WebSocket 对未收盘的同一根 K 线用 `updateKline(candle, session:)`；出现严格更晚的
   开盘时间时用 `appendData([...], session:)`。新周期到来时按市场数据先闭合上一根，再追加；
   不要用全量重置代替每次尾柱更新，否则会丢失历史视口和选中状态。
4. 历史分页由宿主实现 `KChartHistoryLoader`。组件接近最旧边缘时请求上一页，响应必须属于
   发起时会话并严格早于当前首根，再调用前插路径；取消/换序列后丢弃迟到响应。
5. `KChartViewState` 通过只读监听读取；选中回调可以为 `null`。错误通过 issue 状态和宿主 UI
   呈现，网络错误不应回退成伪造的实时数据。

## 配置与生命周期

- `KChartOptions` 管理主图模式、面板、指标绑定和视口策略；`KChartTheme` 管颜色、线宽、数值
  格式和选中标签。不要在 Painter、Renderer 或全局单例中维护业务配置。
- 指标绑定以稳定的 `instanceId` 区分实例；更改周期时提交新的 `IndicatorConfig`，非法参数
  由定义校验并反馈为 issue。
- 图表放在父级给定的有限尺寸内。加载中/失败提示由宿主组合在图表之外；空窗口仍需提供明确
  的序列身份。
- 页面关闭时先取消行情订阅、请求和定时任务，再调用 `controller.dispose()`。仅移除 Widget
  不代表宿主请求自动取消。
- 绘图快照用 UTC 时间/价格锚点，不保存屏幕像素。宿主自行将 `ChartDrawingSnapshot` JSON
  写入数据库/文件；存储键应隔离数据源、symbol 和价格类型。示例内存存储只用于测试。

## 验证命令

```bash
# 仓库根目录：模型、状态、渲染、Widget、架构与快照
flutter test --no-pub
flutter analyze --no-pub

# Example 工程：Demo 自身测试和集成测试
cd example
flutter test --no-pub
flutter test integration_test/v2_minimal_chart_flow_test.dart -d <设备或模拟器ID>
flutter test integration_test/v2_sdk_acceptance_flow_test.dart -d <设备或模拟器ID>
```

Benchmark 用例属于 Host 参考数据，不等于设备帧率结论；Golden 更新必须先检查新图与差异，
不能为消除失败而无审查地覆盖基线。Android/iOS 真机或模拟器仍需验证图表交互、布局与 Profile
UI/Raster 性能；真实网络、断线重连和宿主后台数据刷新由接入方负责，不是库的发布验收门槛。当前证据及未完成项见
[设备验收记录](KLINE_V2_DEVICE_ACCEPTANCE.md)和[发布准备状态](V2_RELEASE_READINESS.md)。
