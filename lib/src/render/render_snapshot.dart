import 'dart:collection';

import '../indicator/indicator.dart';
import '../model/model.dart';
import '../viewport/viewport.dart';

/// Renderer-facing state slices, mirrored without depending on Controller.
enum RenderSnapshotSlice {
  data,
  viewport,
  selection,
  history,
  layout,
  theme,
}

/// Immutable version vector used by Layers to declare invalidation inputs.
final class RenderSnapshotVersions {
  const RenderSnapshotVersions({
    this.data = 0,
    this.viewport = 0,
    this.selection = 0,
    this.history = 0,
    this.layout = 0,
    this.theme = 0,
  })  : assert(data >= 0),
        assert(viewport >= 0),
        assert(selection >= 0),
        assert(history >= 0),
        assert(layout >= 0),
        assert(theme >= 0);

  final int data;
  final int viewport;
  final int selection;
  final int history;
  final int layout;
  final int theme;

  int versionOf(RenderSnapshotSlice slice) => switch (slice) {
        RenderSnapshotSlice.data => data,
        RenderSnapshotSlice.viewport => viewport,
        RenderSnapshotSlice.selection => selection,
        RenderSnapshotSlice.history => history,
        RenderSnapshotSlice.layout => layout,
        RenderSnapshotSlice.theme => theme,
      };
}

enum RenderSelectionValueKind {
  open,
  high,
  low,
  close,
}

/// Selection payload projected into Renderer-owned, chart-local values.
final class RenderSelectionSnapshot {
  const RenderSelectionSnapshot.hidden()
      : isVisible = false,
        localX = 0,
        localY = 0,
        dataIndex = null,
        price = null,
        valueKind = null;

  factory RenderSelectionSnapshot.visible({
    required double localX,
    required double localY,
    int? dataIndex,
    double? price,
    RenderSelectionValueKind? valueKind,
  }) {
    if (!localX.isFinite || !localY.isFinite) {
      throw ArgumentError('Selection coordinates must be finite.');
    }
    final hasCompleteSnap =
        dataIndex != null && price != null && valueKind != null;
    final hasNoSnap = dataIndex == null && price == null && valueKind == null;
    if (!hasCompleteSnap && !hasNoSnap) {
      throw ArgumentError('Snapped selection values must be all set or null.');
    }
    if (dataIndex != null && dataIndex < 0) {
      throw ArgumentError.value(dataIndex, 'dataIndex');
    }
    if (price != null && !price.isFinite) {
      throw ArgumentError.value(price, 'price', 'Must be finite.');
    }
    return RenderSelectionSnapshot._(
      localX: localX,
      localY: localY,
      dataIndex: dataIndex,
      price: price,
      valueKind: valueKind,
    );
  }

  const RenderSelectionSnapshot._({
    required this.localX,
    required this.localY,
    required this.dataIndex,
    required this.price,
    required this.valueKind,
  }) : isVisible = true;

  final bool isVisible;
  final double localX;
  final double localY;
  final int? dataIndex;
  final double? price;
  final RenderSelectionValueKind? valueKind;

  bool get isSnapped => dataIndex != null;
}

enum RenderHistoryPhase {
  idle,
  loading,
  noMore,
  failure,
}

/// Minimal historical-loading state that a visual Layer may consume.
final class RenderHistorySnapshot {
  const RenderHistorySnapshot({this.phase = RenderHistoryPhase.idle});

  final RenderHistoryPhase phase;
}

/// Calculated indicator output projected without private continuation state.
final class RenderIndicatorSnapshot {
  factory RenderIndicatorSnapshot.fromResult({
    required IndicatorResult result,
    required IndicatorRendererDescriptor descriptor,
    required String panelId,
  }) {
    if (panelId.trim().isEmpty) {
      throw ArgumentError.value(panelId, 'panelId', 'Must not be empty.');
    }
    final series = List<IndicatorSeries>.unmodifiable(result.series);
    final resultIds = {for (final item in series) item.id};
    final descriptorIds = {for (final item in descriptor.series) item.id};
    if (resultIds.length != series.length ||
        resultIds.length != descriptorIds.length ||
        !resultIds.containsAll(descriptorIds)) {
      throw ArgumentError(
        'Indicator result Series must exactly match its descriptor.',
      );
    }
    return RenderIndicatorSnapshot._(
      instanceId: result.instanceId,
      definitionId: result.definitionId,
      dataVersion: result.dataVersion,
      length: result.length,
      descriptor: descriptor,
      panelId: panelId,
      series: series,
    );
  }

