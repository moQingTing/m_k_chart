# V2 用户配置序列化协议

`KChartUserConfig` 是从 `package:m_k_chart/m_k_chart.dart` 导出的不可变值对象，用于让宿主保存和恢复图表偏好。组件不访问 SharedPreferences、文件、数据库或网络；宿主自行对 `toJson()` 的结果进行 `jsonEncode` 与持久化。

```dart
final saved = KChartUserConfig(
  instrumentId: 'BTC-USDT',
  intervalCode: '15m',
  mainMode: 'candlestick',
  timeZoneOffsetMinutes: 480,
  mainIndicators: [
    KChartIndicatorPreference(
      instanceId: 'ema-fast',
      definitionId: 'legacy.ema',
      parameters: {'period': 7},
    ),
  ],
);

final json = saved.toJson();
final restored = KChartUserConfig.fromJson(json);
```

## 当前 schema（v1）

- 交易对、周期代码、主图模式、时区偏移；
- 主图/副图的指标实例、参数和语义样式 key；
- 副图叠加策略、面板高度、指标参数标题高度与主副图区之间的时间带高度。

所有字段均是 JSON 安全的基础类型。`KChartIndicatorPreference` 只保存注册表可解析的 `definitionId` 和宿主选择的 `instanceId`，不持有 Renderer、Widget 或可变的指标缓存。

## 兼容迁移

未带 `schemaVersion` 的 v0 配置会自动迁移：

| v0 字段 | v1 字段 |
| --- | --- |
| `period` | `intervalCode` |
| `isLine` | `mainMode`（`line` 或 `candlestick`） |
| `mainState` | 一个 `legacy.*` 主图指标实例 |
| `secondaryStates` | 有序的 `legacy.*` 副图指标实例 |
| `timeZoneOffsetHours` | `timeZoneOffsetMinutes` |

高于当前版本的 schema 会抛出 `UnsupportedError`，避免旧组件静默丢弃新配置。格式错误、非有限数值和未知主图模式会明确失败；宿主可以保留原 JSON、提示用户重置，或在自己的迁移层中处理。

## 边界

该协议保存的是用户偏好，不保存 K 线数据、十字线瞬时选中状态、网络订阅、账户信息或绘图对象。绘图与交易 Overlay 在后续阶段拥有独立的版本化协议。
