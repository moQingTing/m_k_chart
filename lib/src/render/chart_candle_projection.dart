import 'dart:collection';
import 'dart:math' as math;

import '../model/model.dart';

/// 主图 K 线渲染器消费的不可变 OHLC 数值。
final class ChartRenderCandle {
  const ChartRenderCandle({
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  });

  final double open;
  final double high;
  final double low;
  final double close;
}

/// 对一个源 K 线快照和主图模式生成的不可变 K 线投射。
///
/// Heikin-Ashi 等派生模式只在此处转换 OHLC；数据仓库仍保存交易所原始 K 线，避免指标计算
/// 与真实成交数据脱节。
final class ChartCandleProjection {
  factory ChartCandleProjection.fromKlines({
    required List<Kline> source,
    required ChartMainMode mode,
  }) {
    // 普通模式只复制源引用以冻结快照，不为不可见 K 线预先创建渲染对象。
    // Heikin-Ashi 的 open 依赖前一根投射结果，必须沿完整历史顺序计算。
    final candles = mode.usesHeikinAshi
        ? UnmodifiableListView(_heikinAshi(source))
        : _RawCandleList(List<Kline>.of(source, growable: false));
    return ChartCandleProjection._(mode, candles);
  }

  const ChartCandleProjection._(this.mode, this.candles);

  final ChartMainMode mode;
  final List<ChartRenderCandle> candles;

  static List<ChartRenderCandle> _heikinAshi(List<Kline> source) {
    final projected = <ChartRenderCandle>[];
    for (final sourceCandle in source) {
      final close = (sourceCandle.open +
              sourceCandle.high +
              sourceCandle.low +
              sourceCandle.close) /
          4;
      final open = projected.isEmpty
          ? (sourceCandle.open + sourceCandle.close) / 2
          : (projected.last.open + projected.last.close) / 2;
      projected.add(
        ChartRenderCandle(
          open: open,
          high: math.max(sourceCandle.high, math.max(open, close)),
          low: math.min(sourceCandle.low, math.min(open, close)),
          close: close,
        ),
      );
    }
    return projected;
  }
}

/// 冻结原始 K 线列表，按索引仅投射实际读取的蜡烛。
///
/// 不能直接持有调用方列表：仓库切换或外部列表原地修改后，旧投射必须仍是旧快照。
final class _RawCandleList extends ListBase<ChartRenderCandle> {
  _RawCandleList(this._source);

  final List<Kline> _source;

  @override
  int get length => _source.length;

  @override
  set length(int value) => throw UnsupportedError('Immutable projection');

  @override
  ChartRenderCandle operator [](int index) {
    final item = _source[index];
    return ChartRenderCandle(
      open: item.open,
      high: item.high,
      low: item.low,
      close: item.close,
    );
  }

  @override
  void operator []=(int index, ChartRenderCandle value) =>
      throw UnsupportedError('Immutable projection');
}
