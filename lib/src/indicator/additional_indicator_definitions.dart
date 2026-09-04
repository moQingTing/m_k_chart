import 'dart:math' as math;

import '../model/model.dart';
import 'indicator_change.dart';
import 'indicator_config.dart';
import 'indicator_definition.dart';
import 'indicator_registry.dart';
import 'indicator_renderer_descriptor.dart';
import 'indicator_series.dart';

void registerAdditionalIndicatorDefinitions(IndicatorRegistry registry) {
  registry
    ..register(VwapIndicatorDefinition())
    ..register(AverageValueLineIndicatorDefinition())
    ..register(SuperTrendIndicatorDefinition())
    ..register(AtrIndicatorDefinition())
    ..register(CciIndicatorDefinition())
    ..register(DmiIndicatorDefinition())
    ..register(RocIndicatorDefinition())
    ..register(StochRsiIndicatorDefinition());
}

/// Average value line (AVL) for each Kline.
///
/// Binance supplies both quote and base turnover for every Kline, so
/// `quoteVolume / baseVolume` is that bar's actual average execution price.
/// Unlike VWAP, AVL must not accumulate the earlier bars; doing so produces a
/// slow anchor line rather than the price-following line shown in the chart.
final class AverageValueLineIndicatorDefinition
    implements IncrementalIndicatorDefinition {
  static const definitionId = 'builtin.avl';

  @override
  String get id => definitionId;

  @override
  IndicatorRendererDescriptor get rendererDescriptor => _lines(
        IndicatorPlacement.mainChart,
        const [('avl', 'AVL')],
      );

  @override
  IndicatorResult calculate(
    VersionedKlineData input,
    IndicatorConfig config,
  ) {
    return _result(this, input, config, [
      IndicatorSeries.takeOwnership(
        id: 'avl',
        values: [
          for (final item in input.data)
            item.baseVolume == 0 ? null : item.quoteVolume / item.baseVolume,
        ],
      ),
    ]);
  }

  @override
  bool supportsIncremental(IndicatorDataChange change) =>
      _supportsTailChange(change);

  @override
  IndicatorResult calculateIncrementally(
    VersionedKlineData input,
    IndicatorConfig config,
    IndicatorResult previous,
    IndicatorDataChange change,
  ) {
    final values = _buffer(previous.seriesById('avl')!.values, input);
    for (var index = change.currentStart; index < input.data.length; index++) {
      final item = input.data[index];
      values[index] =
          item.baseVolume == 0 ? null : item.quoteVolume / item.baseVolume;
    }
    return _result(this, input, config, [
      IndicatorSeries.takeOwnership(id: 'avl', values: values),
    ]);
  }
}

