import '../data/kline_store.dart';
import '../model/model.dart';

/// 点击选中的稳定数据锚点；不保存列表下标或屏幕坐标。
///
/// 实时更新可改变 OHLC、索引和量程，但不能改变选中的序列及开盘时间。
/// [price] 是用户在命中面板选中的纵轴值（不一定等于该根 K 线的收盘价）。
/// 面板重排只改变几何；面板删除或拆分/合并改变身份，应取消选中。
final class ChartSelectionAnchor {
  ChartSelectionAnchor({
    required Kline candle,
    required this.panelId,
    required this.price,
  })  : symbol = candle.symbol,
        interval = candle.interval,
        priceSource = candle.priceSource,
        openTime = candle.openTime {
    if (panelId.isEmpty) throw ArgumentError.value(panelId, 'panelId');
    if (!price.isFinite) throw ArgumentError.value(price, 'price');
  }

  final String symbol;
  final KlineInterval interval;
  final KlinePriceSource priceSource;
  final int openTime;
  final String panelId;
  final double price;

  /// 在新的数据窗口中恢复索引；空窗口、裁剪、换序列或失效面板均返回 null。
  /// 调用方只应在数据/面板变化时解析，不必每个绘制帧重复扫描。
  int? resolveIndex(List<Kline> candles, {required Iterable<String> panelIds}) {
    if (!panelIds.contains(panelId)) return null;
    final index = candles.indexWhere(
      (candle) =>
          candle.symbol == symbol &&
          candle.interval == interval &&
          candle.priceSource == priceSource &&
          candle.openTime == openTime,
    );
    return index < 0 ? null : index;
  }

  /// Store 快照已保证单序列与严格时间升序，因此可二分恢复选中索引。
  /// 外部列表仍使用 [resolveIndex] 的通用线性查找语义。
  int? resolveIndexInSnapshot(
    KlineSnapshot snapshot, {
    required Iterable<String> panelIds,
  }) {
    if (!panelIds.contains(panelId)) return null;
    final index = snapshot.indexOfOpenTime(openTime);
    if (index < 0) return null;
    final candle = snapshot[index];
    if (candle.symbol != symbol ||
        candle.interval != interval ||
        candle.priceSource != priceSource) {
      return null;
    }
    return index;
  }
}
