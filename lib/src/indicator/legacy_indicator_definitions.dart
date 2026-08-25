import 'dart:math' as math;

import '../model/model.dart';
import 'indicator_change.dart';
import 'indicator_config.dart';
import 'indicator_definition.dart';
import 'indicator_registry.dart';
import 'indicator_renderer_descriptor.dart';
import 'indicator_series.dart';

/// Registers the ten indicator definitions supported by the 1.x renderer.
void registerLegacyIndicatorDefinitions(IndicatorRegistry registry) {
  registry
    ..register(MovingAverageIndicatorDefinition())
    ..register(ExponentialMovingAverageIndicatorDefinition())
    ..register(BollingerBandsIndicatorDefinition())
    ..register(ParabolicSarIndicatorDefinition())
    ..register(VolumeIndicatorDefinition())
    ..register(MacdIndicatorDefinition())
    ..register(KdjIndicatorDefinition())
    ..register(RsiIndicatorDefinition())
    ..register(WilliamsRIndicatorDefinition())
    ..register(ObvIndicatorDefinition());
}

final class MovingAverageIndicatorDefinition
    implements IncrementalIndicatorDefinition {
  static const definitionId = 'legacy.ma';
  static const _periods = [5, 10, 20, 30];

  @override
  String get id => definitionId;

  @override
  IndicatorRendererDescriptor get rendererDescriptor => _lines(
        IndicatorPlacement.mainChart,
        const [
          ('ma5', 'MA5'),
          ('ma10', 'MA10'),
          ('ma20', 'MA20'),
          ('ma30', 'MA30'),
        ],
      );

  @override
  IndicatorResult calculate(
    VersionedKlineData input,
    IndicatorConfig config,
  ) {
    final output = <IndicatorSeries>[];
    for (final period in _periods) {
      output.add(
        IndicatorSeries(
          id: 'ma$period',
          values: _simpleMovingAverage(
            input.data.map((item) => item.close).toList(growable: false),
            period,
          ),
        ),
      );
    }
    return _result(this, input, config, output);
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
    final output = <IndicatorSeries>[];
    for (final period in _periods) {
      final id = 'ma$period';
      final values =
          _resize(previous.seriesById(id)!.values, input.data.length);
      final end = math.min(
        input.data.length,
        change.currentEnd + period - 1,
      );
      for (var index = change.currentStart; index < end; index++) {
        values[index] = index < period - 1
            ? null
            : _averageClose(input.data, index - period + 1, index);
      }
      output.add(IndicatorSeries.takeOwnership(id: id, values: values));
    }
    return _result(this, input, config, output);
  }
}

final class ExponentialMovingAverageIndicatorDefinition
    implements IncrementalIndicatorDefinition {
  static const definitionId = 'legacy.ema';
  static const _periods = [5, 10, 30];

  @override
  String get id => definitionId;

  @override
  IndicatorRendererDescriptor get rendererDescriptor => _lines(
        IndicatorPlacement.mainChart,
        const [('ema5', 'EMA5'), ('ema10', 'EMA10'), ('ema30', 'EMA30')],
      );

  @override
  IndicatorResult calculate(
    VersionedKlineData input,
    IndicatorConfig config,
  ) {
    final output = <IndicatorSeries>[];
    for (final period in _periods) {
      final values = List<double?>.filled(input.data.length, null);
      var ema = 0.0;
      final multiplier = 2.0 / (period + 1);
      for (var index = 0; index < input.data.length; index++) {
        final close = input.data[index].close;
        ema = index == 0 ? close : close * multiplier + ema * (1 - multiplier);
        values[index] = ema;
      }
      output.add(
        IndicatorSeries.takeOwnership(id: 'ema$period', values: values),
      );
    }
    return _result(this, input, config, output);
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
    final output = <IndicatorSeries>[];
    for (final period in _periods) {
      final id = 'ema$period';
      final values =
          _resize(previous.seriesById(id)!.values, input.data.length);
      final multiplier = 2.0 / (period + 1);
      for (var index = change.currentStart;
          index < input.data.length;
          index++) {
        final close = input.data[index].close;
        values[index] = index == 0
            ? close
            : close * multiplier + values[index - 1]! * (1 - multiplier);
      }
      output.add(IndicatorSeries.takeOwnership(id: id, values: values));
    }
    return _result(this, input, config, output);
  }
}