/// Supertrend overlay using Wilder ATR and trailing upper/lower bands.
///
/// The two output series intentionally break at a trend reversal so the
/// renderer does not draw a diagonal bridge between bullish and bearish legs.
final class SuperTrendIndicatorDefinition
    implements IncrementalIndicatorDefinition {
  static const definitionId = 'builtin.super';

  @override
  String get id => definitionId;

  @override
  IndicatorRendererDescriptor get rendererDescriptor =>
      IndicatorRendererDescriptor(
        placement: IndicatorPlacement.mainChart,
        series: [
          IndicatorSeriesDescriptor(
            id: 'up',
            label: 'SUPER↑',
            drawingKind: IndicatorDrawingKind.line,
            lineStyle: IndicatorLineStyle.stepped,
            lineStrokeWidthMultiplier: 0.8,
            areaBaseline: IndicatorAreaBaseline.candleClose,
            areaFillOpacity: 0.3,
          ),
          IndicatorSeriesDescriptor(
            id: 'down',
            label: 'SUPER↓',
            drawingKind: IndicatorDrawingKind.line,
            lineStyle: IndicatorLineStyle.stepped,
            lineStrokeWidthMultiplier: 0.8,
            areaBaseline: IndicatorAreaBaseline.candleClose,
            areaFillOpacity: 0.3,
          ),
        ],
      );

  @override
  IndicatorResult calculate(
    VersionedKlineData input,
    IndicatorConfig config,
  ) {
    final period = _positiveInt(config, 'period', 10);
    final multiplier = _positiveDouble(config, 'multiplier', 3);
    final state = _calculateSuperTrend(input.data, period, multiplier);
    return _statefulResult(this, input, config, [
      IndicatorSeries.takeOwnership(id: 'up', values: state.up),
      IndicatorSeries.takeOwnership(id: 'down', values: state.down),
    ], [
      IndicatorSeries.takeOwnership(id: 'atr', values: state.atr),
      IndicatorSeries.takeOwnership(id: 'upperBand', values: state.upperBand),
      IndicatorSeries.takeOwnership(id: 'lowerBand', values: state.lowerBand),
      IndicatorSeries.takeOwnership(id: 'isUpTrend', values: state.isUpTrend),
    ]);
  }

  @override
  bool supportsIncremental(IndicatorDataChange change) =>
      _supportsTailChange(change);

  @override
  IndicatorResult calculateIncrementally(
    VersionedKlineData input,
    IndicatorConfig config,
    IndicatorResult previous,
    IndicatorDataChange change,
  ) {
    final period = _positiveInt(config, 'period', 10);
    final multiplier = _positiveDouble(config, 'multiplier', 3);
    final firstReadyIndex = period - 1;
    if (change.currentStart <= firstReadyIndex) {
      return calculate(input, config);
    }

    final up = _buffer(previous.seriesById('up')!.values, input);
    final down = _buffer(previous.seriesById('down')!.values, input);
    final atr = _stateBuffer(previous, 'atr', input);
    final upperBand = _stateBuffer(previous, 'upperBand', input);
    final lowerBand = _stateBuffer(previous, 'lowerBand', input);
    final isUpTrend = _stateBuffer(previous, 'isUpTrend', input);

    for (var index = change.currentStart; index < input.data.length; index++) {
      atr[index] =
          (atr[index - 1]! * (period - 1) + _trueRange(input.data, index)) /
              period;
      _writeSuperTrend(
        input.data,
        index,
        multiplier,
        atr,
        upperBand,
        lowerBand,
        isUpTrend,
        up,
        down,
      );
    }
    return _statefulResult(this, input, config, [
      IndicatorSeries.takeOwnership(id: 'up', values: up),
      IndicatorSeries.takeOwnership(id: 'down', values: down),
    ], [
      IndicatorSeries.takeOwnership(id: 'atr', values: atr),
      IndicatorSeries.takeOwnership(id: 'upperBand', values: upperBand),
      IndicatorSeries.takeOwnership(id: 'lowerBand', values: lowerBand),
      IndicatorSeries.takeOwnership(id: 'isUpTrend', values: isUpTrend),
    ]);
  }
}

final class VwapIndicatorDefinition implements IncrementalIndicatorDefinition {
  static const definitionId = 'builtin.vwap';

  @override
  String get id => definitionId;

  @override
  IndicatorRendererDescriptor get rendererDescriptor => _lines(
        IndicatorPlacement.mainChart,
        const [('vwap', 'VWAP')],
      );

  @override
  IndicatorResult calculate(
    VersionedKlineData input,
    IndicatorConfig config,
  ) {
    final values = List<double?>.filled(input.data.length, null);
    final priceVolume = List<double?>.filled(input.data.length, 0);
    final volume = List<double?>.filled(input.data.length, 0);
    var cumulativePriceVolume = 0.0;
    var cumulativeVolume = 0.0;
    for (var index = 0; index < input.data.length; index++) {
      final item = input.data[index];
      cumulativePriceVolume +=
          (item.high + item.low + item.close) / 3 * item.baseVolume;
      cumulativeVolume += item.baseVolume;
      priceVolume[index] = cumulativePriceVolume;
      volume[index] = cumulativeVolume;
      values[index] = cumulativeVolume == 0
          ? null
          : cumulativePriceVolume / cumulativeVolume;
    }
    return _statefulResult(
      this,
      input,
      config,
      [IndicatorSeries.takeOwnership(id: 'vwap', values: values)],
      [
        IndicatorSeries.takeOwnership(id: 'priceVolume', values: priceVolume),
        IndicatorSeries.takeOwnership(id: 'volume', values: volume),
      ],
    );
  }

  @override
  bool supportsIncremental(IndicatorDataChange change) =>
      _supportsTailChange(change);

