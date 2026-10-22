# 从 1.x 迁移到 V2 整改版

> 状态：m_k_chart 2.0.0 正式接入与 1.x 迁移指南
>
> 更新：2026-10-22

`m_k_chart` 2.0.0 已从唯一正式入口 `package:m_k_chart/m_k_chart.dart` 提供 V2 Widget、Controller
及其受控模型。V1 的 `KChartWidget`、实体和工具仍保留，现有项目可渐进迁移。所有新接入只依赖正式入口，
不要导入 `src` 深路径。

V2 组件的数据更新、生命周期和验证步骤整理在
[V2 接入说明](V2_PREVIEW_INTEGRATION_GUIDE.md)。示例均从正式包入口导入，仓库内编译探针
也会防止意外依赖 `src` 深路径。

## 1. 先保持现有图表可运行

`KChartWidget`、`KLineEntity`、`ChartStyle`、`ChartColors`、`MainState`、`SecondaryState` 和 `DataUtil` 在整个 2.x 周期继续可用。已有项目无需一次性重写图表：先将入口统一为 `package:m_k_chart/m_k_chart.dart`，再按需要采用主题和用户偏好协议。

```dart
// 旧入口仍可用，但会产生 deprecated 提示。
import 'package:m_k_chart/flutter_k_chart.dart';

// 建议改为唯一正式入口。
import 'package:m_k_chart/m_k_chart.dart';
```

不要导入 `package:m_k_chart/src/...`、`renderer/...` 或 `v2_example_support.dart`。这些仅供仓库内部和 Example 使用，不是稳定集成接口。

## 2. 旧图表继续使用的方式

原有数据计算与 Widget 用法保持不变：

```dart
DataUtil.calculate(data, chartStyle: chartStyle);

KChartWidget(
  data,
  mainState: MainState.ema,
  secondaryStates: const [SecondaryState.vol, SecondaryState.macd],
  chartStyle: chartStyle,
  chartColors: chartColors,
)
```

继续遵守旧链路的数据约束：数据按时间升序、计算后再交给 `KChartWidget`，实时追加用 `addLastData`，更新最后一根用 `updateLastData`。V2 整改不会改变这些兼容行为。

## 3. 先迁移主题，不迁移 Widget

新主题是公开的不可变值对象。它可以独立于旧 Widget 创建，或者从现有的旧配色生成；这让应用可以先统一颜色、主副图数值格式和十字光标样式，而无需依赖内部 Renderer。

```dart
final legacyTheme = chartColors.toKChartTheme(chartStyle: chartStyle);

final lightTheme = KChartTheme.light(
  mainValueDecimalPlaces: 2,
  mainValueUseThousandsSeparator: true,
  secondaryValueDecimalPlaces: 4,
  secondaryValueUseThousandsSeparator: false,
);
```

`KChartTheme` 的集合是不可修改的；需要调整时使用 `copyWith` 并替换整个值对象。主图和副图格式回调分别配置，不能共用一个回调假定两者量纲一致。

## 4. 迁移保存的用户偏好

将旧页面中的周期、线图开关和指标枚举保存为版本化 JSON。`KChartUserConfig.fromJson` 能直接读取无 `schemaVersion` 的旧 Demo shape：`period`、`isLine`、`mainState`、`secondaryStates` 和 `timeZoneOffsetHours` 会迁移为 schema v1。

```dart
final config = KChartUserConfig.fromJson(oldPreferences);

final storedJson = config.toJson();
// 使用应用自身的 SharedPreferences、数据库或服务端存储。
```

遇到更高 schema 版本或格式错误时，`fromJson` 会明确抛出异常，不会静默重置用户设置。应用应保留原始 JSON，提示用户升级或重置，而不是覆盖旧值。

## 5. 使用完整交易图 Demo 进行验证

`example/` 的默认页面是中文 V2 交易图 Demo：默认请求 Binance 的公开 BTCUSDT 1 分钟线，并每 2 秒以最新两根 K 线替换当前柱或追加新柱；网络不可用时使用确定性离线数据。它覆盖主图模式、主图/副图指标、叠加/分面板、数值格式、时区、十字光标、交易 Overlay 和独立深度图。

```bash
cd example
flutter run
```

默认 `flutter run` 启动的旧 Demo 用于验证完整交易功能；`v2_minimal_chart_main.dart` 与
`v2_sdk_acceptance_main.dart` 则是 `KChart`/`KChartController` 的正式入口接入示例。
这些 API 属于 2.0.0 正式兼容面；应用可通过 `m_k_chart: ^2.0.0` 接入。

## 6. V2 Widget 与 Controller 接入

[ADR-002：V2 Widget / Controller 接入契约](architecture/ADR-002_V2_SDK_FACADE_CONTRACT.md)
已明确新 KChart、Controller 数据所有权、会话令牌与生命周期。内部数据事务协调层和
异步历史分页、指标装配、配置/布局适配、内部 setOptions 与视口策略应用已实现；
只读状态、会话级覆盖物和 Controller 封装也已实现；几何计算不属于配置对象成员。
内部 Surface 已接通布局、绘制、手势、挂载生命周期、参数栏和信息面板，并由公开 `KChart`
包装管理显示时钟和宿主回调。独立[设备验收入口](KLINE_V2_DEVICE_ACCEPTANCE.md)可用于验证正式包中的接入流程。
指标绑定现可按实例设置 `visibleSeriesIds`，同一选择会控制绘制、量程和图例；null 表示
显示该指标允许的全部序列，MA 的旧第四路计算输出不在 V2 图表中提供。此配置尚无正式
持久化迁移承诺，不能直接写入既有 `KChartUserConfig` JSON 并假定可兼容恢复。
V2 新 API 已通过受控 allowlist 与只导入公开入口的编译探针；其稳定兼容承诺从 2.0.0 起生效。
生产应用应使用正式版本依赖，勿以 Git 分支源码替代稳定依赖；任何接入都不要新增 `src` 深路径引用。

## 7. 迁移检查表

- 入口改为 `package:m_k_chart/m_k_chart.dart`；
- 删除所有 `src`、Renderer 和 Example 支持文件的深路径 import；
- 旧 Widget 保持现有数据计算流程；
- 如需持久化偏好，改用 `KChartUserConfig` 并保存 `toJson()`；
- 如需新样式值对象，使用 `KChartTheme` 或 `ChartColorsThemeAdapter`；
- 在 Android/iOS/Web Profile/Release 上运行 Example，确认宿主格式化、存储和网络策略。

配套资料：[公共 API 差异](P9_PUBLIC_API_DIFF.md)、[主题协议](architecture/KLINE_V2_THEME_PROTOCOL.md)、[用户配置协议](architecture/KLINE_V2_USER_CONFIG_PROTOCOL.md)、[完整 Example 说明](architecture/KLINE_V2_EXAMPLE_TOOLBAR.md)。
