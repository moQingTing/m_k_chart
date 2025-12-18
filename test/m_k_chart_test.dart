import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/m_k_chart.dart';

void main() {
  group('DataUtil Tests', () {
    test('getDate should return formatted date string', () {
      // 测试时间戳：2024-01-01 00:00:00 UTC
      const timestamp = 1704067200;
      final result = DataUtil.getDate(timestamp);
      
      expect(result, isA<String>());
      expect(result.isNotEmpty, true);
    });

    test('getDate should use custom formatter when provided', () {
      const timestamp = 1704067200;
      String customFormatter(int date) => 'Custom: $date';
      
      final result = DataUtil.getDate(timestamp, customFormatter);
      
      expect(result, 'Custom: $timestamp');
    });

    test('calculate should process KLineEntity list', () {
      final dataList = <KLineEntity>[
        KLineEntity()
          ..id = 1704067200
          ..open = 100.0
          ..high = 110.0
          ..low = 95.0
          ..close = 105.0
          ..vol = 1000.0,
        KLineEntity()
          ..id = 1704070800
          ..open = 105.0
          ..high = 115.0
          ..low = 100.0
          ..close = 110.0
          ..vol = 1200.0,
      ];

      // Should not throw
      expect(() => DataUtil.calculate(dataList), returnsNormally);
    });
  });

  group('ChartStyle Tests', () {
    test('ChartStyle should have default formatters', () {
      final style = ChartStyle();
      
      expect(style.priceFormatter, isNull);
      expect(style.volumeFormatter, isNull);
      expect(style.dateFormatter, isNull);
    });

    test('ChartStyle should accept custom formatters', () {
      final style = ChartStyle(
        priceFormatter: (price, style) => TextSpan(text: '\$$price', style: style),
        volumeFormatter: (volume, style) => TextSpan(text: '$volume', style: style),
        dateFormatter: (date) => 'Date: $date',
      );

      expect(style.priceFormatter, isNotNull);
      expect(style.volumeFormatter, isNotNull);
      expect(style.dateFormatter, isNotNull);
    });
  });

  group('ChartColors Tests', () {
    test('ChartColors should initialize with required parameters', () {
      final colors = ChartColors(
        isDarkMode: false,
        upColor: const Color(0xFF00FF00),
        downColor: const Color(0xFFFF0000),
      );

      expect(colors.isDarkMode, false);
      expect(colors.upColor, const Color(0xFF00FF00));
      expect(colors.downColor, const Color(0xFFFF0000));
    });

    test('dnColor should return downColor', () {
      final colors = ChartColors(
        isDarkMode: false,
        upColor: const Color(0xFF00FF00),
        downColor: const Color(0xFFFF0000),
      );

      expect(colors.dnColor, colors.downColor);
    });
  });
}

