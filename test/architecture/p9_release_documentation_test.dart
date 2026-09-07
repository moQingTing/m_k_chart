import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final root = Directory.current.absolute.path;

  String read(String relativePath) =>
      File('$root/$relativePath').readAsStringSync();

  test('release documentation keeps the public API boundary explicit', () {
    final report = read('docs/P9_PUBLIC_API_DIFF.md');
    final migration = read('docs/MIGRATING_TO_V2.md');
    final adr = read('docs/architecture/ADR-001_PUBLIC_API_TRANSITION.md');

    for (final document in [report, migration, adr]) {
      expect(document, contains('package:m_k_chart/m_k_chart.dart'));
      expect(document, contains('KChartTheme'));
      expect(document, contains('KChartUserConfig'));
    }
    expect(migration, contains('package:m_k_chart/src/...'));
    expect(report, contains('tool/public_api_allowlist.txt'));
    expect(adr, contains('v2_example_support.dart'));
  });

  test('README points users to the V2 demo and migration resources', () {
    final readme = read('README.md');
    final main = read('example/lib/main.dart');

    expect(readme, contains('V2TradingChartDemo'));
    expect(readme, contains('docs/MIGRATING_TO_V2.md'));
    expect(readme, contains('docs/P9_PUBLIC_API_DIFF.md'));
    expect(main, contains('home: const V2TradingChartDemo()'));
  });
}
