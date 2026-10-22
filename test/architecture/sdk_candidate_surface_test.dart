import 'dart:io';

import 'package:m_k_chart/m_k_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import '../contracts/fixtures/v2_candidate_host.dart' as public_host;

void main() {
  test('V2 导出清单只包含审核过的语义类型，不包含内部接线口或几何扩展', () {
    final source = File('lib/src/controller/k_chart_candidate_api.dart')
        .readAsStringSync();
    final exports = RegExp(r'export\s+[^;]+;')
        .allMatches(source)
        .map((m) => m.group(0)!)
        .toList();
    final names = <String>{};
    for (final directive in exports) {
      // Dart formatter 会把 show 单独换行；检查语义列表而不是固定空格布局。
      final match = RegExp(r'\bshow\s+([^;]+);$').firstMatch(directive);
      expect(match, isNotNull, reason: directive);
      final shown = match!.group(1)!;
      names.addAll(shown.split(',').map((name) => name.trim()));
    }
    expect(names, {
      'KChart',
      'KChartLabels',
      'KChartSelectionBuilder',
      'KChartController',
      'KChartDataCommands',
      'KChartDataViewportPolicy',
      'KChartDataUpdateResult',
      'KChartDataUpdateStatus',
      'KChartDataSession',
      'KChartHistoryLoader',
      'KChartHistoryRequest',
      'KChartHistoryPage',
      'KChartHistoryPhase',
      'KChartViewState',
      'KChartSelection',
      'KChartViewportInfo',
      'KChartIssue',
      'KChartIssueKind',
      'KChartOverlays',
      'KChartOverlayUpdateStatus',
      'KChartOptions',
      'KChartPanelOptions',
      'KChartSecondaryPanelOptions',
      'KChartViewportOptions',
      'KChartIndicatorBinding',
      'IndicatorConfig',
      'IndicatorCatalogEntry',
      'IndicatorDefinition',
      'NamedIndicatorDefinition',
      'IndicatorParameterKind',
      'IndicatorParameterSpec',
      'ParameterizedIndicatorDefinition',
      'IndicatorPlacement',
      'IndicatorDrawingKind',
      'IndicatorColorStrategy',
      'IndicatorRendererDescriptor',
      'IndicatorSeriesDescriptor',
      'IndicatorLegendDescriptor',
      'IndicatorLegendDisplay',
      'IndicatorResult',
      'IndicatorSeries',
      'KlineDataVersion',
      'VersionedKlineData',
      'Kline',
      'KlinePriceSource',
      'KlineInterval',
      'KlineIntervalKind',
      'KlineSeries',
      'ChartMainMode',
      'ChartPriceLine',
      'ChartPriceLineStyle',
      'ChartOverlaySide',
      'ChartEventOverlay',
      'ChartValueMarker',
      'ChartDrawing',
      'ChartDrawingKind',
      'ChartDrawingAnchor',
      'ChartDrawingStyle',
      'ChartDrawingSnapshot',
      'ChartDrawingOutOfRangePolicy',
      'ChartDrawingEditor',
      'ChartDrawingOhlcField',
      'ChartDrawingOhlcSnap',
      'ChartDrawingCommand',
      'ChartDrawingCommandHistory',
    });
    expect(exports, isNotEmpty);
    expect(source, isNot(contains('k_chart_options_geometry.dart')));
    expect(source, isNot(contains("'k_chart_controller.dart'")));
    final canonical = File('lib/m_k_chart.dart').readAsStringSync();
    expect(canonical, contains("export 'k_chart_v2_api.dart'"));
    expect(canonical, isNot(contains('k_chart_facade')));
  });

  test('配置对象无几何方法，宿主编译探针仅导入正式入口', () {
    final options =
        File('lib/src/controller/k_chart_options.dart').readAsStringSync();
    expect(options, isNot(contains('createLayout(')));
    expect(options, isNot(contains('resolveViewport(')));
    final probe = File('test/contracts/fixtures/v2_candidate_host.dart')
        .readAsStringSync();
    final imports =
        RegExp(r"import\s+'([^']+)';").allMatches(probe).map((m) => m.group(1));
    expect(imports, ['package:m_k_chart/m_k_chart.dart']);
    expect(public_host.createPublicWidget, isNotNull);
    expect(public_host.createPublicChart, isNotNull);
    expect(public_host.installPublicOverlays, isNotNull);
    expect(
      public_host.nextPublicDataVersion(KlineDataVersion.zero),
      KlineDataVersion(1),
    );
    for (final path in [
      'example/lib/v2_custom_indicator_example.dart',
      'example/lib/v2_minimal_chart_main.dart',
      'example/lib/v2_sdk_acceptance_main.dart',
      'example/lib/v2_sdk_chart_settings.dart',
    ]) {
      final source = File(path).readAsStringSync();
      final packageImports = RegExp(r"import\s+'(package:m_k_chart/[^']+)';")
          .allMatches(source)
          .map((match) => match.group(1)!)
          .toList();
      expect(packageImports, isNotEmpty, reason: path);
      expect(
        packageImports,
        everyElement('package:m_k_chart/m_k_chart.dart'),
        reason: path,
      );
    }
  });
}
