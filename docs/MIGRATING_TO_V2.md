# 从 1.x 迁移到 V2 整改版

> 状态：2.x 兼容迁移指南
>
> 日期：2026-09-03

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

`example/` 的默认页面是中文 V2 交易图 Demo：默认请求 OKX 的公开 BTC-USDT 1 分钟线，网络不可用时使用确定性离线数据。它覆盖主图模式、主图/副图指标、叠加/分面板、数值格式、时区、十字光标、交易 Overlay 和独立深度图。

```bash
cd example
flutter run
```

Demo 是能力验证和产品参考，不是 `KChart`/`KChartController` 的公开使用示例；这些 Widget/Controller 尚未通过正式 API 准入。集成方应继续使用上述公开兼容面，并在公开 V2 Widget 发布后按新的主版本迁移说明切换。

## 6. 迁移检查表

- 入口改为 `package:m_k_chart/m_k_chart.dart`；
- 删除所有 `src`、Renderer 和 Example 支持文件的深路径 import；
- 旧 Widget 保持现有数据计算流程；
- 如需持久化偏好，改用 `KChartUserConfig` 并保存 `toJson()`；
- 如需新样式值对象，使用 `KChartTheme` 或 `ChartColorsThemeAdapter`；
- 在 Android/iOS/Web Profile/Release 上运行 Example，确认宿主格式化、存储和网络策略。

配套资料：[公共 API 差异](P9_PUBLIC_API_DIFF.md)、[主题协议](architecture/KLINE_V2_THEME_PROTOCOL.md)、[用户配置协议](architecture/KLINE_V2_USER_CONFIG_PROTOCOL.md)、[完整 Example 说明](architecture/KLINE_V2_EXAMPLE_TOOLBAR.md)。
