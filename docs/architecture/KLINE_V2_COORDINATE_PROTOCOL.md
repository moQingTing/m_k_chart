# K 线 2.0 坐标转换协议

> 任务：P4-02
> 状态：已实现
> 日期：2026-08-25

## 1. 坐标空间

新链路只使用图表实例自己的 local 坐标，不读取屏幕/global 坐标，也不依赖 Flutter `Offset`、`RenderBox` 或 legacy Painter。

| 空间 | 单位与方向 | 约定 |
| --- | --- | --- |
| data position | 连续数据槽 | 第 `i` 根占 `[i, i+1]`，中心为 `i+0.5` |
| local X | 逻辑像素，向右为正 | `0` 是当前图表可绘制区域左边界 |
| time | UTC epoch milliseconds | Kline `openTime`，不叠加展示时区 |
| local Y | 逻辑像素，向下为正 | `top`/`bottom` 均相对当前图表或 panel |
| price | double | `maxPrice → top`，`minPrice → bottom` |

## 2. X 轴仿射转换

`ChartXTransform` 使用 P4-01 的 Viewport：

```text
localX = (dataPosition - visibleLeftDataPosition) * itemExtent
dataPosition = visibleLeftDataPosition + localX / itemExtent
```

连续转换允许 Viewport 外的坐标，便于 Renderer 裁剪和手势外推。索引查询使用槽包含关系，坐标恰好落在槽边界时选择右侧/更新的数据；超出数据范围时约束到首尾索引。

Transform 接受 `VersionedKlineData` 稳定快照，并要求其长度与 `viewport.itemCount` 一致。构造时验证 `openTime` 严格递增，避免二分查找建立在错误输入上。

## 3. 时间转换

- 精确 `openTime` 映射到对应槽中心；
- 位于两根 Kline 之间的时间按两端实际 `openTime` 线性插值；
- 查找使用二分法，不假设固定 interval，因此缺失 Kline、停牌间隔和 calendar month 均可使用同一协议；
- 时间轴外的值约束到首尾中心；
- 逆变换使用相同区间插值并四舍五入到整数毫秒，往返误差目标不超过 1 ms；
- 空数据的时间或索引查询显式抛出 `StateError`。

显示时区只影响轴标签格式化，不改变存储和坐标使用的 UTC epoch。

## 4. 价格转换

`ChartPriceTransform` 接受非退化价格范围与 panel local 边界：

```text
localY = top + (maxPrice - price) / (maxPrice - minPrice) * height
price = maxPrice - (localY - top) / height * (maxPrice - minPrice)
```

价格和 Y 坐标允许超出可见范围并保持线性外推，由 Renderer 统一裁剪。`maxPrice <= minPrice` 或 `bottom <= top` 被拒绝；平盘数据的 padding 策略属于 P4-03 极值/Layout 输入，不在转换层隐式猜测。

## 5. 性质与边界

- data/local 往返误差：`≤ 1e-12`（测试样本）；
- time/local 往返误差：`≤ 1 ms`；
- price/local 往返误差：`≤ 1e-9`（测试样本）；
- 所有 double 输入必须有限；
- 转换对象不可变，不保存 mutable static 或 Widget 状态；
- P4-03 负责提供确定性的 panel `top/bottom` 和绘制宽度；
- P4-04/P4-05 使用本协议实现焦点缩放、选中和时间定位；
- P5 Renderer 只消费这些 local 结果，不再执行独立的坐标公式。

## 6. 验证

- 最新端、分数槽滚动和缩放后的 data/local 往返；
- 槽边界选择、首尾约束和无数据错误；
- 不规则时间间隔的二分查找、插值、端点约束和毫秒往返；
- 价格顶部/中点/底部映射、范围外外推和退化输入拒绝；
- viewport 模块无 Flutter、global coordinate 或 legacy Renderer 依赖。
