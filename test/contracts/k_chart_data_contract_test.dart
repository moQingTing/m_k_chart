import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/controller/k_chart_data_contract.dart';
import 'package:m_k_chart/src/model/model.dart';

import 'fixtures/v2_host_compile_probe.dart' as host;

void main() {
  test('host loader compiles against the frozen internal data commands', () {
    // 仅验证签名可编译，不冒充真实 Controller 的行为测试。
    const Future<KChartDataUpdateResult> Function(
      KChartDataCommands,
      KlineSeries,
      Future<List<Kline>> Function(KlineSeries),
    ) loader = host.loadSeries;
    expect(loader, isNotNull);
    expect(host.subscribeRealtime, isNotNull);
    expect(host.verifyDataCommandSignatures, isNotNull);
  });

  test('data receipts distinguish reload, rejection, no-op and applied changes',
      () {
    for (final status in KChartDataUpdateStatus.values) {
      final result = KChartDataUpdateResult(status: status, dataRevision: 4);
      expect(result.dataRevision, 4);
      expect(result.changed, status == KChartDataUpdateStatus.applied);
      expect(
        result.requiresReload,
        status == KChartDataUpdateStatus.rejectedOutsideWindow,
      );
    }
    expect(
      () => KChartDataUpdateResult(
        status: KChartDataUpdateStatus.applied,
        dataRevision: -1,
      ),
      throwsArgumentError,
    );
  });
}
