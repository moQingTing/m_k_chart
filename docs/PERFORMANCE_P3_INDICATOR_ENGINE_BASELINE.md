# m_k_chart 2.0 Phase 3 指标 Engine 多实例基线

> 任务：P3-05  
> 日期：2026-08-25  
> 环境：macOS、Flutter 3.44.0、Flutter Test Host Debug

## 1. 场景与口径

- 确定性生成 10,000 根 BTCUSDT 一分钟 Kline。
- 同时启用 MA、MACD、RSI、VOL、DMI、Stoch RSI 六个实例，覆盖主图、多 Series、副图和递归私有状态。
- 初次批量计算前后使用 `ProcessInfo.currentRss` 记录进程 RSS；它是粗略增量，不等同于对象 retained size。
- 末项更新预热 5 次、记录 100 个样本；每个样本包含 Store 更新、六实例变更检测、增量计算、校验、缓存提交和批次结果组装。

## 2. 结果

| 指标 | 结果 | 预算 | 结论 |
| --- | ---: | ---: | --- |
| 六实例 RSS 粗测增量 | 6,574,080 bytes（约 6.27 MiB） | ≤35 MiB | 通过 |
| 六实例末项更新 P50 | 1,021 μs | 记录 | 通过 |
| 六实例末项更新 P95 | 2,776 μs | ≤8,000 μs | 通过 |
| 六实例末项更新 P99 | 11,477 μs | 记录 | Host Debug 抖动，P95 门禁不受影响 |

RSS 口径只包含 Kline Store 已建立后的六指标初次结果增量；Phase 5 必须重新测量 10,000 根 Kline、六指标缓存和 Renderer/Picture/Text 缓存的综合内存。

## 3. 隔离与压力证据

- 同一 CCI 定义以 5/20 两个周期实例同时计算，结果不同且分别缓存命中。
- 一个批次同时注入正常 ROC、未知定义、主动抛错和 NaN 输出；正常结果保留，三个失败按 instanceId 独立返回。
- failure 不写缓存，再次调用会重新执行；成功实例直接命中缓存。
- 全部 16 个内置指标分别在 1 根短数据和 100 根平盘/零成交量输入下检查可绘制 Series 与私有状态，不存在 NaN/Infinity。
- 批次重复 instanceId 在开始计算前拒绝，避免部分缓存写入。

## 4. 复现

```bash
flutter test \
  --dart-define=RUN_INDICATOR_ENGINE_BENCHMARK=true \
  test/benchmark/indicator_engine_benchmark_test.dart
```

普通测试会跳过此基准，固定 CI/Profile 环境应在 Phase 5 复测。
