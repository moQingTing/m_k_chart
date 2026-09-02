import 'dart:collection';
import 'dart:ui';

import '../drawing/drawing.dart';
import '../indicator/indicator.dart';
import '../model/model.dart';
import '../viewport/viewport.dart';
import 'chart_main_mode.dart';

/// Renderer-facing state slices, mirrored without depending on Controller.
enum RenderSnapshotSlice {
  data,
  viewport,
  selection,
  history,
  layout,
  theme,
  drawings,
  overlays,
  clock,
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
    this.drawings = 0,
    this.overlays = 0,
    this.clock = 0,
  })  : assert(data >= 0),
        assert(viewport >= 0),
        assert(selection >= 0),
        assert(history >= 0),
        assert(layout >= 0),
        assert(theme >= 0),
        assert(drawings >= 0),
        assert(overlays >= 0),
        assert(clock >= 0);

  final int data;
  final int viewport;
  final int selection;
  final int history;
  final int layout;
  final int theme;
  final int drawings;
  final int overlays;
  final int clock;

  int versionOf(RenderSnapshotSlice slice) => switch (slice) {
        RenderSnapshotSlice.data => data,
        RenderSnapshotSlice.viewport => viewport,
        RenderSnapshotSlice.selection => selection,
        RenderSnapshotSlice.history => history,
        RenderSnapshotSlice.layout => layout,
        RenderSnapshotSlice.theme => theme,
        RenderSnapshotSlice.drawings => drawings,
        RenderSnapshotSlice.overlays => overlays,
        RenderSnapshotSlice.clock => clock,
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

/// Legacy chart-local line primitive kept for backward-compatible render input.
final class RenderLineDrawing {
  RenderLineDrawing({
    required this.id,
    required this.start,
    required this.end,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty.');
    }
    if (!start.dx.isFinite ||
        !start.dy.isFinite ||
        !end.dx.isFinite ||
        !end.dy.isFinite) {
      throw ArgumentError('Drawing coordinates must be finite.');
    }
  }

  final String id;
  final Offset start;
  final Offset end;
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
/// [TTheme] remains generic inside Renderer; production assembly supplies the
/// public immutable KChartTheme. Callers must provide an immutable theme value.
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
    Iterable<RenderLineDrawing> drawings = const [],
    Iterable<ChartDrawing> anchoredDrawings = const [],
    Iterable<ChartPriceLine> priceLines = const [],
    Iterable<ChartEventOverlay> eventOverlays = const [],
    Iterable<ChartValueMarker> valueMarkers = const [],
    ChartMainMode mainMode = ChartMainMode.candlestick,
    Duration timeZoneOffset = Duration.zero,
    int? currentTime,
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

    final immutableDrawings = List<RenderLineDrawing>.unmodifiable(drawings);
    final drawingById = <String, RenderLineDrawing>{};
    for (final drawing in immutableDrawings) {
      if (drawingById.containsKey(drawing.id)) {
        throw ArgumentError.value(
          drawing.id,
          'drawings',
          'Duplicate drawing id.',
        );
      }
      drawingById[drawing.id] = drawing;
    }
    final immutableAnchoredDrawings =
        List<ChartDrawing>.unmodifiable(anchoredDrawings);
    final anchoredDrawingById = <String, ChartDrawing>{};
    for (final drawing in immutableAnchoredDrawings) {
      if (anchoredDrawingById.containsKey(drawing.id)) {
        throw ArgumentError.value(
          drawing.id,
          'anchoredDrawings',
          'Duplicate drawing id.',
        );
      }
      anchoredDrawingById[drawing.id] = drawing;
    }

    final immutablePriceLines = List<ChartPriceLine>.unmodifiable(priceLines);
    final immutableEventOverlays =
        List<ChartEventOverlay>.unmodifiable(eventOverlays);
    final immutableValueMarkers =
        List<ChartValueMarker>.unmodifiable(valueMarkers);
    final overlayIds = <String>{};
    for (final overlay in <(String, String)>[
      for (final line in immutablePriceLines) (line.id, 'priceLines'),
      for (final event in immutableEventOverlays) (event.id, 'eventOverlays'),
      for (final marker in immutableValueMarkers) (marker.id, 'valueMarkers'),
    ]) {
      if (!overlayIds.add(overlay.$1)) {
        throw ArgumentError.value(
          overlay.$1,
          overlay.$2,
          'Duplicate trade overlay id.',
        );
      }
    }

    final resolvedCurrentTime = currentTime ?? _nextExpectedOpenTime(data.data);
    if (resolvedCurrentTime < 0) {
      throw ArgumentError.value(
        currentTime,
        'currentTime',
        'Must not be negative.',
      );
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
      drawings: immutableDrawings,
      drawingById: UnmodifiableMapView(drawingById),
      anchoredDrawings: immutableAnchoredDrawings,
      anchoredDrawingById: UnmodifiableMapView(anchoredDrawingById),
      priceLines: immutablePriceLines,
      eventOverlays: immutableEventOverlays,
      valueMarkers: immutableValueMarkers,
      mainMode: mainMode,
      timeZoneOffset: timeZoneOffset,
      currentTime: resolvedCurrentTime,
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
    required this.drawings,
    required this.drawingById,
    required this.anchoredDrawings,
    required this.anchoredDrawingById,
    required this.priceLines,
    required this.eventOverlays,
    required this.valueMarkers,
    required this.mainMode,
    required this.timeZoneOffset,
    required this.currentTime,
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
  final List<RenderLineDrawing> drawings;
  final Map<String, RenderLineDrawing> drawingById;

  /// P7 drawings persisted as time/price anchors and projected at paint time.
  final List<ChartDrawing> anchoredDrawings;
  final Map<String, ChartDrawing> anchoredDrawingById;

  /// Trading overlays are immutable and invalidated independently of data.
  final List<ChartPriceLine> priceLines;
  final List<ChartEventOverlay> eventOverlays;
  final List<ChartValueMarker> valueMarkers;
  final ChartMainMode mainMode;

  /// Display offset applied by axis and overlay time formatters.
  final Duration timeZoneOffset;

  /// Host-supplied clock used to calculate the latest-candle countdown.
  final int currentTime;

  /// Remaining time until the next candle is expected from the latest two
  /// opening timestamps. It stays at zero when the interval is unknown or
  /// after the expected boundary has passed.
  Duration get latestPriceCountdown {
    if (data.data.length < 2) return Duration.zero;
    final previous = data.data[data.data.length - 2];
    final latest = data.data.last;
    final interval = latest.openTime - previous.openTime;
    if (interval <= 0) return Duration.zero;
    final remaining = latest.openTime + interval - currentTime;
    return remaining > 0 ? Duration(milliseconds: remaining) : Duration.zero;
  }

  /// Compact countdown used by the latest-price label.
  ///
  /// Sub-hour intervals use `MM:SS`; longer intervals use `HH:MM:SS`.
  String get latestPriceCountdownText {
    final milliseconds = latestPriceCountdown.inMilliseconds;
    if (milliseconds <= 0) return '00:00';
    final totalSeconds = (milliseconds + 999) ~/ 1000;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final minuteText = minutes.toString().padLeft(2, '0');
    final secondText = seconds.toString().padLeft(2, '0');
    if (hours == 0) return '$minuteText:$secondText';
    return '${hours.toString().padLeft(2, '0')}:'
        '$minuteText:$secondText';
  }

  RenderIndicatorSnapshot indicator(String instanceId) {
    final result = indicatorById[instanceId];
    if (result == null) {
      throw ArgumentError.value(instanceId, 'instanceId', 'Unknown indicator.');
    }
    return result;
  }

  RenderLineDrawing drawing(String id) {
    final result = drawingById[id];
    if (result == null) {
      throw ArgumentError.value(id, 'id', 'Unknown drawing.');
    }
    return result;
  }

  ChartDrawing anchoredDrawing(String id) {
    final result = anchoredDrawingById[id];
    if (result == null) {
      throw ArgumentError.value(id, 'id', 'Unknown anchored drawing.');
    }
    return result;
  }
}

int _nextExpectedOpenTime(List<Kline> data) {
  if (data.isEmpty) return 0;
  if (data.length < 2) return data.last.openTime;
  final previous = data[data.length - 2];
  final latest = data.last;
  final interval = latest.openTime - previous.openTime;
  return interval > 0 ? latest.openTime + interval : latest.openTime;
}
