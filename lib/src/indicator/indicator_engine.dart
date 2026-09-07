import '../model/model.dart';
import 'indicator_cache.dart';
import 'indicator_config.dart';
import 'indicator_registry.dart';
import 'indicator_series.dart';

/// One isolated indicator instance failure from a batch calculation.
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

/// Immutable results and failures produced by one batch resolve.
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

/// Instance-owned calculation facade combining registry, cache, and isolation.
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
