part of 'kline_store.dart';

/// 单条 K 线序列的不可变、带版本视图。
///
/// [data] 以不可修改列表暴露；消费者应通过 [version] 判断是否需要重新计算或重绘，
/// 而不是比较整个集合。
final class KlineSnapshot implements VersionedKlineData {
  KlineSnapshot._(List<Kline> items, this.version)
      : data = UnmodifiableListView(items);

  @override
  final List<Kline> data;

  @override
  final KlineDataVersion version;

  int get length => data.length;
  bool get isEmpty => data.isEmpty;
  bool get isNotEmpty => data.isNotEmpty;
  Kline? get firstOrNull => isEmpty ? null : data.first;
  Kline? get lastOrNull => isEmpty ? null : data.last;

  Kline operator [](int index) => data[index];
}
