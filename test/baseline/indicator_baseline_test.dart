import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/m_k_chart.dart';

import '../support/kline_fixture.dart';

const _tolerance = 1e-9;

void main() {
  group('current indicator baseline', () {
    late List<KLineEntity> data;

    setUp(() {
      data = buildKlineFixture(100);
      _calculate(data);
    });

    test('matches the frozen values at index 29', () {
      _expectSnapshot(
        data[29],
        const _IndicatorSnapshot(
          ma5: 1007.1779999999999,
          ma10: 1007.9410000000001,
          ma20: 1007.4139999999994,
          ma30: 1004.5513333333332,
          bollUp: 1012.6003798549657,
          bollMb: 1007.4139999999994,
          bollDn: 1002.2276201450331,
          ema5: 1007.4702312213207,
          ema10: 1007.4082342223485,
          ema30: 1004.7668656987541,
          sar: 1013.2302742130239,
          volMa5: 1375.9000000000003,
          volMa10: 1239.15,
          macd: -1.0766749768140649,
          dif: 1.9214231384640925,
          dea: 2.459760626871125,
          k: 44.756847687108255,
          d: 46.74192987026435,
          j: 40.78668332079606,
          rsi: 58.808806914117916,
          wr: 50.760135135134924,
          obv: 22513.300000000007,
          maObv: 12219.536666666669,
        ),
      );
    });

    test('matches the frozen values at index 59', () {
      _expectSnapshot(
        data[59],
        const _IndicatorSnapshot(
          ma5: 1020.9159999999993,
          ma10: 1019.0530000000002,
          ma20: 1018.0544999999995,
          ma30: 1016.3596666666667,
          bollUp: 1023.5155236219957,
          bollMb: 1018.0544999999995,
          bollDn: 1012.5934763780033,
          ema5: 1020.9682207173753,
          ema10: 1019.614319760608,
          ema30: 1016.0131609325858,
          sar: 1013.3736878976,
          volMa5: 1214.900000000001,
          volMa10: 1168.25,
          macd: 0.4448587236101762,
          dif: 2.4942633736230846,
          dea: 2.2718340118179965,
          k: 80.24026121963055,
          d: 72.4271186794346,
          j: 95.86654630002246,
          rsi: 68.432231029768,
          wr: 13.099771515613199,
          obv: 47851.60000000001,
          maObv: 36657.27666666668,
        ),
      );
    });

    test('matches the frozen values at index 99', () {
      _expectSnapshot(
        data[99],
        const _IndicatorSnapshot(
          ma5: 1033.4879999999991,
          ma10: 1033.3080000000004,
          ma20: 1033.2524999999998,
          ma30: 1030.5469999999998,
          bollUp: 1038.37420235371,
          bollMb: 1033.2524999999998,
          bollDn: 1028.1307976462897,
          ema5: 1033.5962865586303,
          ema10: 1033.3085828844603,
          ema30: 1030.7084631744283,
          sar: 1038.5197184786298,
          volMa5: 1600.9000000000017,
          volMa10: 1464.15,
          macd: -0.8272396297545059,
          dif: 1.812186991038061,
          dea: 2.225806805915314,
          k: 51.18390222801427,
          d: 49.671889520079354,
          j: 54.207927643884105,
          rsi: 58.64939458291856,
          wr: 42.50000000000114,
          obv: 81345.0,
          maObv: 69942.40333333332,
        ),
      );
    });

    test('incremental append matches a full recalculation', () {
      final appended = buildKlineFixture(101).last;
      DataUtil.addLastData(
        data,
        appended,
        obvPeriod: 30,
        emaConfigs: _emaConfigs,
        chartStyle: _chartStyle,
      );

      final fullyRecalculated = buildKlineFixture(101);
      _calculate(fullyRecalculated);

      _expectEntitiesEqual(data.last, fullyRecalculated.last);
    });
  });
}

