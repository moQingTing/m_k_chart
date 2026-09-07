import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final packageRoot = Directory.current.absolute;
  final indicatorRoot = Directory('${packageRoot.path}/lib/src/indicator');
  final modelFile = File('${packageRoot.path}/lib/src/model/kline.dart');

  test('v2 indicator module has no legacy entity or Flutter dependency', () {
    const forbidden = <String, String>{
      'KLineEntity': 'legacy mutable entity',
      'DataUtil': 'legacy mutating calculator',
      'MainState': 'legacy main indicator enum',
      'SecondaryState': 'legacy secondary indicator enum',
      'package:flutter/': 'Flutter framework',
      '../../entity/': 'legacy entity module',
      '../../chart_style.dart': 'legacy mutable style',
      '../../utils/data_util.dart': 'legacy calculator',
    };
    final violations = <String>[];
    for (final source in _dartSources(indicatorRoot)) {
      final contents = source.readAsStringSync();
      for (final entry in forbidden.entries) {
        if (contents.contains(entry.key)) {
          violations.add(
            '${_relative(source, packageRoot)} references ${entry.value}',
          );
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('definition lookup and built-in registration use no switch dispatch',
      () {
    const guardedFiles = [
      'indicator_registry.dart',
      'indicator_engine.dart',
      'built_in_indicators.dart',
      'legacy_indicator_definitions.dart',
      'additional_indicator_definitions.dart',
    ];
    final violations = <String>[];
    final switchDispatch = RegExp(r'\bswitch\s*[\(\{]');
    for (final name in guardedFiles) {
      final source = File('${indicatorRoot.path}/$name');
      if (switchDispatch.hasMatch(source.readAsStringSync())) {
        violations.add(_relative(source, packageRoot));
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Indicator selection must use registered definitions, not '
          'enum/switch dispatch:\n${violations.join('\n')}',
    );
  });

  test('immutable Kline stores no indicator result fields or mixins', () {
    final contents = modelFile.readAsStringSync();
    const forbiddenFields = [
      'MA5Price',
      'MA10Price',
      'emaValues',
      'macd',
      'boll',
      'sar',
      'rsi',
      'obv',
      'cci',
      'vwap',
    ];

    expect(contents, isNot(contains(' with ')));
    for (final field in forbiddenFields) {
      expect(
        contents,
        isNot(contains(field)),
        reason: 'Kline must not store $field indicator output.',
      );
    }
  });

  test('indicator formulas never assign through Kline input objects', () {
    final violations = <String>[];
    final klineMutation = RegExp(
      r'(?:input\.data|data)\s*\[[^\]]+\]\s*\.\s*\w+\s*=',
    );
    for (final source in _dartSources(indicatorRoot)) {
      if (klineMutation.hasMatch(source.readAsStringSync())) {
        violations.add(_relative(source, packageRoot));
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}

Iterable<File> _dartSources(Directory root) => root
    .listSync(recursive: true)
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'));

String _relative(File file, Directory root) =>
    file.path.substring(root.path.length + 1);
