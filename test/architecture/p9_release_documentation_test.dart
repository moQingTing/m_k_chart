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

  test('host gate includes each maintained V2 integration target', () {
    final gate = read('tool/run_p9_host_gate.sh');
    for (final target in [
      'integration_test/v2_chart_flow_test.dart',
      'integration_test/v2_minimal_chart_flow_test.dart',
      'integration_test/v2_sdk_acceptance_flow_test.dart',
    ]) {
      expect(gate, contains(target));
    }
  });

  test('public API gate compiles the host probe and checks the facade contract', () {
    final gate = read('tool/check_p9_public_api.sh');
    expect(gate, contains('test/architecture/public_api_surface_test.dart'));
    expect(gate, contains('test/architecture/sdk_candidate_surface_test.dart'));
    expect(gate, contains('test/architecture/sdk_facade_contract_test.dart'));
    expect(gate, contains('test/architecture/p9_release_documentation_test.dart'));
  });
}