final _emaConfigs = <EMAConfig>[
  EMAConfig(period: 5, color: Colors.yellow),
  EMAConfig(period: 10, color: Colors.pink),
  EMAConfig(period: 30, color: Colors.purple),
];

final _chartStyle = ChartStyle()..emaConfigs = _emaConfigs;

void _calculate(List<KLineEntity> data) {
  DataUtil.calculate(
    data,
    obvPeriod: 30,
    emaConfigs: _emaConfigs,
    chartStyle: _chartStyle,
  );
}

void _expectSnapshot(KLineEntity actual, _IndicatorSnapshot expected) {
  final values = <String, (double, double)>{
    'ma5': (actual.MA5Price, expected.ma5),
    'ma10': (actual.MA10Price, expected.ma10),
    'ma20': (actual.MA20Price, expected.ma20),
    'ma30': (actual.MA30Price, expected.ma30),
    'bollUp': (actual.up, expected.bollUp),
    'bollMb': (actual.mb, expected.bollMb),
    'bollDn': (actual.dn, expected.bollDn),
    'ema5': (actual.emaValues[5]!, expected.ema5),
    'ema10': (actual.emaValues[10]!, expected.ema10),
    'ema30': (actual.emaValues[30]!, expected.ema30),
    'sar': (actual.sar, expected.sar),
    'volMa5': (actual.MA5Volume, expected.volMa5),
    'volMa10': (actual.MA10Volume, expected.volMa10),
    'macd': (actual.macd, expected.macd),
    'dif': (actual.dif, expected.dif),
    'dea': (actual.dea, expected.dea),
    'k': (actual.k, expected.k),
    'd': (actual.d, expected.d),
    'j': (actual.j, expected.j),
    'rsi': (actual.rsi, expected.rsi),
    'wr': (actual.r, expected.wr),
    'obv': (actual.obv, expected.obv),
    'maObv': (actual.maOBV, expected.maObv),
  };

  for (final MapEntry(key: name, value: pair) in values.entries) {
    expect(pair.$1, closeTo(pair.$2, _tolerance), reason: name);
  }
}

void _expectEntitiesEqual(KLineEntity actual, KLineEntity expected) {
  _expectSnapshot(
    actual,
    _IndicatorSnapshot(
      ma5: expected.MA5Price,
      ma10: expected.MA10Price,
      ma20: expected.MA20Price,
      ma30: expected.MA30Price,
      bollUp: expected.up,
      bollMb: expected.mb,
      bollDn: expected.dn,
      ema5: expected.emaValues[5]!,
      ema10: expected.emaValues[10]!,
      ema30: expected.emaValues[30]!,
      sar: expected.sar,
      volMa5: expected.MA5Volume,
      volMa10: expected.MA10Volume,
      macd: expected.macd,
      dif: expected.dif,
      dea: expected.dea,
      k: expected.k,
      d: expected.d,
      j: expected.j,
      rsi: expected.rsi,
      wr: expected.r,
      obv: expected.obv,
      maObv: expected.maOBV,
    ),
  );
}

final class _IndicatorSnapshot {
  const _IndicatorSnapshot({
    required this.ma5,
    required this.ma10,
    required this.ma20,
    required this.ma30,
    required this.bollUp,
    required this.bollMb,
    required this.bollDn,
    required this.ema5,
    required this.ema10,
    required this.ema30,
    required this.sar,
    required this.volMa5,
    required this.volMa10,
    required this.macd,
    required this.dif,
    required this.dea,
    required this.k,
    required this.d,
    required this.j,
    required this.rsi,
    required this.wr,
    required this.obv,
    required this.maObv,
  });

  final double ma5;
  final double ma10;
  final double ma20;
  final double ma30;
  final double bollUp;
  final double bollMb;
  final double bollDn;
  final double ema5;
  final double ema10;
  final double ema30;
  final double sar;
  final double volMa5;
  final double volMa10;
  final double macd;
  final double dif;
  final double dea;
  final double k;
  final double d;
  final double j;
  final double rsi;
  final double wr;
  final double obv;
  final double maObv;
}