  const RenderIndicatorSnapshot._({
    required this.instanceId,
    required this.definitionId,
    required this.dataVersion,
    required this.length,
    required this.descriptor,
    required this.panelId,
    required this.series,
  });

  final String instanceId;
  final String definitionId;
  final KlineDataVersion dataVersion;
  final int length;
  final IndicatorRendererDescriptor descriptor;
  final String panelId;
  final List<IndicatorSeries> series;

  IndicatorSeries? seriesById(String id) {
    for (final item in series) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }
}

/// Complete, read-only input for one deterministic render pass.
///
/// [TTheme] is generic until P6 freezes the public immutable KChartTheme.
/// Callers must provide an immutable theme value.
final class RenderSnapshot<TTheme extends Object> {
  factory RenderSnapshot({
    required VersionedKlineData data,
    required ChartViewport viewport,
    required ChartLayoutModel layout,
    required TTheme theme,
    required RenderSnapshotVersions versions,
    Iterable<RenderIndicatorSnapshot> indicators = const [],
    RenderSelectionSnapshot selection = const RenderSelectionSnapshot.hidden(),
    RenderHistorySnapshot history = const RenderHistorySnapshot(),
  }) {
    if (viewport.itemCount != data.data.length) {
      throw ArgumentError(
        'Viewport itemCount must match the stable data snapshot length.',
      );
    }
    if (viewport.width != layout.drawingBounds.width) {
      throw ArgumentError(
        'Viewport width must match the Layout drawing width.',
      );
    }
    if (selection.dataIndex case final index? when index >= data.data.length) {
      throw ArgumentError.value(
        index,
        'selection.dataIndex',
        'Must reference the data snapshot.',
      );
    }

    final immutableIndicators =
        List<RenderIndicatorSnapshot>.unmodifiable(indicators);
    final instanceIds = <String>{};
    for (final indicator in immutableIndicators) {
      if (!instanceIds.add(indicator.instanceId)) {
        throw ArgumentError.value(
          indicator.instanceId,
          'indicators',
          'Duplicate indicator instance.',
        );
      }
      if (indicator.dataVersion != data.version ||
          indicator.length != data.data.length) {
        throw ArgumentError(
          'Indicator ${indicator.instanceId} does not match the data snapshot.',
        );
      }
      final panel = layout.panelById[indicator.panelId];
      if (panel == null) {
        throw ArgumentError.value(
          indicator.panelId,
          'indicator.panelId',
          'Unknown layout panel.',
        );
      }
      final expectedKind =
          indicator.descriptor.placement == IndicatorPlacement.mainChart
              ? ChartPanelKind.main
              : ChartPanelKind.secondary;
      if (panel.spec.kind != expectedKind) {
        throw ArgumentError(
          'Indicator ${indicator.instanceId} placement does not match '
          'panel ${indicator.panelId}.',
        );
      }
    }

    return RenderSnapshot._(
      data: data,
      viewport: viewport,
      layout: layout,
      theme: theme,
      versions: versions,
      indicators: immutableIndicators,
      indicatorById: UnmodifiableMapView({
        for (final indicator in immutableIndicators)
          indicator.instanceId: indicator,
      }),
      selection: selection,
      history: history,
    );
  }

  const RenderSnapshot._({
    required this.data,
    required this.viewport,
    required this.layout,
    required this.theme,
    required this.versions,
    required this.indicators,
    required this.indicatorById,
    required this.selection,
    required this.history,
  });

  final VersionedKlineData data;
  final ChartViewport viewport;
  final ChartLayoutModel layout;
  final TTheme theme;
  final RenderSnapshotVersions versions;
  final List<RenderIndicatorSnapshot> indicators;
  final Map<String, RenderIndicatorSnapshot> indicatorById;
  final RenderSelectionSnapshot selection;
  final RenderHistorySnapshot history;

  RenderIndicatorSnapshot indicator(String instanceId) {
    final result = indicatorById[instanceId];
    if (result == null) {
      throw ArgumentError.value(instanceId, 'instanceId', 'Unknown indicator.');
    }
    return result;
  }
}