  @override
  IndicatorResult calculateIncrementally(
    VersionedKlineData input,
    IndicatorConfig config,
    IndicatorResult previous,
    IndicatorDataChange change,
  ) {
    final values = _buffer(previous.seriesById('vwap')!.values, input);
    final priceVolume = _stateBuffer(previous, 'priceVolume', input);
    final volume = _stateBuffer(previous, 'volume', input);
    for (var index = change.currentStart; index < input.data.length; index++) {
      final item = input.data[index];
      final priorPriceVolume = index == 0 ? 0.0 : priceVolume[index - 1]!;
      final priorVolume = index == 0 ? 0.0 : volume[index - 1]!;
      priceVolume[index] = priorPriceVolume +
          (item.high + item.low + item.close) / 3 * item.baseVolume;
      volume[index] = priorVolume + item.baseVolume;
      values[index] =
          volume[index] == 0 ? null : priceVolume[index]! / volume[index]!;
    }
    return _statefulResult(this, input, config, [
      IndicatorSeries.takeOwnership(id: 'vwap', values: values),
    ], [
      IndicatorSeries.takeOwnership(id: 'priceVolume', values: priceVolume),
      IndicatorSeries.takeOwnership(id: 'volume', values: volume),
    ]);
  }
}

final class AtrIndicatorDefinition implements IncrementalIndicatorDefinition {
  static const definitionId = 'builtin.atr';

  @override
  String get id => definitionId;

  @override
  IndicatorRendererDescriptor get rendererDescriptor => _lines(
        IndicatorPlacement.separatePanel,
        const [('atr', 'ATR')],
      );

  @override
  IndicatorResult calculate(
    VersionedKlineData input,
    IndicatorConfig config,
  ) {
    final period = _positiveInt(config, 'period', 14);
    final tr = _trueRanges(input.data);
    final atr = _wilderAverage(tr, period);
    return _result(this, input, config, [
      IndicatorSeries.takeOwnership(id: 'atr', values: atr),
    ]);
  }

  @override
  bool supportsIncremental(IndicatorDataChange change) =>
      _supportsTailChange(change);

  @override
  IndicatorResult calculateIncrementally(
    VersionedKlineData input,
    IndicatorConfig config,
    IndicatorResult previous,
    IndicatorDataChange change,
  ) {
    final period = _positiveInt(config, 'period', 14);
    if (change.currentStart < period) {
      return calculate(input, config);
    }
    final atr = _buffer(previous.seriesById('atr')!.values, input);
    for (var index = change.currentStart; index < input.data.length; index++) {
      final tr = _trueRange(input.data, index);
      atr[index] = (atr[index - 1]! * (period - 1) + tr) / period;
    }
    return _result(this, input, config, [
      IndicatorSeries.takeOwnership(id: 'atr', values: atr),
    ]);
  }
}

final class CciIndicatorDefinition implements IncrementalIndicatorDefinition {
  static const definitionId = 'builtin.cci';

  @override
  String get id => definitionId;

  @override
  IndicatorRendererDescriptor get rendererDescriptor => _lines(
        IndicatorPlacement.separatePanel,
        const [('cci', 'CCI')],
      );

  @override
  IndicatorResult calculate(
    VersionedKlineData input,
    IndicatorConfig config,
  ) {
    final period = _positiveInt(config, 'period', 20);
    final constant = _positiveDouble(config, 'constant', 0.015);
    final values = List<double?>.filled(input.data.length, null);
    for (var index = period - 1; index < input.data.length; index++) {
      values[index] = _cciAt(input.data, index, period, constant);
    }
    return _result(this, input, config, [
      IndicatorSeries.takeOwnership(id: 'cci', values: values),
    ]);
  }

  @override
  bool supportsIncremental(IndicatorDataChange change) =>
      _supportsTailChange(change);

  @override
  IndicatorResult calculateIncrementally(
    VersionedKlineData input,
    IndicatorConfig config,
    IndicatorResult previous,
    IndicatorDataChange change,
  ) {
    final period = _positiveInt(config, 'period', 20);
    final constant = _positiveDouble(config, 'constant', 0.015);
    final values = _buffer(previous.seriesById('cci')!.values, input);
    final end = math.min(input.data.length, change.currentEnd + period - 1);
    for (var index = change.currentStart; index < end; index++) {
      values[index] = index < period - 1
          ? null
          : _cciAt(input.data, index, period, constant);
    }
    return _result(this, input, config, [
      IndicatorSeries.takeOwnership(id: 'cci', values: values),
    ]);
  }
}

final class DmiIndicatorDefinition implements IncrementalIndicatorDefinition {
  static const definitionId = 'builtin.dmi';

  @override
  String get id => definitionId;

  @override
  IndicatorRendererDescriptor get rendererDescriptor => _lines(
        IndicatorPlacement.separatePanel,
        const [('plusDi', '+DI'), ('minusDi', '-DI'), ('adx', 'ADX')],
      );

