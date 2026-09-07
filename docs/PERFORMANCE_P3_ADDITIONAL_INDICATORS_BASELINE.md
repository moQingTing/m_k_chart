# m_k_chart 2.0 Phase 3 新增指标性能基线

> 任务：P3-04  
> 日期：2026-08-25  
> 环境：macOS、Flutter 3.44.0、Flutter Test Host Debug

## 1. 数据与口径

- 确定性生成 10,000 根 BTCUSDT 一分钟 Kline。
- 同时计算 VWAP、ATR、CCI、DMI、ROC、Stoch RSI 六类指标。
- 全量计算预热 5 次、记录 20 个样本；末项更新预热 5 次、记录 50 个样本。
- 末项场景包含 Store 更新、变更检测、六指标增量计算、状态/Series 校验和缓存提交。
- 各指标另建 Store/Cache 记录 50 个末项样本；合计和单项均执行 P95 ≤ 8 ms 门禁。

## 2. 结果

| 场景 | P50 | P95 | P99 | 结论 |
| --- | ---: | ---: | ---: | --- |
| 六指标全量计算 | 8,355 μs | 10,516 μs | 10,516 μs | 历史/replace 路径基线 |
| Store + 六指标末项增量 | 846 μs | 1,689 μs | 2,380 μs | P95 ≤ 8 ms，通过 |

| 单指标末项更新 | P50 | P95 | 结论 |
| --- | ---: | ---: | --- |
| VWAP | 308 μs | 440 μs | 通过 |
| ATR | 294 μs | 509 μs | 通过 |
| CCI | 263 μs | 377 μs | 通过 |
| DMI | 370 μs | 551 μs | 通过 |
| ROC | 449 μs | 853 μs | 通过 |
| Stoch RSI | 383 μs | 709 μs | 通过 |

Host Debug 首次冷态运行出现过一次 P95 15,713 μs 的进程级抖动；同一基准完整复跑后为 1,689 μs。门禁基于预热后的最终完整样本，固定 CI/Profile 环境仍需在 Phase 5 复测，不能把 Host Debug 结果代替原生 UI/Raster 帧指标。

## 3. 公式与边界证据

- 平盘序列验证 VWAP、ATR、CCI、DMI、ROC、Stoch RSI 的零分母及有限值行为。
- 线性上涨序列解析验证 ATR=2、CCI=126.666...、+DI=50、-DI=0、ADX=100 和 ROC=120。
- 三点不同成交量序列手算验证累计 VWAP。
- append 和末项 update 对六类指标逐 Series 与新 Store 全量重算比较，容差 `1e-9`。

## 4. 复现

```bash
flutter test \
  --dart-define=RUN_ADDITIONAL_INDICATOR_BENCHMARK=true \
  test/benchmark/additional_indicator_engine_benchmark_test.dart
```

普通测试会跳过该基准，避免共享 CI 主机抖动造成非确定性失败。