final class BollingerBandsIndicatorDefinition
    implements IncrementalIndicatorDefinition {
  static const definitionId = 'legacy.boll';

  @override
  String get id => definitionId;

  @override
  IndicatorRendererDescriptor get rendererDescriptor => _lines(
        IndicatorPlacement.mainChart,
        const [('up', 'UP'), ('mb', 'MB'), ('dn', 'DN')],
      );

  @override
  IndicatorResult calculate(
    VersionedKlineData input,
    IndicatorConfig config,
  ) {
    final period = _positiveInt(config, 'period', 20);
    final multiplier = _positiveDouble(config, 'multiplier', 2);
    final closes = input.data.map((item) => item.close).toList(growable: false);
    final middle = _simpleMovingAverage(closes, period);
    final up = List<double?>.filled(closes.length, null);
    final down = List<double?>.filled(closes.length, null);
    for (var index = period - 1; index < closes.length; index++) {
      final mean = middle[index]!;
      var squaredDifference = 0.0;
      for (var offset = index - period + 1; offset <= index; offset++) {
        final difference = closes[offset] - mean;
        squaredDifference += difference * difference;
      }
      final deviation = math.sqrt(squaredDifference / period);
      up[index] = mean + multiplier * deviation;
      down[index] = mean - multiplier * deviation;
    }
    return _result(this, input, config, [
      IndicatorSeries.takeOwnership(id: 'up', values: up),
      IndicatorSeries.takeOwnership(id: 'mb', values: middle),
      IndicatorSeries.takeOwnership(id: 'dn', values: down),
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
    final multiplier = _positiveDouble(config, 'multiplier', 2);
    final up = _resize(previous.seriesById('up')!.values, input.data.length);
    final middle =
        _resize(previous.seriesById('mb')!.values, input.data.length);
    final down = _resize(previous.seriesById('dn')!.values, input.data.length);
    final end = math.min(
      input.data.length,
      change.currentEnd + period - 1,
    );
    for (var index = change.currentStart; index < end; index++) {
      if (index < period - 1) {
        up[index] = null;
        middle[index] = null;
        down[index] = null;
        continue;
      }
      final mean = _averageClose(input.data, index - period + 1, index);
      var squaredDifference = 0.0;
      for (var cursor = index - period + 1; cursor <= index; cursor++) {
        final difference = input.data[cursor].close - mean;
        squaredDifference += difference * difference;
      }
      final deviation = math.sqrt(squaredDifference / period);
      middle[index] = mean;
      up[index] = mean + multiplier * deviation;
      down[index] = mean - multiplier * deviation;
    }
    return _result(this, input, config, [
      IndicatorSeries.takeOwnership(id: 'up', values: up),
      IndicatorSeries.takeOwnership(id: 'mb', values: middle),
      IndicatorSeries.takeOwnership(id: 'dn', values: down),
    ]);
  }
}

final class ParabolicSarIndicatorDefinition
    implements IncrementalIndicatorDefinition {
  static const definitionId = 'legacy.sar';

  @override
  String get id => definitionId;

  @override
  IndicatorRendererDescriptor get rendererDescriptor =>
      IndicatorRendererDescriptor(
        placement: IndicatorPlacement.mainChart,
        series: [
          IndicatorSeriesDescriptor(
            id: 'sar',
            label: 'SAR',
            drawingKind: IndicatorDrawingKind.points,
          ),
        ],
      );

  @override
  IndicatorResult calculate(
    VersionedKlineData input,
    IndicatorConfig config,
  ) {
    final afStart = _positiveDouble(config, 'afStart', 0.02);
    final afIncrement = _positiveDouble(config, 'afIncrement', 0.02);
    final afMax = _positiveDouble(config, 'afMax', 0.2);
    if (afStart > afMax || afIncrement > afMax) {
      throw ArgumentError('SAR acceleration values must not exceed afMax.');
    }
    final data = input.data;
    final values = List<double?>.filled(data.length, null);
    if (data.length < 2) {
      return _result(this, input, config, [
        IndicatorSeries(id: 'sar', values: values),
      ]);
    }

    final trends = List<bool>.filled(data.length, true);
    final acceleration = List<double>.filled(data.length, afStart);
    final extremePoints = List<double>.filled(data.length, 0);
    var trend = data[1].close > data[0].close;
    var sar = trend ? data[0].low : data[0].high;
    var extremePoint = trend ? data[0].high : data[0].low;
    var factor = afStart;
    values[0] = sar;
    trends[0] = trend;
    acceleration[0] = factor;
    extremePoints[0] = extremePoint;

    for (var index = 1; index < data.length; index++) {
      final previous = data[index - 1];
      final previousSar = values[index - 1]!;
      final previousTrend = trends[index - 1];
      final previousFactor = acceleration[index - 1];
      final previousExtreme = extremePoints[index - 1];
      if (previousTrend) {
        sar = previousSar + previousFactor * (previous.high - previousSar);
        if (sar >= data[index].low) {
          trend = false;
          sar = previousExtreme;
          extremePoint = data[index].low;
          factor = afStart;
        } else {
          trend = true;
          final minimumLow = index >= 2
              ? math.min(data[index - 1].low, data[index - 2].low)
              : data[index - 1].low;
          sar = math.min(sar, minimumLow);
          if (data[index].high > previousExtreme) {
            extremePoint = data[index].high;
            factor = math.min(previousFactor + afIncrement, afMax);
          } else {
            extremePoint = previousExtreme;
            factor = previousFactor;
          }
        }
      } else {
        sar = previousSar + previousFactor * (previous.low - previousSar);
        if (sar <= data[index].high) {
          trend = true;
          sar = previousExtreme;
          extremePoint = data[index].high;
          factor = afStart;
        } else {
          trend = false;
          final maximumHigh = index >= 2
              ? math.max(data[index - 1].high, data[index - 2].high)
              : data[index - 1].high;
          sar = math.max(sar, maximumHigh);
          if (data[index].low < previousExtreme) {
            extremePoint = data[index].low;
            factor = math.min(previousFactor + afIncrement, afMax);
          } else {
            extremePoint = previousExtreme;
            factor = previousFactor;
          }
        }
      }
      values[index] = sar;
      trends[index] = trend;
      acceleration[index] = factor;
      extremePoints[index] = extremePoint;
    }
    return _result(
      this,
      input,
      config,
      [IndicatorSeries.takeOwnership(id: 'sar', values: values)],
      computationState: IndicatorComputationState(
        length: data.length,
        series: [
          IndicatorSeries(
            id: 'trend',
            values: trends.map((value) => value ? 1.0 : 0.0),
          ),
          IndicatorSeries(id: 'af', values: acceleration),
          IndicatorSeries(id: 'ep', values: extremePoints),
        ],
      ),
    );
  }

  @override
  bool supportsIncremental(IndicatorDataChange change) =>
      _supportsTailChange(change) && change.currentStart >= 2;

  @override
  IndicatorResult calculateIncrementally(
    VersionedKlineData input,
    IndicatorConfig config,
    IndicatorResult previous,
    IndicatorDataChange change,
  ) {
    final afStart = _positiveDouble(config, 'afStart', 0.02);
    final afIncrement = _positiveDouble(config, 'afIncrement', 0.02);
    final afMax = _positiveDouble(config, 'afMax', 0.2);
    final state = previous.computationState!;
    final sarValues =
        _resize(previous.seriesById('sar')!.values, input.data.length);
    final trends =
        _resize(state.seriesById('trend')!.values, input.data.length);
    final acceleration =
        _resize(state.seriesById('af')!.values, input.data.length);
    final extremePoints =
        _resize(state.seriesById('ep')!.values, input.data.length);

    for (var index = change.currentStart; index < input.data.length; index++) {
      final previousKline = input.data[index - 1];
      final previousSar = sarValues[index - 1]!;
      final previousTrend = trends[index - 1] == 1;
      final previousFactor = acceleration[index - 1]!;
      final previousExtreme = extremePoints[index - 1]!;
      late bool trend;
      late double sar;
      late double factor;
      late double extremePoint;
      if (previousTrend) {
        sar = previousSar + previousFactor * (previousKline.high - previousSar);
        if (sar >= input.data[index].low) {
          trend = false;
          sar = previousExtreme;
          extremePoint = input.data[index].low;
          factor = afStart;
        } else {
          trend = true;
          sar = math.min(
            sar,
            math.min(input.data[index - 1].low, input.data[index - 2].low),
          );
          if (input.data[index].high > previousExtreme) {
            extremePoint = input.data[index].high;
            factor = math.min(previousFactor + afIncrement, afMax);
          } else {
            extremePoint = previousExtreme;
            factor = previousFactor;
          }
        }
      } else {
        sar = previousSar + previousFactor * (previousKline.low - previousSar);
        if (sar <= input.data[index].high) {
          trend = true;
          sar = previousExtreme;
          extremePoint = input.data[index].high;
          factor = afStart;
        } else {
          trend = false;
          sar = math.max(
            sar,
            math.max(input.data[index - 1].high, input.data[index - 2].high),
          );
          if (input.data[index].low < previousExtreme) {
            extremePoint = input.data[index].low;
            factor = math.min(previousFactor + afIncrement, afMax);
          } else {
            extremePoint = previousExtreme;
            factor = previousFactor;
          }
        }
      }
      sarValues[index] = sar;
      trends[index] = trend ? 1 : 0;
      acceleration[index] = factor;
      extremePoints[index] = extremePoint;
    }
    return _result(
      this,
      input,
      config,
      [IndicatorSeries.takeOwnership(id: 'sar', values: sarValues)],
      computationState: IndicatorComputationState(
        length: input.data.length,
        series: [
          IndicatorSeries.takeOwnership(id: 'trend', values: trends),
          IndicatorSeries.takeOwnership(id: 'af', values: acceleration),
          IndicatorSeries.takeOwnership(id: 'ep', values: extremePoints),
        ],
      ),
    );
  }
}

final class VolumeIndicatorDefinition
    implements IncrementalIndicatorDefinition {
  static const definitionId = 'legacy.vol';

  @override
  String get id => definitionId;

  @override
  IndicatorRendererDescriptor get rendererDescriptor =>
      IndicatorRendererDescriptor(
        placement: IndicatorPlacement.separatePanel,
        includeZeroInRange: true,
        series: [
          IndicatorSeriesDescriptor(
            id: 'volume',
            label: 'VOL',
            drawingKind: IndicatorDrawingKind.histogram,
          ),
          IndicatorSeriesDescriptor(
            id: 'ma5',
            label: 'MA5',
            drawingKind: IndicatorDrawingKind.line,
          ),
          IndicatorSeriesDescriptor(
            id: 'ma10',
            label: 'MA10',
            drawingKind: IndicatorDrawingKind.line,
          ),
        ],
      );

  @override
  IndicatorResult calculate(
    VersionedKlineData input,
    IndicatorConfig config,
  ) {
    final volumes =
        input.data.map((item) => item.baseVolume).toList(growable: false);
    return _result(this, input, config, [
      IndicatorSeries(id: 'volume', values: volumes),
      IndicatorSeries(id: 'ma5', values: _simpleMovingAverage(volumes, 5)),
      IndicatorSeries(id: 'ma10', values: _simpleMovingAverage(volumes, 10)),
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
    final volume =
        _resize(previous.seriesById('volume')!.values, input.data.length);
    final ma5 = _resize(previous.seriesById('ma5')!.values, input.data.length);
    final ma10 =
        _resize(previous.seriesById('ma10')!.values, input.data.length);
    final end = math.min(input.data.length, change.currentEnd + 9);
    for (var index = change.currentStart; index < end; index++) {
      volume[index] = input.data[index].baseVolume;
      ma5[index] =
          index < 4 ? null : _averageVolume(input.data, index - 4, index);
      ma10[index] =
          index < 9 ? null : _averageVolume(input.data, index - 9, index);
    }
    return _result(this, input, config, [
      IndicatorSeries.takeOwnership(id: 'volume', values: volume),
      IndicatorSeries.takeOwnership(id: 'ma5', values: ma5),
      IndicatorSeries.takeOwnership(id: 'ma10', values: ma10),
    ]);
  }
}

final class MacdIndicatorDefinition implements IncrementalIndicatorDefinition {
  static const definitionId = 'legacy.macd';

  @override
  String get id => definitionId;

  @override
  IndicatorRendererDescriptor get rendererDescriptor =>
      IndicatorRendererDescriptor(
        placement: IndicatorPlacement.separatePanel,
        includeZeroInRange: true,
        series: [
          IndicatorSeriesDescriptor(
            id: 'macd',
            label: 'MACD',
            drawingKind: IndicatorDrawingKind.histogram,
          ),
          IndicatorSeriesDescriptor(
            id: 'dif',
            label: 'DIF',
            drawingKind: IndicatorDrawingKind.line,
          ),
          IndicatorSeriesDescriptor(
            id: 'dea',
            label: 'DEA',
            drawingKind: IndicatorDrawingKind.line,
          ),
        ],
      );

  @override
  IndicatorResult calculate(
    VersionedKlineData input,
    IndicatorConfig config,
  ) {
    final macd = List<double?>.filled(input.data.length, null);
    final difValues = List<double?>.filled(input.data.length, null);
    final deaValues = List<double?>.filled(input.data.length, null);
    var ema12 = 0.0;
    var ema26 = 0.0;
    var dea = 0.0;
    for (var index = 0; index < input.data.length; index++) {
      final close = input.data[index].close;
      if (index == 0) {
        ema12 = close;
        ema26 = close;
      } else {
        ema12 = ema12 * 11 / 13 + close * 2 / 13;
        ema26 = ema26 * 25 / 27 + close * 2 / 27;
      }
      final dif = ema12 - ema26;
      dea = dea * 8 / 10 + dif * 2 / 10;
      difValues[index] = dif;
      deaValues[index] = dea;
      macd[index] = (dif - dea) * 2;
    }
    return _result(
      this,
      input,
      config,
      [
        IndicatorSeries.takeOwnership(id: 'macd', values: macd),
        IndicatorSeries.takeOwnership(id: 'dif', values: difValues),
        IndicatorSeries.takeOwnership(id: 'dea', values: deaValues),
      ],
      computationState: IndicatorComputationState(
        length: input.data.length,
        series: [
          IndicatorSeries(id: 'ema12', values: _ema(input.data, 12)),
          IndicatorSeries(id: 'ema26', values: _ema(input.data, 26)),
        ],
      ),
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
    final macd =
        _resize(previous.seriesById('macd')!.values, input.data.length);
    final difValues =
        _resize(previous.seriesById('dif')!.values, input.data.length);
    final deaValues =
        _resize(previous.seriesById('dea')!.values, input.data.length);
    final ema12 = _resize(
      previous.computationState!.seriesById('ema12')!.values,
      input.data.length,
    );
    final ema26 = _resize(
      previous.computationState!.seriesById('ema26')!.values,
      input.data.length,
    );
    for (var index = change.currentStart; index < input.data.length; index++) {
      final close = input.data[index].close;
      if (index == 0) {
        ema12[index] = close;
        ema26[index] = close;
      } else {
        ema12[index] = ema12[index - 1]! * 11 / 13 + close * 2 / 13;
        ema26[index] = ema26[index - 1]! * 25 / 27 + close * 2 / 27;
      }
      final dif = ema12[index]! - ema26[index]!;
      final dea =
          (index == 0 ? 0 : deaValues[index - 1]!) * 8 / 10 + dif * 2 / 10;
      difValues[index] = dif;
      deaValues[index] = dea;
      macd[index] = (dif - dea) * 2;
    }
    return _result(
      this,
      input,
      config,
      [
        IndicatorSeries.takeOwnership(id: 'macd', values: macd),
        IndicatorSeries.takeOwnership(id: 'dif', values: difValues),
        IndicatorSeries.takeOwnership(id: 'dea', values: deaValues),
      ],
      computationState: IndicatorComputationState(
        length: input.data.length,
        series: [
          IndicatorSeries.takeOwnership(id: 'ema12', values: ema12),
          IndicatorSeries.takeOwnership(id: 'ema26', values: ema26),
        ],
      ),
    );
  }
}

final class KdjIndicatorDefinition implements IncrementalIndicatorDefinition {
  static const definitionId = 'legacy.kdj';

  @override
  String get id => definitionId;

  @override
  IndicatorRendererDescriptor get rendererDescriptor => _lines(
        IndicatorPlacement.separatePanel,
        const [('k', 'K'), ('d', 'D'), ('j', 'J')],
      );

  @override
  IndicatorResult calculate(
    VersionedKlineData input,
    IndicatorConfig config,
  ) {
    final period = _positiveInt(config, 'period', 14);
    final kValues = List<double?>.filled(input.data.length, null);
    final dValues = List<double?>.filled(input.data.length, null);
    final jValues = List<double?>.filled(input.data.length, null);
    final rawK = List<double?>.filled(input.data.length, null);
    final rawD = List<double?>.filled(input.data.length, null);
    var k = 0.0;
    var d = 0.0;
    for (var index = 0; index < input.data.length; index++) {
      final start = math.max(0, index - period + 1);
      var highest = -double.maxFinite;
      var lowest = double.maxFinite;
      for (var cursor = start; cursor <= index; cursor++) {
        highest = math.max(highest, input.data[cursor].high);
        lowest = math.min(lowest, input.data[cursor].low);
      }
      final range = highest - lowest;
      final rsv =
          range == 0 ? 0.0 : 100 * (input.data[index].close - lowest) / range;
      if (index == 0) {
        k = 50;
        d = 50;
      } else {
        k = (rsv + 2 * k) / 3;
        d = (k + 2 * d) / 3;
      }
      if (index >= period - 1) {
        kValues[index] = k;
        if (index >= period + 1) {
          dValues[index] = d;
          jValues[index] = 3 * k - 2 * d;
        }
      }
      rawK[index] = k;
      rawD[index] = d;
    }
    return _result(
      this,
      input,
      config,
      [
        IndicatorSeries.takeOwnership(id: 'k', values: kValues),
        IndicatorSeries.takeOwnership(id: 'd', values: dValues),
        IndicatorSeries.takeOwnership(id: 'j', values: jValues),
      ],
      computationState: IndicatorComputationState(
        length: input.data.length,
        series: [
          IndicatorSeries.takeOwnership(id: 'rawK', values: rawK),
          IndicatorSeries.takeOwnership(id: 'rawD', values: rawD),
        ],
      ),
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
    final period = _positiveInt(config, 'period', 14);
    final kValues =
        _resize(previous.seriesById('k')!.values, input.data.length);
    final dValues =
        _resize(previous.seriesById('d')!.values, input.data.length);
    final jValues =
        _resize(previous.seriesById('j')!.values, input.data.length);
    final rawK = _resize(
      previous.computationState!.seriesById('rawK')!.values,
      input.data.length,
    );
    final rawD = _resize(
      previous.computationState!.seriesById('rawD')!.values,
      input.data.length,
    );
    for (var index = change.currentStart; index < input.data.length; index++) {
      final start = math.max(0, index - period + 1);
      var highest = -double.maxFinite;
      var lowest = double.maxFinite;
      for (var cursor = start; cursor <= index; cursor++) {
        highest = math.max(highest, input.data[cursor].high);
        lowest = math.min(lowest, input.data[cursor].low);
      }
      final range = highest - lowest;
      final rsv =
          range == 0 ? 0.0 : 100 * (input.data[index].close - lowest) / range;
      final k = index == 0 ? 50.0 : (rsv + 2 * rawK[index - 1]!) / 3;
      final d = index == 0 ? 50.0 : (k + 2 * rawD[index - 1]!) / 3;
      rawK[index] = k;
      rawD[index] = d;
      kValues[index] = index >= period - 1 ? k : null;
      dValues[index] = index >= period + 1 ? d : null;
      jValues[index] = index >= period + 1 ? 3 * k - 2 * d : null;
    }
    return _result(
      this,
      input,
      config,
      [
        IndicatorSeries.takeOwnership(id: 'k', values: kValues),
        IndicatorSeries.takeOwnership(id: 'd', values: dValues),
        IndicatorSeries.takeOwnership(id: 'j', values: jValues),
      ],
      computationState: IndicatorComputationState(
        length: input.data.length,
        series: [
          IndicatorSeries.takeOwnership(id: 'rawK', values: rawK),
          IndicatorSeries.takeOwnership(id: 'rawD', values: rawD),
        ],
      ),
    );
  }
}

final class RsiIndicatorDefinition implements IncrementalIndicatorDefinition {
  static const definitionId = 'legacy.rsi';

  @override
  String get id => definitionId;

  @override
  IndicatorRendererDescriptor get rendererDescriptor => _lines(
        IndicatorPlacement.separatePanel,
        const [('rsi', 'RSI')],
      );

  @override
  IndicatorResult calculate(
    VersionedKlineData input,
    IndicatorConfig config,
  ) {
    final period = _positiveInt(config, 'period', 14);
    final values = List<double?>.filled(input.data.length, null);
    final absoluteValues = List<double?>.filled(input.data.length, 0);
    final maximumValues = List<double?>.filled(input.data.length, 0);
    var absoluteEma = 0.0;
    var maximumEma = 0.0;
    for (var index = 1; index < input.data.length; index++) {
      final difference = input.data[index].close - input.data[index - 1].close;
      maximumEma =
          (math.max(0, difference) + (period - 1) * maximumEma) / period;
      absoluteEma = (difference.abs() + (period - 1) * absoluteEma) / period;
      if (index >= period - 1) {
        values[index] = absoluteEma == 0 ? 0 : maximumEma / absoluteEma * 100;
      }
      absoluteValues[index] = absoluteEma;
      maximumValues[index] = maximumEma;
    }
    return _result(
      this,
      input,
      config,
      [IndicatorSeries.takeOwnership(id: 'rsi', values: values)],
      computationState: IndicatorComputationState(
        length: input.data.length,
        series: [
          IndicatorSeries.takeOwnership(
            id: 'absoluteEma',
            values: absoluteValues,
          ),
          IndicatorSeries.takeOwnership(
            id: 'maximumEma',
            values: maximumValues,
          ),
        ],
      ),
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
    final period = _positiveInt(config, 'period', 14);
    final values =
        _resize(previous.seriesById('rsi')!.values, input.data.length);
    final absoluteValues = _resize(
      previous.computationState!.seriesById('absoluteEma')!.values,
      input.data.length,
    );
    final maximumValues = _resize(
      previous.computationState!.seriesById('maximumEma')!.values,
      input.data.length,
    );
    for (var index = change.currentStart; index < input.data.length; index++) {
      if (index == 0) {
        absoluteValues[index] = 0;
        maximumValues[index] = 0;
        values[index] = null;
        continue;
      }
      final difference = input.data[index].close - input.data[index - 1].close;
      final maximumEma =
          (math.max(0, difference) + (period - 1) * maximumValues[index - 1]!) /
              period;
      final absoluteEma =
          (difference.abs() + (period - 1) * absoluteValues[index - 1]!) /
              period;
      maximumValues[index] = maximumEma;
      absoluteValues[index] = absoluteEma;
      values[index] = index < period - 1
          ? null
          : absoluteEma == 0
              ? 0
              : maximumEma / absoluteEma * 100;
    }
    return _result(
      this,
      input,
      config,
      [IndicatorSeries.takeOwnership(id: 'rsi', values: values)],
      computationState: IndicatorComputationState(
        length: input.data.length,
        series: [
          IndicatorSeries.takeOwnership(
            id: 'absoluteEma',
            values: absoluteValues,
          ),
          IndicatorSeries.takeOwnership(
            id: 'maximumEma',
            values: maximumValues,
          ),
        ],
      ),
    );
  }
}

final class WilliamsRIndicatorDefinition
    implements IncrementalIndicatorDefinition {
  static const definitionId = 'legacy.wr';

  @override
  String get id => definitionId;

  @override
  IndicatorRendererDescriptor get rendererDescriptor => _lines(
        IndicatorPlacement.separatePanel,
        const [('wr', 'WR')],
      );

  @override
  IndicatorResult calculate(
    VersionedKlineData input,
    IndicatorConfig config,
  ) {
    final declaredPeriod = _positiveInt(config, 'period', 14);
    final legacyWindow = declaredPeriod + 1;
    final values = List<double?>.filled(input.data.length, null);
    for (var index = declaredPeriod - 1; index < input.data.length; index++) {
      final start = math.max(0, index - legacyWindow + 1);
      var highest = -double.maxFinite;
      var lowest = double.maxFinite;
      for (var cursor = start; cursor <= index; cursor++) {
        highest = math.max(highest, input.data[cursor].high);
        lowest = math.min(lowest, input.data[cursor].low);
      }
      final range = highest - lowest;
      values[index] =
          range == 0 ? 0 : 100 * (highest - input.data[index].close) / range;
    }
    return _result(this, input, config, [
      IndicatorSeries.takeOwnership(id: 'wr', values: values),
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
    final declaredPeriod = _positiveInt(config, 'period', 14);
    final legacyWindow = declaredPeriod + 1;
    final values =
        _resize(previous.seriesById('wr')!.values, input.data.length);
    final end = math.min(
      input.data.length,
      change.currentEnd + legacyWindow - 1,
    );
    for (var index = change.currentStart; index < end; index++) {
      if (index < declaredPeriod - 1) {
        values[index] = null;
        continue;
      }
      final start = math.max(0, index - legacyWindow + 1);
      var highest = -double.maxFinite;
      var lowest = double.maxFinite;
      for (var cursor = start; cursor <= index; cursor++) {
        highest = math.max(highest, input.data[cursor].high);
        lowest = math.min(lowest, input.data[cursor].low);
      }
      final range = highest - lowest;
      values[index] =
          range == 0 ? 0 : 100 * (highest - input.data[index].close) / range;
    }
    return _result(this, input, config, [
      IndicatorSeries.takeOwnership(id: 'wr', values: values),
    ]);
  }
}

final class ObvIndicatorDefinition implements IncrementalIndicatorDefinition {
  static const definitionId = 'legacy.obv';

  @override
  String get id => definitionId;

  @override
  IndicatorRendererDescriptor get rendererDescriptor => _lines(
        IndicatorPlacement.separatePanel,
        const [('obv', 'OBV'), ('ma', 'MAOBV')],
      );

  @override
  IndicatorResult calculate(
    VersionedKlineData input,
    IndicatorConfig config,
  ) {
    final period = _positiveInt(config, 'period', 30);
    final obv = List<double?>.filled(input.data.length, null);
    var current = 0.0;
    for (var index = 0; index < input.data.length; index++) {
      if (index > 0) {
        final close = input.data[index].close;
        final previousClose = input.data[index - 1].close;
        if (close > previousClose) {
          current += input.data[index].baseVolume;
        } else if (close < previousClose) {
          current -= input.data[index].baseVolume;
        }
      }
      obv[index] = current;
    }
    final ma = _simpleMovingAverage(
      obv.map((value) => value!).toList(growable: false),
      period,
    );
    return _result(this, input, config, [
      IndicatorSeries.takeOwnership(id: 'obv', values: obv),
      IndicatorSeries.takeOwnership(id: 'ma', values: ma),
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
    final period = _positiveInt(config, 'period', 30);
    final obv = _resize(previous.seriesById('obv')!.values, input.data.length);
    final ma = _resize(previous.seriesById('ma')!.values, input.data.length);
    for (var index = change.currentStart; index < input.data.length; index++) {
      if (index == 0) {
        obv[index] = 0;
      } else {
        final close = input.data[index].close;
        final previousClose = input.data[index - 1].close;
        final previousObv = obv[index - 1]!;
        obv[index] = close > previousClose
            ? previousObv + input.data[index].baseVolume
            : close < previousClose
                ? previousObv - input.data[index].baseVolume
                : previousObv;
      }
    }
    final maStart = math.max(period - 1, change.currentStart);
    for (var index = maStart; index < input.data.length; index++) {
      var sum = 0.0;
      for (var cursor = index - period + 1; cursor <= index; cursor++) {
        sum += obv[cursor]!;
      }
      ma[index] = sum / period;
    }
    return _result(this, input, config, [
      IndicatorSeries.takeOwnership(id: 'obv', values: obv),
      IndicatorSeries.takeOwnership(id: 'ma', values: ma),
    ]);
  }
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
  Iterable<IndicatorSeries> series, {
  IndicatorComputationState? computationState,
}) {
  if (config.definitionId != definition.id) {
    throw ArgumentError('Config does not belong to ${definition.id}.');
  }
  return IndicatorResult(
    instanceId: config.instanceId,
    definitionId: definition.id,
    dataVersion: input.version,
    length: input.data.length,
    series: series,
    computationState: computationState,
  );
}

bool _supportsTailChange(IndicatorDataChange change) =>
    (change.kind == IndicatorChangeKind.append ||
        change.kind == IndicatorChangeKind.update) &&
    change.preservedSuffixLength == 0;

List<double?> _resize(List<double?> previous, int length) {
  return IndicatorValueBuffer.from(previous, length);
}

double _averageClose(List<Kline> data, int start, int end) {
  var sum = 0.0;
  for (var index = start; index <= end; index++) {
    sum += data[index].close;
  }
  return sum / (end - start + 1);
}

double _averageVolume(List<Kline> data, int start, int end) {
  var sum = 0.0;
  for (var index = start; index <= end; index++) {
    sum += data[index].baseVolume;
  }
  return sum / (end - start + 1);
}

List<double?> _ema(List<Kline> data, int period) {
  final values = List<double?>.filled(data.length, null);
  var current = 0.0;
  for (var index = 0; index < data.length; index++) {
    final close = data[index].close;
    current = index == 0
        ? close
        : current * (period - 1) / (period + 1) + close * 2 / (period + 1);
    values[index] = current;
  }
  return values;
}

List<double?> _simpleMovingAverage(List<double> values, int period) {
  final result = List<double?>.filled(values.length, null);
  var sum = 0.0;
  for (var index = 0; index < values.length; index++) {
    sum += values[index];
    if (index >= period) {
      sum -= values[index - period];
    }
    if (index >= period - 1) {
      result[index] = sum / period;
    }
  }
  return result;
}

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