  @override
  IndicatorResult calculate(
    VersionedKlineData input,
    IndicatorConfig config,
  ) {
    final period = _positiveInt(config, 'period', 14);
    final adxPeriod = _positiveInt(config, 'adxPeriod', 14);
    final length = input.data.length;
    final plusDi = List<double?>.filled(length, null);
    final minusDi = List<double?>.filled(length, null);
    final adx = List<double?>.filled(length, null);
    final smoothTr = List<double?>.filled(length, null);
    final smoothPlus = List<double?>.filled(length, null);
    final smoothMinus = List<double?>.filled(length, null);
    final dx = List<double?>.filled(length, null);
    if (length > period) {
      var trSum = 0.0;
      var plusSum = 0.0;
      var minusSum = 0.0;
      for (var index = 1; index <= period; index++) {
        trSum += _trueRange(input.data, index);
        final movement = _directionalMovement(input.data, index);
        plusSum += movement.$1;
        minusSum += movement.$2;
      }
      smoothTr[period] = trSum;
      smoothPlus[period] = plusSum;
      smoothMinus[period] = minusSum;
      _writeDirectional(period, trSum, plusSum, minusSum, plusDi, minusDi, dx);
      for (var index = period + 1; index < length; index++) {
        final movement = _directionalMovement(input.data, index);
        trSum = trSum - trSum / period + _trueRange(input.data, index);
        plusSum = plusSum - plusSum / period + movement.$1;
        minusSum = minusSum - minusSum / period + movement.$2;
        smoothTr[index] = trSum;
        smoothPlus[index] = plusSum;
        smoothMinus[index] = minusSum;
        _writeDirectional(
          index,
          trSum,
          plusSum,
          minusSum,
          plusDi,
          minusDi,
          dx,
        );
      }
      _writeAdx(dx, adx, period, adxPeriod);
    }
    return _statefulResult(this, input, config, [
      IndicatorSeries.takeOwnership(id: 'plusDi', values: plusDi),
      IndicatorSeries.takeOwnership(id: 'minusDi', values: minusDi),
      IndicatorSeries.takeOwnership(id: 'adx', values: adx),
    ], [
      IndicatorSeries.takeOwnership(id: 'smoothTr', values: smoothTr),
      IndicatorSeries.takeOwnership(id: 'smoothPlus', values: smoothPlus),
      IndicatorSeries.takeOwnership(id: 'smoothMinus', values: smoothMinus),
      IndicatorSeries.takeOwnership(id: 'dx', values: dx),
    ]);
  }

  @override
  bool supportsIncremental(IndicatorDataChange change) =>
      _supportsTailChange(change);

  @override
  IndicatorResult calculateIncrementally(
    VersionedKlineData input,
    IndicatorConfig config,
    IndicatorResult previous,
    IndicatorDataChange change,
  ) {
    final period = _positiveInt(config, 'period', 14);
    final adxPeriod = _positiveInt(config, 'adxPeriod', 14);
    if (change.currentStart <= period) {
      return calculate(input, config);
    }
    final plusDi = _buffer(previous.seriesById('plusDi')!.values, input);
    final minusDi = _buffer(previous.seriesById('minusDi')!.values, input);
    final adx = _buffer(previous.seriesById('adx')!.values, input);
    final smoothTr = _stateBuffer(previous, 'smoothTr', input);
    final smoothPlus = _stateBuffer(previous, 'smoothPlus', input);
    final smoothMinus = _stateBuffer(previous, 'smoothMinus', input);
    final dx = _stateBuffer(previous, 'dx', input);
    for (var index = change.currentStart; index < input.data.length; index++) {
      final movement = _directionalMovement(input.data, index);
      smoothTr[index] = smoothTr[index - 1]! -
          smoothTr[index - 1]! / period +
          _trueRange(input.data, index);
      smoothPlus[index] = smoothPlus[index - 1]! -
          smoothPlus[index - 1]! / period +
          movement.$1;
      smoothMinus[index] = smoothMinus[index - 1]! -
          smoothMinus[index - 1]! / period +
          movement.$2;
      _writeDirectional(
        index,
        smoothTr[index]!,
        smoothPlus[index]!,
        smoothMinus[index]!,
        plusDi,
        minusDi,
        dx,
      );
      final firstAdx = period + adxPeriod - 1;
      if (index == firstAdx) {
        var sum = 0.0;
        for (var cursor = period; cursor <= index; cursor++) {
          sum += dx[cursor]!;
        }
        adx[index] = sum / adxPeriod;
      } else if (index > firstAdx) {
        adx[index] =
            (adx[index - 1]! * (adxPeriod - 1) + dx[index]!) / adxPeriod;
      }
    }
    return _statefulResult(this, input, config, [
      IndicatorSeries.takeOwnership(id: 'plusDi', values: plusDi),
      IndicatorSeries.takeOwnership(id: 'minusDi', values: minusDi),
      IndicatorSeries.takeOwnership(id: 'adx', values: adx),
    ], [
      IndicatorSeries.takeOwnership(id: 'smoothTr', values: smoothTr),
      IndicatorSeries.takeOwnership(id: 'smoothPlus', values: smoothPlus),
      IndicatorSeries.takeOwnership(id: 'smoothMinus', values: smoothMinus),
      IndicatorSeries.takeOwnership(id: 'dx', values: dx),
    ]);
  }
}

