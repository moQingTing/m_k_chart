import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test('read-only state DTO fields avoid runtime geometry and write hooks', () {
    final source = read('lib/src/controller/k_chart_view_state.dart');
    final dto = source
        .substring(0, source.indexOf('final class _ChartViewListenable'))
        .replaceAll(RegExp(r'///[^\n]*'), '');
    for (final type in [
      'KChartViewState',
      'KChartSelection',
      'KChartViewportInfo',
      'KChartIssue',
    ]) {
      expect(dto, contains('final class $type'));
    }
    for (final forbidden in [
      'ChartViewport',
      'ChartLayoutModel',
      'RenderSnapshot',
      'KlineStore',
      'IndicatorEngine',
      'StateSliceVersions',
      'notifyListeners',
      'dispatch',
    ]) {
      expect(
        RegExp('\\b$forbidden\\b').hasMatch(dto),
        isFalse,
        reason: forbidden,
      );
    }
    expect(
      read('lib/m_k_chart.dart'),
      isNot(contains('k_chart_data_coordinator')),
    );
    expect(read('lib/m_k_chart.dart'), isNot(contains('k_chart_view_state')));
    expect(
      read('lib/m_k_chart.dart'),
      isNot(contains('k_chart_overlay_state')),
    );
  });

  test('V2 SDK API is part of the released stable package contract',
      () {
    final adr = read('docs/architecture/ADR-002_V2_SDK_FACADE_CONTRACT.md');
    final migration = read('docs/MIGRATING_TO_V2.md');
    final draft = read('docs/KLINE_V2_API_DRAFT.md');
    expect(adr, contains('V2 公共 API 纳入 2.0.0 正式兼容面'));
    expect(adr, contains('V2 公共 API 纳入 2.0.0 正式兼容面'));
    expect(adr, contains('KChartDataCommands'));
    expect(migration, contains('m_k_chart` 2.0.0 已从唯一正式入口'));
    expect(draft, contains('ADR-002_V2_SDK_FACADE_CONTRACT.md'));
  });

  test('frozen data commands avoid leaking mutable stores and render inputs',
      () {
    final contract = read('lib/src/controller/k_chart_data_contract.dart');
    final adr = read('docs/architecture/ADR-002_V2_SDK_FACADE_CONTRACT.md');
    // 只检查声明体，说明中的 Store/Renderer 字样不属于签名泄露。
    final body =
        contract.substring(contract.indexOf('abstract interface class'));
    for (final name in [
      'beginSeries',
      'replaceData',
      'appendData',
      'prependHistory',
      'updateKline',
    ]) {
      expect(body, contains('$name('));
      expect(adr, contains('$name('));
    }
    for (final forbidden in [
      'KlineStore',
      'RenderSnapshot',
      'ChartLayoutModel',
      'ChartViewport',
    ]) {
      expect(body, isNot(contains(forbidden)));
    }
    expect(
      read('lib/m_k_chart.dart'),
      isNot(contains('k_chart_data_contract')),
    );
    expect(read('lib/m_k_chart.dart'), isNot(contains('k_chart_data_session')));
  });
}
