part of 'kline_store.dart';

/// Immutable, versioned view of one Kline series.
final class KlineSnapshot {
  KlineSnapshot._(List<Kline> items, this.version)
      : data = UnmodifiableListView(items);

  final List<Kline> data;
  final KlineDataVersion version;

  int get length => data.length;
  bool get isEmpty => data.isEmpty;
  bool get isNotEmpty => data.isNotEmpty;
  Kline? get firstOrNull => isEmpty ? null : data.first;
  Kline? get lastOrNull => isEmpty ? null : data.last;

  Kline operator [](int index) => data[index];
}