final class RocIndicatorDefinition implements IncrementalIndicatorDefinition {
  static const definitionId = 'builtin.roc';

  @override
  String get id => definitionId;

  @override
  IndicatorRendererDescriptor get rendererDescriptor => _lines(
        IndicatorPlacement.separatePanel,
        const [('roc', 'ROC')],
      );

  @override
  IndicatorResult calculate(
    VersionedKlineData input,
    IndicatorConfig config,
  ) {
    final period = _positiveInt(config, 'period', 12);
    final values = List<double?>.filled(input.data.length, null);
    for (var index = period; index < input.data.length; index++) {
      values[index] = _rocAt(input.data, index, period);
    }
    return _result(this, input, config, [
      IndicatorSeries.takeOwnership(id: 'roc', values: values),
    ]);
  }

  @override
  bool supportsIncremental(IndicatorDataChange change) =>
      _supportsTailChange(change);

  @override
  IndicatorResult calculateIncrementally(
    VersionedKlineData input,
    IndicatorConfig config,
    IndicatorResult previous,
    IndicatorDataChange change,
  ) {
    final period = _positiveInt(config, 'period', 12);
    final values = _buffer(previous.seriesById('roc')!.values, input);
    final end = math.min(input.data.length, change.currentEnd + period);
    for (var index = change.currentStart; index < end; index++) {
      values[index] = index < period ? null : _rocAt(input.data, index, period);
    }
    return _result(this, input, config, [
      IndicatorSeries.takeOwnership(id: 'roc', values: values),
    ]);
  }
}

final class StochRsiIndicatorDefinition
    implements IncrementalIndicatorDefinition {
  static const definitionId = 'builtin.stochRsi';

  @override
  String get id => definitionId;

  @override
  IndicatorRendererDescriptor get rendererDescriptor => _lines(
        IndicatorPlacement.separatePanel,
        const [('k', '%K'), ('d', '%D')],
      );

  @override
  IndicatorResult calculate(
    VersionedKlineData input,
    IndicatorConfig config,
  ) {
    final rsiPeriod = _positiveInt(config, 'rsiPeriod', 14);
    final stochPeriod = _positiveInt(config, 'stochPeriod', 14);
    final kPeriod = _positiveInt(config, 'kPeriod', 3);
    final dPeriod = _positiveInt(config, 'dPeriod', 3);
    final state = _calculateStochState(
      input.data,
      rsiPeriod,
      stochPeriod,
      kPeriod,
      dPeriod,
    );
    return _statefulResult(this, input, config, [
      IndicatorSeries.takeOwnership(id: 'k', values: state.k),
      IndicatorSeries.takeOwnership(id: 'd', values: state.d),
    ], [
      IndicatorSeries.takeOwnership(id: 'rsi', values: state.rsi),
      IndicatorSeries.takeOwnership(id: 'avgGain', values: state.avgGain),
      IndicatorSeries.takeOwnership(id: 'avgLoss', values: state.avgLoss),
      IndicatorSeries.takeOwnership(id: 'raw', values: state.raw),
    ]);
  }

  @override
  bool supportsIncremental(IndicatorDataChange change) =>
      _supportsTailChange(change);

  @override
  IndicatorResult calculateIncrementally(
    VersionedKlineData input,
    IndicatorConfig config,
    IndicatorResult previous,
    IndicatorDataChange change,
  ) {
    final rsiPeriod = _positiveInt(config, 'rsiPeriod', 14);
    final stochPeriod = _positiveInt(config, 'stochPeriod', 14);
    final kPeriod = _positiveInt(config, 'kPeriod', 3);
    final dPeriod = _positiveInt(config, 'dPeriod', 3);
    if (change.currentStart <= rsiPeriod) {
      return calculate(input, config);
    }
    final k = _buffer(previous.seriesById('k')!.values, input);
    final d = _buffer(previous.seriesById('d')!.values, input);
    final rsi = _stateBuffer(previous, 'rsi', input);
    final avgGain = _stateBuffer(previous, 'avgGain', input);
    final avgLoss = _stateBuffer(previous, 'avgLoss', input);
    final raw = _stateBuffer(previous, 'raw', input);
    for (var index = change.currentStart; index < input.data.length; index++) {
      final difference = input.data[index].close - input.data[index - 1].close;
      avgGain[index] =
          (avgGain[index - 1]! * (rsiPeriod - 1) + math.max(0, difference)) /
              rsiPeriod;
      avgLoss[index] =
          (avgLoss[index - 1]! * (rsiPeriod - 1) + math.max(0, -difference)) /
              rsiPeriod;
      rsi[index] = _rsi(avgGain[index]!, avgLoss[index]!);
      raw[index] = index < rsiPeriod + stochPeriod - 1
          ? null
          : _stochasticRsiAt(rsi, index, stochPeriod);
      k[index] = _nullableAverage(raw, index, kPeriod);
      d[index] = _nullableAverage(k, index, dPeriod);
    }
    return _statefulResult(this, input, config, [
      IndicatorSeries.takeOwnership(id: 'k', values: k),
      IndicatorSeries.takeOwnership(id: 'd', values: d),
    ], [
      IndicatorSeries.takeOwnership(id: 'rsi', values: rsi),
      IndicatorSeries.takeOwnership(id: 'avgGain', values: avgGain),
      IndicatorSeries.takeOwnership(id: 'avgLoss', values: avgLoss),
      IndicatorSeries.takeOwnership(id: 'raw', values: raw),
    ]);
  }
}

