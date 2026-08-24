# m_k_chart 1.x 架构与行为基线

> 状态：Phase 0 基线
> 记录日期：2026-08-24
> 对应提交起点：`92ce808`

## 1. 目的

本文冻结 2.0 重构前的公共入口、核心行为、视觉样例、已知缺陷和构建状态。后续实现可以改变内部结构，但必须明确说明是否保持这些外部行为。

## 2. 公共入口

推荐入口：

```dart
import 'package:m_k_chart/m_k_chart.dart';
```

当前仍存在历史入口 `package:m_k_chart/flutter_k_chart.dart`，其导出内容与推荐入口不完全一致。2.0 应只保留一个正式入口，历史入口作为兼容转发。

当前公开导出：

| API | 类型 | 当前职责 | 2.0 策略 |
| --- | --- | --- | --- |
| `KChartWidget` | Widget | K 线渲染和手势 | 保留名称，新增 Controller API |
| `KChartWidgetState` | State | 内部视口和动画状态 | 不再作为公共控制入口 |
| `MainState` | enum | 主图指标选择 | deprecated，迁移到指标配置 |
| `SecondaryState` | enum | 副图指标选择 | deprecated，迁移到指标配置 |
| `ChartStyle` | mutable config | 几何、格式化和指标参数 | 兼容转发到不可变样式配置 |
| `ChartColors` | config/getters | 图表主题 | 兼容转发到 `KChartTheme` |
| `EMAConfig` | config | EMA 周期和颜色 | 迁移到通用指标配置 |
| `KLineEntity` | mutable model | 原始数据和全部指标结果 | deprecated，提供 adapter |
| `InfoWindowEntity` | model | 十字线弹窗数据 | 迁移到 selection state |
| `DepthEntity` | model | 深度价格和数量 | deprecated，提供 adapter |
| `DepthChart` | Widget | 深度图 | 保留功能，替换数据和 Controller |
| `DataUtil` | static utility | 原地计算所有指标 | deprecated，迁移到指标引擎 |
| `DateFormatUtil` | utility | 日期格式化 | 评估后收缩公共范围 |
| `NumberUtil` | utility | 数字格式化 | 评估后收缩公共范围 |

## 3. 当前核心行为

### K 线图

- 支持蜡烛和分时折线。
- 主图支持 MA、BOLL、EMA、SAR、无指标。
- 副图支持 MACD、KDJ、RSI、WR、VOL、OBV，可同时显示多个。
- 支持水平拖动、惯性、双指缩放和长按十字线。
- 支持最新价格线、最大最小价格和自定义详情 Widget。
- 数据为 `null` 时复位缩放和滚动；空列表不绘制数据。

### 深度图

- 同时要求非空 bids 和 asks。
- 左右各占一半宽度。
- 支持长按选择价格档位。
- 默认以传入列表首尾元素计算最大累计量。

### 指标计算

- 调用者必须先执行 `DataUtil.calculate()`。
- 指标结果原地写入 `KLineEntity`。
- `addLastData()` 追加并计算最后一项。
- `updateLastData()` 重算最后一项。
- `0` 同时被用作合法数值和“尚无指标结果”的哨兵。

## 4. 视觉基线

当前仓库视觉样例：

- `example/0d45c754e1d760926e2a97cdec01a464.jpg`，1080 × 2400。
- `example/39d489b40a933d2fa64ceec7b28997cf.jpg`，1080 × 2400。

Phase 3 开始前应将核心状态转换为自动化 Golden：蜡烛、分时、主图指标、多副图、十字线、明暗主题和横屏。

## 5. 已确认架构和正确性风险

| ID | 风险 | 归属架构问题 |
| --- | --- | --- |
| `BASE-R01` | 原始行情和指标结果混在可变实体中，并大量使用 `late`。 | `ARCH-01` |
| `BASE-R02` | `ChartPainter.maxScrollX` 是静态状态，多图表实例会互相影响。 | `ARCH-04` |
| `BASE-R03` | `shouldRepaint()` 恒为 true。 | `ARCH-05` |
| `BASE-R04` | Painter 在 `paint()` 中向 Widget 的 Stream 写入选择状态。 | `ARCH-03` |
| `BASE-R05` | 十字线使用 `globalPosition.dx`，不是图表局部坐标。 | `ARCH-06` |
| `BASE-R06` | 自定义手势识别器在 reject 后强制 accept。 | `ARCH-07` |
| `BASE-R07` | 垂直网格循环上限误用像素间距而不是 `gridColumns`。 | `ARCH-06` |
| `BASE-R08` | `mDataLen` 在 `mPointWidth` 赋值前计算。 | `ARCH-06` |
| `BASE-R09` | 指标选择通过 enum/switch 固化，新增指标要修改多层。 | `ARCH-08` |
| `BASE-R10` | 两个库入口导出不一致，内部工具已经暴露为公共 API。 | `ARCH-08` |
| `BASE-R11` | Widget State 同时管理手势、动画、滚动、选中和 UI 刷新。 | `ARCH-02` |

这些问题在 Phase 0 只记录不修改，避免在建立性能和视觉基线前改变行为。

## 6. 标准数据规模

测试使用 `test/support/kline_fixture.dart` 生成确定性数据：

- 100 根：单元测试和指标快照。
- 2,000 根：常用显示和帧性能。
- 10,000 根：实时更新、内存和指标计算压力测试。

生成器包含涨跌蜡烛、趋势变化和成交量变化，时间按一分钟递增。

## 7. 当前构建矩阵

| 平台 | 当前状态 | 最近验证 | 备注 |
| --- | --- | --- | --- |
| Android Debug | 通过 | 2026-08-24 | Flutter 3.44，APK 构建成功 |
| Android Release | 通过 | 2026-08-24 | APK 构建成功，主清单含联网权限 |
| iOS | 待验证 | — | Phase 0 需要模拟器或真机环境 |
| Web | 环境未启用 | 2026-08-24 | 当前 Flutter 环境未启用 Web |

## 8. 基线变更规则

- 指标快照变化必须说明是公式修复还是意外回归。
- 视觉变化必须通过 Golden 审核。
- 旧 API 行为变化必须加入迁移指南。
- 性能数字只允许在相同数据、设备和构建模式下比较。
