import 'dart:collection';

import '../model/model.dart';

part 'kline_snapshot.dart';

/// Owns immutable snapshots for a single symbol/interval/price-source series.
final class KlineStore {
  KlineStore()
      : _snapshot = KlineSnapshot._(
          const [],
          KlineDataVersion.zero,
        );

  KlineSnapshot _snapshot;

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
    final index = _indexOfOpenTime(value.openTime);
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

  int _indexOfOpenTime(int openTime) {
    var low = 0;
    var high = _snapshot.length - 1;
    while (low <= high) {
      final middle = low + ((high - low) >> 1);
      final candidate = _snapshot[middle].openTime;
      if (candidate == openTime) {
        return middle;
      }
      if (candidate < openTime) {
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }
    return -1;
  }
}

List<Kline> _join(List<Kline> first, List<Kline> second) {
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
