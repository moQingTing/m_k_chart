part of 'kline_store.dart';

/// 单条 K 线序列的不可变、带版本视图。
///
/// [data] 以不可修改列表暴露；消费者应通过 [version] 判断是否需要重新计算或重绘，
/// 而不是比较整个集合。
final class KlineSnapshot implements VersionedKlineData {
  KlineSnapshot._(List<Kline> items, this.version)
      : data = UnmodifiableListView(items);

  /// 沿用 Store 已验证的不可变窗口，仅更换协调器的全局版本号。
  ///
  /// 不重新包装或扫描数据；调用方不能传入自定义 [VersionedKlineData] 冒充已验证窗口。
  KlineSnapshot.withVersion(KlineSnapshot source, this.version)
      : data = source.data;

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

  /// 在已验证为严格时间升序的快照中查找开盘时间；不存在时返回 -1。
  int indexOfOpenTime(int openTime) {
    var low = 0;
    var high = length - 1;
    while (low <= high) {
      final middle = low + ((high - low) >> 1);
      final candidate = data[middle].openTime;
      if (candidate == openTime) return middle;
      if (candidate < openTime) {
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }
    return -1;
  }
}
