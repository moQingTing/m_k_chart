import '../model/model.dart';
import 'indicator_cache.dart';
import 'indicator_config.dart';
import 'indicator_registry.dart';
import 'indicator_series.dart';

/// 单个指标实例在批量计算中被隔离后的失败信息。
final class IndicatorCalculationFailure {
  const IndicatorCalculationFailure({
    required this.config,
    required this.error,
    required this.stackTrace,
  });

  final IndicatorConfig config;
  final Object error;
  final StackTrace stackTrace;
}

/// 一次批量解析产生的不可变结果与失败集合。
final class IndicatorCalculationBatch {
  IndicatorCalculationBatch._(
    Map<String, IndicatorResult> results,
    Map<String, IndicatorCalculationFailure> failures,
  )   : results = Map.unmodifiable(results),
        failures = Map.unmodifiable(failures);

  final Map<String, IndicatorResult> results;
  final Map<String, IndicatorCalculationFailure> failures;

  bool get isSuccessful => failures.isEmpty;
  bool get hasFailures => failures.isNotEmpty;
  int get length => results.length + failures.length;
}

/// 组合指标注册表、缓存和失败隔离的实例级计算门面。
///
/// 每个图表应拥有自己的引擎，避免不同数据源、版本号或用户参数共享可变缓存。
final class IndicatorEngine {
  IndicatorEngine({
    IndicatorRegistry? registry,
    int maximumCacheEntries = 32,
  }) : registry = registry ?? IndicatorRegistry() {
    cache = IndicatorCache(
      this.registry,
      maximumEntries: maximumCacheEntries,
    );
  }

  final IndicatorRegistry registry;
  late final IndicatorCache cache;

  IndicatorResult resolve(
    VersionedKlineData input,
    IndicatorConfig config,
  ) =>
      cache.resolve(input, config);

  IndicatorCalculationBatch resolveAll(
    VersionedKlineData input,
    Iterable<IndicatorConfig> configs,
  ) {
    final immutableConfigs = List<IndicatorConfig>.unmodifiable(configs);
    final instanceIds = <String>{};
    for (final config in immutableConfigs) {
      if (!instanceIds.add(config.instanceId)) {
        throw ArgumentError.value(
          config.instanceId,
          'configs',
          'Indicator instance ids must be unique within a batch.',
        );
      }
    }

    // 单个指标异常不应阻断同一图表上的其他指标；失败由宿主决定如何展示或重试。
    final results = <String, IndicatorResult>{};
    final failures = <String, IndicatorCalculationFailure>{};
    for (final config in immutableConfigs) {
      try {
        results[config.instanceId] = cache.resolve(input, config);
      } on Object catch (error, stackTrace) {
        failures[config.instanceId] = IndicatorCalculationFailure(
          config: config,
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    return IndicatorCalculationBatch._(results, failures);
  }

  void clear() => cache.clear();
}
