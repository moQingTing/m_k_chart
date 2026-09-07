import '../model/model.dart';
import 'indicator_change.dart';
import 'indicator_config.dart';
import 'indicator_registry.dart';
import 'indicator_series.dart';

/// Immutable cache identity for one configured indicator calculation.
final class IndicatorCacheKey {
  IndicatorCacheKey._({
    required this.config,
    required this.dataVersion,
    required this.priceSource,
    required this.dataIdentity,
  });

  factory IndicatorCacheKey.from(
    VersionedKlineData input,
    IndicatorConfig config,
  ) =>
      IndicatorCacheKey._(
        config: config,
        dataVersion: input.version,
        priceSource: input.data.isEmpty ? null : input.data.first.priceSource,
        dataIdentity: input.data,
      );

  final IndicatorConfig config;
  final KlineDataVersion dataVersion;
  final KlinePriceSource? priceSource;

  /// Prevents equal version counters from independent stores colliding.
  final Object dataIdentity;

  String get definitionId => config.definitionId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IndicatorCacheKey &&
          config == other.config &&
          dataVersion == other.dataVersion &&
          priceSource == other.priceSource &&
          identical(dataIdentity, other.dataIdentity);

  @override
  int get hashCode => Object.hash(
        config,
        dataVersion,
        priceSource,
        identityHashCode(dataIdentity),
      );
}

/// Instance-owned bounded cache and incremental calculation coordinator.
final class IndicatorCache {
  IndicatorCache(this.registry, {this.maximumEntries = 32}) {
    if (maximumEntries <= 0) {
      throw ArgumentError.value(maximumEntries, 'maximumEntries');
    }
  }

  final IndicatorRegistry registry;
  final int maximumEntries;
  final Map<IndicatorCacheKey, _CacheEntry> _entries = {};

  int _cacheHits = 0;
  int _fullCalculations = 0;
  int _incrementalCalculations = 0;
  int _evictions = 0;

  int get length => _entries.length;
  int get cacheHits => _cacheHits;
  int get fullCalculations => _fullCalculations;
  int get incrementalCalculations => _incrementalCalculations;
  int get evictions => _evictions;

  IndicatorResult resolve(
    VersionedKlineData input,
    IndicatorConfig config,
  ) {
    final key = IndicatorCacheKey.from(input, config);
    final exact = _entries.remove(key);
    if (exact != null) {
      _entries[key] = exact;
      _cacheHits++;
      return exact.result;
    }

    final previous = _latestCompatibleEntry(input, config);
    late final IndicatorResult result;
    if (previous != null && input.version.isNewerThan(previous.input.version)) {
      final change = IndicatorDataChange.between(previous.input, input);
      if (change.kind == IndicatorChangeKind.unchanged) {
        result = _rebind(previous.result, input.version);
        _incrementalCalculations++;
      } else if (registry.supportsIncremental(config, change)) {
        result = registry.calculateIncrementally(
          input,
          config,
          previous.result,
          change,
        );
        _incrementalCalculations++;
      } else {
        result = registry.calculate(input, config);
        _fullCalculations++;
      }
    } else {
      result = registry.calculate(input, config);
      _fullCalculations++;
    }

    _entries[key] = _CacheEntry(input, result);
    _trim();
    return result;
  }

  void clear() => _entries.clear();

  _CacheEntry? _latestCompatibleEntry(
    VersionedKlineData input,
    IndicatorConfig config,
  ) {
    final currentSeries = _SeriesIdentity.from(input.data);
    _CacheEntry? latest;
    for (final entry in _entries.entries) {
      if (entry.key.config == config &&
          _SeriesIdentity.from(entry.value.input.data) == currentSeries &&
          entry.value.input.version.value < input.version.value &&
          (latest == null ||
              entry.value.input.version.isNewerThan(latest.input.version))) {
        latest = entry.value;
      }
    }
    return latest;
  }

  void _trim() {
    while (_entries.length > maximumEntries) {
      _entries.remove(_entries.keys.first);
      _evictions++;
    }
  }
}

final class _CacheEntry {
  const _CacheEntry(this.input, this.result);

  final VersionedKlineData input;
  final IndicatorResult result;
}

final class _SeriesIdentity {
  const _SeriesIdentity(this.symbol, this.interval, this.priceSource);

  factory _SeriesIdentity.from(List<Kline> data) => data.isEmpty
      ? const _SeriesIdentity(null, null, null)
      : _SeriesIdentity(
          data.first.symbol,
          data.first.interval,
          data.first.priceSource,
        );

  final String? symbol;
  final KlineInterval? interval;
  final KlinePriceSource? priceSource;

  @override
  bool operator ==(Object other) =>
      other is _SeriesIdentity &&
      symbol == other.symbol &&
      interval == other.interval &&
      priceSource == other.priceSource;

  @override
  int get hashCode => Object.hash(symbol, interval, priceSource);
}

IndicatorResult _rebind(
  IndicatorResult previous,
  KlineDataVersion dataVersion,
) =>
    IndicatorResult(
      instanceId: previous.instanceId,
      definitionId: previous.definitionId,
      dataVersion: dataVersion,
      length: previous.length,
      series: previous.series,
      computationState: previous.computationState,
    );
