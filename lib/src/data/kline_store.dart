import 'dart:collection';

import '../model/model.dart';

part 'kline_snapshot.dart';

/// 管理单一交易对/周期/价格来源序列的不可变快照。
///
/// [replace] 适用于历史全量同步；[prepend] 用于向左加载更早数据；[append] 用于新 K 线；
/// [update] 只替换同一开盘时间的正在形成 K 线。每次有效变更都会产生新的版本，供指标与
/// 渲染缓存精准失效。
final class KlineStore {
  KlineStore()
      : _snapshot = KlineSnapshot._(
          const [],
          KlineDataVersion.zero,
        );

  /// 为已验证的内部快照建立暂存事务，不再次复制并扫描整个旧窗口。
  ///
  /// 只供内部协调器传入由 Store 生成、且数据列表不可修改的快照。新收到的行情仍必须经过
  /// [replace]、[append]、[prepend] 或 [update] 校验；暂存 Store 的提交不修改原快照。
  KlineStore.stagedFromVerifiedSnapshot(VersionedKlineData source)
      : _snapshot = _requireVerifiedSnapshot(source);

  KlineSnapshot _snapshot;

  /// 当前稳定快照。请勿持有其可变副本并原地修改。
  KlineSnapshot get snapshot => _snapshot;

  KlineSnapshot replace(Iterable<Kline> values) {
    final next = List<Kline>.of(values, growable: false);
    _validateOrderedSeries(next);
    return _commitIfChanged(next);
  }

  KlineSnapshot prepend(Iterable<Kline> values) {
    final incoming = List<Kline>.of(values, growable: false);
    if (incoming.isEmpty) {
      return _snapshot;
    }
    _validateOrderedSeries(incoming);
    _validateSameSeries(incoming.first);
    final current = _snapshot.data;
    if (current.isNotEmpty &&
        incoming.last.openTime >= current.first.openTime) {
      throw ArgumentError(
        'Prepended Klines must end before the current first openTime.',
      );
    }

    final next = _join(incoming, current);
    return _commit(next);
  }

  KlineSnapshot append(Iterable<Kline> values) {
    final incoming = List<Kline>.of(values, growable: false);
    if (incoming.isEmpty) {
      return _snapshot;
    }
    _validateOrderedSeries(incoming);
    _validateSameSeries(incoming.first);
    final current = _snapshot.data;
    if (current.isNotEmpty &&
        incoming.first.openTime <= current.last.openTime) {
      throw ArgumentError(
        'Appended Klines must start after the current last openTime.',
      );
    }

    final next = _join(current, incoming);
    return _commit(next);
  }

  KlineSnapshot update(Kline value) {
    if (_snapshot.isEmpty) {
      throw StateError('Cannot update an empty KlineStore.');
    }
    _validateSameSeries(value);
    final index = _snapshot.indexOfOpenTime(value.openTime);
    if (index < 0) {
      throw StateError(
        'No Kline exists at openTime ${value.openTime}.',
      );
    }
    if (_snapshot[index] == value) {
      return _snapshot;
    }

    final next = List<Kline>.of(_snapshot.data, growable: false);
    next[index] = value;
    return _commit(next);
  }

  KlineSnapshot _commitIfChanged(List<Kline> next) {
    if (_listEquals(_snapshot.data, next)) {
      return _snapshot;
    }
    return _commit(next);
  }

  KlineSnapshot _commit(List<Kline> next) {
    // 版本只在数据真实变化时递增；这是增量指标计算与渲染缓存的失效依据。
    _snapshot = KlineSnapshot._(next, _snapshot.version.next());
    return _snapshot;
  }

  void _validateOrderedSeries(List<Kline> values) {
    if (values.isEmpty) {
      return;
    }
    final first = values.first;
    for (var index = 1; index < values.length; index++) {
      final previous = values[index - 1];
      final current = values[index];
      if (!first.hasSameSeries(current)) {
        throw ArgumentError('A KlineStore can contain only one series.');
      }
      if (current.openTime <= previous.openTime) {
        throw ArgumentError(
          'Klines must be strictly ordered by unique openTime.',
        );
      }
    }
  }

  void _validateSameSeries(Kline value) {
    final current = _snapshot.firstOrNull;
    if (current != null && !current.hasSameSeries(value)) {
      throw ArgumentError('Kline does not belong to the current series.');
    }
  }
}

KlineSnapshot _requireVerifiedSnapshot(VersionedKlineData source) {
  // UnmodifiableListView 本身不能证明有序：外部可把可变底层列表包成只读视图。
  if (source is! KlineSnapshot) {
    throw ArgumentError('Staged Kline data must be a verified Store snapshot.');
  }
  return source;
}

List<Kline> _join(List<Kline> first, List<Kline> second) {
  // 预分配不可增长列表，避免拼接时产生多余的中间集合。
  final result = List<Kline>.filled(
    first.length + second.length,
    first.isNotEmpty ? first.first : second.first,
    growable: false,
  );
  result.setRange(0, first.length, first);
  result.setRange(first.length, result.length, second);
  return result;
}

bool _listEquals(List<Kline> first, List<Kline> second) {
  if (identical(first, second)) {
    return true;
  }
  if (first.length != second.length) {
    return false;
  }
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) {
      return false;
    }
  }
  return true;
}
