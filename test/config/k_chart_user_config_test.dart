import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/m_k_chart.dart';

void main() {
  test('round-trips a versioned host-owned V2 user configuration', () {
    final config = KChartUserConfig(
      instrumentId: 'BTC-USDT',
      intervalCode: '15m',
      mainMode: 'heikinAshi',
      timeZoneOffsetMinutes: 480,
      mainIndicators: [
        KChartIndicatorPreference(
          instanceId: 'ema-fast',
          definitionId: 'legacy.ema',
          parameters: {'period': 7},
          seriesStyleKeys: {'ema': 'accent-yellow'},
        ),
      ],
      secondaryIndicators: [
        KChartIndicatorPreference(
          instanceId: 'macd-primary',
          definitionId: 'legacy.macd',
          parameters: {'fast': 12, 'slow': 26, 'signal': 9},
        ),
      ],
      overlaySecondaryIndicators: true,
      secondaryPanelHeight: 124,
      mainIndicatorHeaderHeight: 20,
      secondaryIndicatorHeaderHeight: 16,
      mainTimeAxisHeight: 22,
    );

    final decoded = jsonDecode(jsonEncode(config.toJson())) as Map;
    final restored = KChartUserConfig.fromJson(
      Map<String, Object?>.from(decoded),
    );

    expect(restored, config);
    expect(restored.toJson()['schemaVersion'], KChartUserConfig.schemaVersion);
    expect(
      () => restored.mainIndicators.add(
        KChartIndicatorPreference(
          instanceId: 'other',
          definitionId: 'legacy.ma',
        ),
      ),
      throwsUnsupportedError,
    );
  });

  test('migrates pre-versioned legacy chart preference fields', () {
    final config = KChartUserConfig.fromJson({
      'instrumentId': 'ETH-USDT',
      'period': '5m',
      'isLine': true,
      'mainState': 'MainState.ema',
      'secondaryStates': ['SecondaryState.vol', 'SecondaryState.macd'],
      'timeZoneOffsetHours': 8,
      'overlaySecondaryIndicators': true,
      'secondaryPanelHeight': 120,
    });

    expect(config.instrumentId, 'ETH-USDT');
    expect(config.intervalCode, '5m');
    expect(config.mainMode, 'line');
    expect(config.timeZoneOffsetMinutes, 480);
    expect(config.mainIndicators.single.definitionId, 'legacy.ema');
    expect(
      config.secondaryIndicators.map((item) => item.definitionId),
      ['legacy.vol', 'legacy.macd'],
    );
    expect(config.overlaySecondaryIndicators, isTrue);
    expect(config.secondaryPanelHeight, 120);
  });

  test('rejects newer schemas and malformed persisted values', () {
    expect(
      () => KChartUserConfig.fromJson({
        'schemaVersion': KChartUserConfig.schemaVersion + 1,
      }),
      throwsUnsupportedError,
    );
    expect(
      () => KChartUserConfig.fromJson({
        'schemaVersion': 1,
        'intervalCode': '1m',
        'mainMode': 'unknown',
      }),
      throwsArgumentError,
    );
    expect(
      () => KChartIndicatorPreference.fromJson({
        'instanceId': 'bad',
        'definitionId': 'legacy.ma',
        'parameters': {'period': 'five'},
      }),
      throwsFormatException,
    );
  });
}
