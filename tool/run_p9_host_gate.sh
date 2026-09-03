#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"
flutter_bin="${FLUTTER_BIN:-flutter}"
device_id="${1:-}"

cd "$project_root"
"$flutter_bin" analyze --no-fatal-infos --no-fatal-warnings
"$flutter_bin" test
(
  cd example
  "$flutter_bin" test test
)

# Microbenchmarks intentionally run in separate processes. Running the files
# together lets flutter_test execute CPU-heavy suites concurrently and makes
# their latency budgets measure host contention instead of one chart pipeline.
"$flutter_bin" test \
  --dart-define=RUN_KLINE_STORE_BENCHMARK=true \
  test/benchmark/kline_store_benchmark_test.dart
"$flutter_bin" test \
  --dart-define=RUN_INDICATOR_ENGINE_BENCHMARK=true \
  test/benchmark/indicator_engine_benchmark_test.dart
"$flutter_bin" test \
  --dart-define=RUN_INDICATOR_CACHE_BENCHMARK=true \
  test/benchmark/indicator_cache_benchmark_test.dart
"$flutter_bin" test \
  --dart-define=RUN_ADDITIONAL_INDICATOR_BENCHMARK=true \
  test/benchmark/additional_indicator_engine_benchmark_test.dart
"$flutter_bin" test \
  --dart-define=RUN_LEGACY_INDICATOR_BENCHMARK=true \
  test/benchmark/legacy_indicator_engine_benchmark_test.dart
"$flutter_bin" test \
  --dart-define=RUN_KLINE_BENCHMARK=true \
  test/benchmark/current_architecture_benchmark_test.dart
"$flutter_bin" test \
  --dart-define=RUN_KLINE_BENCHMARK=true \
  test/benchmark/interaction_latency_benchmark_test.dart
"$flutter_bin" test \
  --dart-define=RUN_KLINE_BENCHMARK=true \
  test/benchmark/render_cache_benchmark_test.dart
"$flutter_bin" test \
  --dart-define=RUN_DEPTH_BENCHMARK=true \
  test/benchmark/depth_pipeline_benchmark_test.dart

if [[ -n "$device_id" ]]; then
  (
    cd example
    "$flutter_bin" test \
      integration_test/v2_chart_flow_test.dart \
      -d "$device_id"
  )
fi
