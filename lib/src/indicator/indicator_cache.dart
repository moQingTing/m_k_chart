import '../model/model.dart';
import 'indicator_change.dart';
import 'indicator_config.dart';
import 'indicator_registry.dart';
import 'indicator_series.dart';

/// 一次配置化指标计算的不可变缓存身份。
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

  /// 防止不同数据仓库中相同版本号发生缓存碰撞。
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

/// 实例私有的有界缓存与增量计算协调器。
///
/// 缓存键同时包含参数、数据版本、价格来源和数据列表身份。命中完全相同快照时直接复用；
/// 否则仅在数据版本前进且指标支持该变化类型时使用增量计算，保证计算正确性优先于缓存命中。
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
    // remove + put 将命中项移至末尾，Map 的插入顺序即为 LRU 访问顺序。
    final exact = _entries.remove(key);
    if (exact != null) {
      _entries[key] = exact;
      _cacheHits++;
      return exact.result;
    }

    final previous = _latestCompatibleEntry(input, config);
    late final IndicatorResult result;
    if (previous != null && input.version.isNewerThan(previous.input.version)) {
      // 先精确分类更新（追加、尾部替换、历史修正等），再决定能否安全增量计算。
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
    // 最早插入且最长时间未被访问的条目位于首位。
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
