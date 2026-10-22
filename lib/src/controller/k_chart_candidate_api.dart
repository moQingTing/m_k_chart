/// V2 公共 API 的显式 show 清单，由根目录受控 facade 转发。
///
/// 消费方只应从 `package:m_k_chart/m_k_chart.dart` 接入；此实现路径不是公共入口。
/// 用显式 show 避免把内部协调器、几何扩展、Painter 或 Widget State 暴露给宿主。
library;

export '../widget/k_chart.dart' show KChart;
export '../widget/k_chart_labels.dart' show KChartLabels;
export '../widget/k_chart_overlays.dart' show KChartSelectionBuilder;
export 'k_chart_facade.dart' show KChartController;
export 'k_chart_data_contract.dart'
    show
        KChartDataCommands,
        KChartDataViewportPolicy,
        KChartDataUpdateResult,
        KChartDataUpdateStatus;
export 'k_chart_data_session.dart' show KChartDataSession;
export 'k_chart_history_contract.dart'
    show
        KChartHistoryLoader,
        KChartHistoryRequest,
        KChartHistoryPage,
        KChartHistoryPhase;
export 'k_chart_data_coordinator.dart'
    show
        KChartViewState,
        KChartSelection,
        KChartViewportInfo,
        KChartIssue,
        KChartIssueKind,
        KChartOverlays,
        KChartOverlayUpdateStatus;
export 'k_chart_options.dart'
    show
        KChartOptions,
        KChartPanelOptions,
        KChartSecondaryPanelOptions,
        KChartViewportOptions;
export 'k_chart_indicator_binding.dart' show KChartIndicatorBinding;
export '../indicator/indicator_config.dart' show IndicatorConfig;
export '../indicator/indicator_catalog_entry.dart' show IndicatorCatalogEntry;
export '../indicator/indicator_definition.dart'
    show IndicatorDefinition, NamedIndicatorDefinition;
export '../indicator/indicator_parameter_spec.dart'
    show
        IndicatorParameterKind,
        IndicatorParameterSpec,
        ParameterizedIndicatorDefinition;
export '../indicator/indicator_renderer_descriptor.dart'
    show
        IndicatorPlacement,
        IndicatorDrawingKind,
        IndicatorColorStrategy,
        IndicatorRendererDescriptor,
        IndicatorSeriesDescriptor,
        IndicatorLegendDescriptor,
        IndicatorLegendDisplay;
export '../indicator/indicator_series.dart'
    show IndicatorResult, IndicatorSeries;
export '../model/kline.dart' show Kline, KlinePriceSource;
export '../model/kline_data_version.dart' show KlineDataVersion;
export '../model/versioned_kline_data.dart' show VersionedKlineData;
export '../model/kline_interval.dart' show KlineInterval, KlineIntervalKind;
export '../model/kline_series.dart' show KlineSeries;
export '../model/chart_main_mode.dart' show ChartMainMode;
export '../model/chart_overlay.dart'
    show
        ChartPriceLine,
        ChartPriceLineStyle,
        ChartOverlaySide,
        ChartEventOverlay,
        ChartValueMarker;
export '../drawing/chart_drawing.dart'
    show ChartDrawing, ChartDrawingKind, ChartDrawingAnchor, ChartDrawingStyle;
export '../drawing/chart_drawing_snapshot.dart' show ChartDrawingSnapshot;
export '../drawing/chart_drawing_timeline_restorer.dart'
    show ChartDrawingOutOfRangePolicy;
export '../drawing/chart_drawing_editor.dart'
    show ChartDrawingEditor, ChartDrawingOhlcField, ChartDrawingOhlcSnap;
export '../drawing/chart_drawing_command_history.dart'
    show ChartDrawingCommand, ChartDrawingCommandHistory;
