import '../interaction/interaction.dart';
import '../viewport/viewport.dart';

/// Independently versioned portions of a chart state.
///
/// Render layers and listeners use these identities to subscribe to the
/// smallest state portion that can affect their output.
enum StateSlice {
  data,
  viewport,
  selection,
  history,
  layout,
  theme,
}

/// Immutable version vector for all [StateSlice] values.
final class StateSliceVersions {
  const StateSliceVersions({
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

  int versionOf(StateSlice slice) => switch (slice) {
        StateSlice.data => data,
        StateSlice.viewport => viewport,
        StateSlice.selection => selection,
        StateSlice.history => history,
        StateSlice.layout => layout,
        StateSlice.theme => theme,
      };

  StateSliceVersions bump(Set<StateSlice> slices) {
    if (slices.isEmpty) {
      return this;
    }

    return StateSliceVersions(
      data: data + (slices.contains(StateSlice.data) ? 1 : 0),
      viewport: viewport + (slices.contains(StateSlice.viewport) ? 1 : 0),
      selection: selection + (slices.contains(StateSlice.selection) ? 1 : 0),
      history: history + (slices.contains(StateSlice.history) ? 1 : 0),
      layout: layout + (slices.contains(StateSlice.layout) ? 1 : 0),
      theme: theme + (slices.contains(StateSlice.theme) ? 1 : 0),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StateSliceVersions &&
          data == other.data &&
          viewport == other.viewport &&
          selection == other.selection &&
          history == other.history &&
          layout == other.layout &&
          theme == other.theme;

  @override
  int get hashCode =>
      Object.hash(data, viewport, selection, history, layout, theme);
}

/// Immutable aggregate revision published by a chart controller.
///
/// A controller transaction calls [bump] once with every changed slice. The
/// aggregate [revision] advances once per non-empty transaction while each
/// affected slice advances independently. State payloads will be added beside
/// this protocol as their owning modules are introduced.
final class KChartState {
  const KChartState({
    this.revision = 0,
    this.versions = const StateSliceVersions(),
    this.viewport = const ChartViewport.initial(),
    this.layout,
    this.crosshair = const ChartCrosshairState.hidden(),
    this.historyPaging = const ChartHistoryPagingState(),
  }) : assert(revision >= 0);

  final int revision;
  final StateSliceVersions versions;
  final ChartViewport viewport;
  final ChartLayoutModel? layout;
  final ChartCrosshairState crosshair;
  final ChartHistoryPagingState historyPaging;

  int versionOf(StateSlice slice) => versions.versionOf(slice);

  KChartState bump(
    Iterable<StateSlice> changedSlices, {
    ChartViewport? viewport,
    ChartLayoutModel? layout,
    ChartCrosshairState? crosshair,
    ChartHistoryPagingState? historyPaging,
  }) {
    final slices = Set<StateSlice>.of(changedSlices);
    final nextViewport = viewport ?? this.viewport;
    final nextLayout = layout ?? this.layout;
    final nextCrosshair = crosshair ?? this.crosshair;
    final nextHistoryPaging = historyPaging ?? this.historyPaging;
    if (nextViewport != this.viewport) {
      slices.add(StateSlice.viewport);
    }
    if (nextLayout != this.layout) {
      slices.add(StateSlice.layout);
    }
    if (nextCrosshair != this.crosshair) {
      slices.add(StateSlice.selection);
    }
    if (nextHistoryPaging != this.historyPaging) {
      slices.add(StateSlice.history);
    }
    if (slices.isEmpty) {
      return this;
    }

    return KChartState(
      revision: revision + 1,
      versions: versions.bump(slices),
      viewport: nextViewport,
      layout: nextLayout,
      crosshair: nextCrosshair,
      historyPaging: nextHistoryPaging,
    );
  }

  bool hasChangedSince(KChartState previous, StateSlice slice) =>
      versionOf(slice) != previous.versionOf(slice);

  Set<StateSlice> changedSlicesSince(KChartState previous) => {
        for (final slice in StateSlice.values)
          if (hasChangedSince(previous, slice)) slice,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KChartState &&
          revision == other.revision &&
          versions == other.versions &&
          viewport == other.viewport &&
          layout == other.layout &&
          crosshair == other.crosshair &&
          historyPaging == other.historyPaging;

  @override
  int get hashCode => Object.hash(
        revision,
        versions,
        viewport,
        layout,
        crosshair,
        historyPaging,
      );
}