final class _SuperTrendState {
  const _SuperTrendState({
    required this.up,
    required this.down,
    required this.atr,
    required this.upperBand,
    required this.lowerBand,
    required this.isUpTrend,
  });

  final List<double?> up;
  final List<double?> down;
  final List<double?> atr;
  final List<double?> upperBand;
  final List<double?> lowerBand;
  final List<double?> isUpTrend;
}

_SuperTrendState _calculateSuperTrend(
  List<Kline> data,
  int period,
  double multiplier,
) {
  final up = List<double?>.filled(data.length, null);
  final down = List<double?>.filled(data.length, null);
  final atr = _wilderAverage(_trueRanges(data), period);
  final upperBand = List<double?>.filled(data.length, null);
  final lowerBand = List<double?>.filled(data.length, null);
  final isUpTrend = List<double?>.filled(data.length, null);
  for (var index = period - 1; index < data.length; index++) {
    _writeSuperTrend(
      data,
      index,
      multiplier,
      atr,
      upperBand,
      lowerBand,
      isUpTrend,
      up,
      down,
    );
  }
  return _SuperTrendState(
    up: up,
    down: down,
    atr: atr,
    upperBand: upperBand,
    lowerBand: lowerBand,
    isUpTrend: isUpTrend,
  );
}

void _writeSuperTrend(
  List<Kline> data,
  int index,
  double multiplier,
  List<double?> atr,
  List<double?> upperBand,
  List<double?> lowerBand,
  List<double?> isUpTrend,
  List<double?> up,
  List<double?> down,
) {
  final item = data[index];
  final midpoint = (item.high + item.low) / 2;
  final basicUpperBand = midpoint + multiplier * atr[index]!;
  final basicLowerBand = midpoint - multiplier * atr[index]!;
  if (index == 0 || upperBand[index - 1] == null) {
    upperBand[index] = basicUpperBand;
    lowerBand[index] = basicLowerBand;
    isUpTrend[index] = 0;
    up[index] = null;
    down[index] = basicUpperBand;
    return;
  }

  final previous = data[index - 1];
  final previousUpperBand = upperBand[index - 1]!;
  final previousLowerBand = lowerBand[index - 1]!;
  upperBand[index] =
      basicUpperBand < previousUpperBand || previous.close > previousUpperBand
          ? basicUpperBand
          : previousUpperBand;
  lowerBand[index] =
      basicLowerBand > previousLowerBand || previous.close < previousLowerBand
          ? basicLowerBand
          : previousLowerBand;

  final previousIsUpTrend = isUpTrend[index - 1] == 1;
  final nextIsUpTrend = previousIsUpTrend
      ? item.close >= lowerBand[index]!
      : item.close > upperBand[index]!;
  isUpTrend[index] = nextIsUpTrend ? 1 : 0;
  up[index] = nextIsUpTrend ? lowerBand[index] : null;
  down[index] = nextIsUpTrend ? null : upperBand[index];
}

