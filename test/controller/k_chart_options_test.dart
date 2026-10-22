import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/controller/k_chart_indicator_binding.dart';
import 'package:m_k_chart/src/controller/k_chart_options.dart';
import 'package:m_k_chart/src/controller/k_chart_options_geometry.dart';
import 'package:m_k_chart/src/indicator/indicator_config.dart';
import 'package:m_k_chart/src/model/chart_main_mode.dart';
import 'package:m_k_chart/src/render/chart_main_mode.dart' as legacy;
import 'package:m_k_chart/src/viewport/viewport.dart';

void main() {
  KChartIndicatorBinding binding(String id, String panel) =>
      KChartIndicatorBinding(
        panelId: panel,
        config: IndicatorConfig(instanceId: id, definitionId: 'legacy.ma'),
      );

  test('defaults match demo geometry without enabling indicators', () {
    final options = KChartOptions();
    expect(options.mainMode, ChartMainMode.candlestick);
    expect(options.mainPanel.minHeight, 220);
    expect(options.mainPanel.headerHeight, 18);
    expect(options.mainPanel.gridRows, 4);
    expect(options.viewport.initialVisibleCandles, 90);
    expect(options.viewport.rightPaddingFraction, 0.2);
    expect(options.viewport.allowLatestAtLeft, isTrue);
    expect(options.timeZoneOffset, const Duration(hours: 8));
    expect(options.indicators, isEmpty);
    expect(options.secondaryPanels, isEmpty);
    final secondary = KChartSecondaryPanelOptions(id: 'macd');
    expect(secondary.layout.minHeight, 108);
    expect(secondary.layout.headerHeight, 18);
    expect(secondary.layout.gridRows, 2);
  });

  test(
      'collections are immutable and copyWith validates combined panel changes',
      () {
    final panels = [KChartSecondaryPanelOptions(id: 'one')];
    final indicators = [binding('ma', 'one')];
    final options =
        KChartOptions(secondaryPanels: panels, indicators: indicators);
    panels.clear();
    indicators.clear();
    expect(options.secondaryPanels, hasLength(1));
    expect(options.indicators, hasLength(1));
    expect(() => options.indicators.clear(), throwsUnsupportedError);
    expect(() => options.secondaryPanels.clear(), throwsUnsupportedError);
    expect(
      () => options.copyWith(secondaryPanels: const []),
      throwsArgumentError,
    );
    final cleared =
        options.copyWith(secondaryPanels: const [], indicators: const []);
    expect(cleared.secondaryPanels, isEmpty);
    expect(options.indicators, hasLength(1));
  });

  test(
      'copyWith and hash equality include all independent configuration groups',
      () {
    final options = KChartOptions(
      secondaryPanels: [KChartSecondaryPanelOptions(id: 'one')],
    );
    expect(options.copyWith(), options);
    expect(options.copyWith().hashCode, options.hashCode);
    final variants = [
      options.copyWith(mainMode: ChartMainMode.area),
      options.copyWith(mainPanel: options.mainPanel.copyWith(headerHeight: 20)),
      options.copyWith(
        secondaryPanels: [
          options.secondaryPanels.single.copyWith(id: 'two'),
        ],
      ),
      options.copyWith(indicators: [binding('ma', 'main')]),
      options.copyWith(
        viewport: options.viewport.copyWith(initialVisibleCandles: 60),
      ),
      options.copyWith(timeZoneOffset: Duration.zero),
      options.copyWith(mainTimeAxisHeight: 20),
      options.copyWith(panelSpacing: 2),
      options.copyWith(gridColumns: 3),
      options.copyWith(maxOutOfOrderCandles: 3),
      options.copyWith(historyThresholdItems: 3),
    ];
    for (final variant in variants) {
      expect(variant, isNot(options));
      expect(variant.copyWith(), variant);
      expect(variant.copyWith().hashCode, variant.hashCode);
    }
    final viewport = KChartViewportOptions();
    for (final variant in [
      viewport.copyWith(minItemExtent: 3),
      viewport.copyWith(maxItemExtent: 50),
      viewport.copyWith(rightPaddingFraction: 0.3),
      viewport.copyWith(allowLatestAtLeft: false),
    ]) {
      expect(variant, isNot(viewport));
    }
  });

  test('panel identity, bindings and scalar ranges are strictly validated', () {
    final invalid = <void Function()>[
      () => KChartSecondaryPanelOptions(id: 'main'),
      () => KChartSecondaryPanelOptions(id: ' '),
      () => KChartOptions(
            secondaryPanels: [
              KChartSecondaryPanelOptions(id: 'a'),
              KChartSecondaryPanelOptions(id: 'a'),
            ],
          ),
      () => KChartOptions(indicators: [binding('ma', 'unknown')]),
      () => KChartOptions(
            indicators: [binding('ma', 'main'), binding('ma', 'main')],
          ),
      () => KChartOptions(gridColumns: 0),
      () => KChartOptions(maxOutOfOrderCandles: -1),
      () => KChartOptions(timeZoneOffset: const Duration(microseconds: 1)),
      () => KChartOptions(timeZoneOffset: const Duration(hours: -13)),
      () => KChartOptions(timeZoneOffset: const Duration(hours: 15)),
      () => KChartPanelOptions(weight: 0),
      () => KChartPanelOptions(minHeight: 0),
      () => KChartPanelOptions(gridRows: 0),
      () => KChartViewportOptions(initialVisibleCandles: 0),
      () => KChartViewportOptions(minItemExtent: 0),
      () => KChartViewportOptions(minItemExtent: 20, maxItemExtent: 10),
      () => KChartViewportOptions(rightPaddingFraction: 1),
    ];
    for (final command in invalid) {
      expect(command, throwsArgumentError);
    }
    for (final value in [-1.0, double.nan, double.infinity]) {
      expect(() => KChartPanelOptions(minHeight: value), throwsArgumentError);
      expect(
        () => KChartPanelOptions(headerHeight: value),
        throwsArgumentError,
      );
      expect(() => KChartPanelOptions(weight: value), throwsArgumentError);
      expect(
        () => KChartOptions(mainTimeAxisHeight: value),
        throwsArgumentError,
      );
      expect(() => KChartOptions(panelSpacing: value), throwsArgumentError);
      expect(
        () => KChartOptions(historyThresholdItems: value),
        throwsArgumentError,
      );
      expect(
        () => KChartViewportOptions(rightPaddingFraction: value),
        throwsArgumentError,
      );
      expect(
        () => KChartViewportOptions(maxItemExtent: value),
        throwsArgumentError,
      );
    }
    expect(
      KChartOptions(timeZoneOffset: const Duration(hours: -12)).timeZoneOffset,
      const Duration(hours: -12),
    );
    expect(
      KChartOptions(timeZoneOffset: const Duration(hours: 14)).timeZoneOffset,
      const Duration(hours: 14),
    );
  });

  test('layout adapter matches explicit existing layout construction', () {
    final options = KChartOptions(
      secondaryPanels: [KChartSecondaryPanelOptions(id: 'macd')],
    );
    final layout = options.createLayout(width: 400, height: 500);
    final explicit = ChartLayoutModel(
      width: 400,
      height: 500,
      gridColumns: 2,
      mainTimeAxisHeight: 18,
      mainPanel: const ChartPanelSpec.main(
        minHeight: 220,
        headerHeight: 18,
        gridRows: 4,
      ),
      secondaryPanels: const [
        ChartPanelSpec.secondary(
          id: 'macd',
          minHeight: 108,
          headerHeight: 18,
          gridRows: 2,
        ),
      ],
    );
    expect(layout, explicit);
    expect(layout.gridRowYsFor('main'), hasLength(5));
    expect(layout.gridRowYsFor('macd'), hasLength(3));
    expect(
      layout.drawingBounds.width,
      400,
      reason: 'Future blank must not crop the grid width.',
    );
    expect(layout.mainTimeAxisBounds.height, 18);
    expect(layout.mainPanel.gridBounds.bottom, layout.mainTimeAxisBounds.top);
    expect(
      layout.panel('macd').gridBounds.top,
      layout.mainTimeAxisBounds.bottom,
    );
  });

  test('single main chart puts time axis at bottom', () {
    final layout = KChartOptions().createLayout(width: 400, height: 300);
    expect(layout.timeAxisBounds.height, 18);
    expect(layout.mainPanel.bounds.bottom, layout.timeAxisBounds.top);
    expect(layout.mainPanel.headerBounds.height, 18);
  });

  test('measured headers stay within grid and never overlap data region', () {
    final options = KChartOptions(
      secondaryPanels: [
        KChartSecondaryPanelOptions(
          id: 'auto',
          layout: KChartPanelOptions(minHeight: 60),
        ),
        KChartSecondaryPanelOptions(id: 'fixed'),
      ],
    );
    final layout = options.createLayout(
      width: 400,
      height: 600,
      measuredMainHeaderHeight: 40,
      measuredSecondaryHeaderHeights: const {'auto': 30, 'fixed': 50},
    );
    expect(layout.mainPanel.headerBounds.height, 40);
    expect(layout.panel('auto').headerBounds.height, 30);
    expect(layout.panel('fixed').headerBounds.height, 18);
    for (final panel in layout.panels) {
      expect(panel.headerBounds.bottom, panel.bounds.top);
      expect(panel.gridBounds.top, panel.headerBounds.top);
    }
    final smaller = options.createLayout(
      width: 400,
      height: 600,
      measuredMainHeaderHeight: 1,
    );
    expect(smaller.mainPanel.headerBounds.height, 18);
  });

  test(
      'layout rejects impossible sizes and unknown or invalid header measurements',
      () {
    final options = KChartOptions();
    expect(
      () => options.createLayout(width: 400, height: 20),
      throwsArgumentError,
    );
    expect(
      () => options.createLayout(width: 0, height: 300),
      throwsArgumentError,
    );
    expect(
      () => options.createLayout(
        width: 400,
        height: 300,
        measuredMainHeaderHeight: double.nan,
      ),
      throwsArgumentError,
    );
    expect(
      () => options.createLayout(
        width: 400,
        height: 300,
        measuredSecondaryHeaderHeights: const {'missing': 20},
      ),
      throwsArgumentError,
    );
  });

  test('old render import and new model import preserve mode identity', () {
    expect(legacy.ChartMainMode.values, ChartMainMode.values);
    expect(
      identical(legacy.ChartMainMode.candlestick, ChartMainMode.candlestick),
      isTrue,
    );
    expect(ChartMainMode.heikinAshi.usesHeikinAshi, isTrue);
    expect(ChartMainMode.line.showsMainIndicators, isFalse);
  });
}
