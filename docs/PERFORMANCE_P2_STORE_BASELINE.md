# m_k_chart 2.0 Phase 2 Store 性能基线

> 任务：P2-06  
> 日期：2026-08-24  
> 环境：macOS 26.5.1、x86_64、Flutter 3.44.0、Flutter Test Host Debug

## 1. 数据与口径

- 确定性生成 10,000 根 BTCUSDT 一分钟不可变 Kline。
- 每个耗时场景预热 5 次；replace/prepend/append 记录 30 个样本，update 记录 100 个样本。
- 时间使用 Stopwatch 微秒；P95 采用排序后向上取整索引。
- prepend/append 样本保守地包含新建 Store 和 9,000 根初始 replace，再执行 1,000 根历史合并。
- RSS 使用 `ProcessInfo.currentRss` 在同一 Flutter Test 进程前后读取，只作为当前主机粗略增量基线，不等同于对象精确 retained size。

## 2. 结果

| 场景 | P50 | P95 | P99 | 预算/结论 |
| --- | ---: | ---: | ---: | --- |
| replace 10,000 | 211 μs | 1,726 μs | 2,345 μs | 记录基线 |
| prepend 1,000 → 9,000 | 317 μs | 955 μs | 1,381 μs | ≤ 50 ms，通过 |
| append 1,000 → 9,000 | 355 μs | 546 μs | 934 μs | ≤ 50 ms，通过 |
| update last of 10,000 | 259 μs | 656 μs | 1,936 μs | Store 部分低于 8 ms，通过 |

RSS：139,337,728 → 141,049,856 bytes，增量 1,712,128 bytes（约 1.63 MiB），低于 10,000 根 + 指标综合目标 35 MB。指标缓存尚未加入，Phase 3/5 必须重新测量综合内存，不能用本结果替代最终门禁。

## 3. 异常输入与幂等证据

- 模型拒绝空 symbol、时间倒序、NaN/Infinity、非法 OHLC、负成交量/笔数、无序交易 ID 和非法时区。
- Store 拒绝乱序、重复、跨序列、范围重叠和不存在的 update。
- Coordinator 对 duplicate/stale/closed/outside-window/different-series 保持原快照和版本。
- Binance Adapter 拒绝错误 tuple、错误事件类型、symbol 不一致、未知周期和非法数值。
- legacy 秒转换拒绝无法整除 1000 的毫秒时间，避免静默精度丢失。

## 4. 复现

```bash
flutter test \
  --dart-define=RUN_KLINE_STORE_BENCHMARK=true \
  test/benchmark/kline_store_benchmark_test.dart
```

正常 `flutter test` 会跳过该 benchmark，避免 CI 主机抖动造成非确定性失败。正式发布前应在固定 CI/设备 Profile 环境复测并对比本基线。