IndicatorRendererDescriptor _lines(
  IndicatorPlacement placement,
  List<(String, String)> definitions,
) =>
    IndicatorRendererDescriptor(
      placement: placement,
      series: definitions.map(
        (definition) => IndicatorSeriesDescriptor(
          id: definition.$1,
          label: definition.$2,
          drawingKind: IndicatorDrawingKind.line,
        ),
      ),
    );

IndicatorResult _result(
  IndicatorDefinition definition,
  VersionedKlineData input,
  IndicatorConfig config,
  Iterable<IndicatorSeries> series,
) =>
    IndicatorResult(
      instanceId: config.instanceId,
      definitionId: definition.id,
      dataVersion: input.version,
      length: input.data.length,
      series: series,
    );

IndicatorResult _statefulResult(
  IndicatorDefinition definition,
  VersionedKlineData input,
  IndicatorConfig config,
  Iterable<IndicatorSeries> series,
  Iterable<IndicatorSeries> state,
) =>
    IndicatorResult(
      instanceId: config.instanceId,
      definitionId: definition.id,
      dataVersion: input.version,
      length: input.data.length,
      series: series,
      computationState: IndicatorComputationState(
        length: input.data.length,
        series: state,
      ),
    );

bool _supportsTailChange(IndicatorDataChange change) =>
    (change.kind == IndicatorChangeKind.append ||
        change.kind == IndicatorChangeKind.update) &&
    change.preservedSuffixLength == 0;

IndicatorValueBuffer _buffer(List<double?> values, VersionedKlineData input) =>
    IndicatorValueBuffer.from(values, input.data.length);

IndicatorValueBuffer _stateBuffer(
  IndicatorResult previous,
  String id,
  VersionedKlineData input,
) =>
    _buffer(previous.computationState!.seriesById(id)!.values, input);

int _positiveInt(IndicatorConfig config, String key, int defaultValue) {
  final value = config.parameter(key) ?? defaultValue;
  if (value <= 0 || value.toInt() != value) {
    throw ArgumentError.value(value, key, 'Must be a positive integer.');
  }
  return value.toInt();
}

double _positiveDouble(
  IndicatorConfig config,
  String key,
  double defaultValue,
) {
  final value = (config.parameter(key) ?? defaultValue).toDouble();
  if (value <= 0) {
    throw ArgumentError.value(value, key, 'Must be positive.');
  }
  return value;
}

double _typicalPrice(Kline item) => (item.high + item.low + item.close) / 3;

double _trueRange(List<Kline> data, int index) {
  if (index == 0) {
    return data[index].high - data[index].low;
  }
  return math.max(
    data[index].high - data[index].low,
    math.max(
      (data[index].high - data[index - 1].close).abs(),
      (data[index].low - data[index - 1].close).abs(),
    ),
  );
}

List<double> _trueRanges(List<Kline> data) =>
    List<double>.generate(data.length, (index) => _trueRange(data, index));

List<double?> _wilderAverage(List<double> values, int period) {
  final output = List<double?>.filled(values.length, null);
  if (values.length < period) {
    return output;
  }
  var total = 0.0;
  for (var index = 0; index < period; index++) {
    total += values[index];
  }
  output[period - 1] = total / period;
  for (var index = period; index < values.length; index++) {
    output[index] =
        (output[index - 1]! * (period - 1) + values[index]) / period;
  }
  return output;
}

double _cciAt(List<Kline> data, int index, int period, double constant) {
  var average = 0.0;
  for (var cursor = index - period + 1; cursor <= index; cursor++) {
    average += _typicalPrice(data[cursor]);
  }
  average /= period;
  var deviation = 0.0;
  for (var cursor = index - period + 1; cursor <= index; cursor++) {
    deviation += (_typicalPrice(data[cursor]) - average).abs();
  }
  deviation /= period;
  return deviation == 0
      ? 0
      : (_typicalPrice(data[index]) - average) / (constant * deviation);
}

(double, double) _directionalMovement(List<Kline> data, int index) {
  final up = data[index].high - data[index - 1].high;
  final down = data[index - 1].low - data[index].low;
  return (up > down && up > 0 ? up : 0, down > up && down > 0 ? down : 0);
}

void _writeDirectional(
  int index,
  double tr,
  double plus,
  double minus,
  List<double?> plusDi,
  List<double?> minusDi,
  List<double?> dx,
) {
  plusDi[index] = tr == 0 ? 0 : 100 * plus / tr;
  minusDi[index] = tr == 0 ? 0 : 100 * minus / tr;
  final total = plusDi[index]! + minusDi[index]!;
  dx[index] =
      total == 0 ? 0 : 100 * (plusDi[index]! - minusDi[index]!).abs() / total;
}

void _writeAdx(
  List<double?> dx,
  List<double?> adx,
  int period,
  int adxPeriod,
) {
  final first = period + adxPeriod - 1;
  if (first >= dx.length) {
    return;
  }
  var sum = 0.0;
  for (var index = period; index <= first; index++) {
    sum += dx[index]!;
  }
  adx[first] = sum / adxPeriod;
  for (var index = first + 1; index < dx.length; index++) {
    adx[index] = (adx[index - 1]! * (adxPeriod - 1) + dx[index]!) / adxPeriod;
  }
}

double _rocAt(List<Kline> data, int index, int period) {
  final previous = data[index - period].close;
  return previous == 0 ? 0 : (data[index].close / previous - 1) * 100;
}

final class _StochState {
  const _StochState({
    required this.rsi,
    required this.avgGain,
    required this.avgLoss,
    required this.raw,
    required this.k,
    required this.d,
  });

  final List<double?> rsi;
  final List<double?> avgGain;
  final List<double?> avgLoss;
  final List<double?> raw;
  final List<double?> k;
  final List<double?> d;
}

_StochState _calculateStochState(
  List<Kline> data,
  int rsiPeriod,
  int stochPeriod,
  int kPeriod,
  int dPeriod,
) {
  final rsi = List<double?>.filled(data.length, null);
  final avgGain = List<double?>.filled(data.length, null);
  final avgLoss = List<double?>.filled(data.length, null);
  final raw = List<double?>.filled(data.length, null);
  final k = List<double?>.filled(data.length, null);
  final d = List<double?>.filled(data.length, null);
  if (data.length > rsiPeriod) {
    var gain = 0.0;
    var loss = 0.0;
    for (var index = 1; index <= rsiPeriod; index++) {
      final difference = data[index].close - data[index - 1].close;
      gain += math.max(0, difference);
      loss += math.max(0, -difference);
    }
    avgGain[rsiPeriod] = gain / rsiPeriod;
    avgLoss[rsiPeriod] = loss / rsiPeriod;
    rsi[rsiPeriod] = _rsi(avgGain[rsiPeriod]!, avgLoss[rsiPeriod]!);
    for (var index = rsiPeriod + 1; index < data.length; index++) {
      final difference = data[index].close - data[index - 1].close;
      avgGain[index] =
          (avgGain[index - 1]! * (rsiPeriod - 1) + math.max(0, difference)) /
              rsiPeriod;
      avgLoss[index] =
          (avgLoss[index - 1]! * (rsiPeriod - 1) + math.max(0, -difference)) /
              rsiPeriod;
      rsi[index] = _rsi(avgGain[index]!, avgLoss[index]!);
    }
    for (var index = rsiPeriod + stochPeriod - 1;
        index < data.length;
        index++) {
      raw[index] = _stochasticRsiAt(rsi, index, stochPeriod);
      k[index] = _nullableAverage(raw, index, kPeriod);
      d[index] = _nullableAverage(k, index, dPeriod);
    }
  }
  return _StochState(
    rsi: rsi,
    avgGain: avgGain,
    avgLoss: avgLoss,
    raw: raw,
    k: k,
    d: d,
  );
}

double _rsi(double averageGain, double averageLoss) {
  if (averageLoss == 0) {
    return averageGain == 0 ? 0 : 100;
  }
  return 100 - 100 / (1 + averageGain / averageLoss);
}

double _stochasticRsiAt(List<double?> rsi, int index, int period) {
  var lowest = double.maxFinite;
  var highest = -double.maxFinite;
  for (var cursor = index - period + 1; cursor <= index; cursor++) {
    lowest = math.min(lowest, rsi[cursor]!);
    highest = math.max(highest, rsi[cursor]!);
  }
  final range = highest - lowest;
  return range == 0 ? 0 : (rsi[index]! - lowest) / range * 100;
}

double? _nullableAverage(List<double?> values, int index, int period) {
  if (index < period - 1) {
    return null;
  }
  var total = 0.0;
  for (var cursor = index - period + 1; cursor <= index; cursor++) {
    final value = values[cursor];
    if (value == null) {
      return null;
    }
    total += value;
  }
  return total / period;
}
