import '../interaction/interaction.dart';
import 'k_chart_state.dart';
import '../viewport/viewport.dart';

/// A typed input accepted by [KChartController].
///
/// Events describe what changed. Concrete payloads are added by their owning
/// data, viewport, interaction, layout, and theme tasks.
abstract interface class KChartEvent {
  Set<StateSlice> get changedSlices;
}

final class ChartDataChanged implements KChartEvent {
  const ChartDataChanged();

  @override
  Set<StateSlice> get changedSlices => const {StateSlice.data};
}

final class ChartViewportChanged implements KChartEvent {
  const ChartViewportChanged(this.viewport);

  final ChartViewport viewport;

  @override
  Set<StateSlice> get changedSlices => const {StateSlice.viewport};
}

final class ChartSelectionChanged implements KChartEvent {
  const ChartSelectionChanged(this.crosshair);

  final ChartCrosshairState crosshair;

  @override
  Set<StateSlice> get changedSlices => const {StateSlice.selection};
}

final class ChartHistoryPagingChanged implements KChartEvent {
  const ChartHistoryPagingChanged(this.state);

  final ChartHistoryPagingState state;

  @override
  Set<StateSlice> get changedSlices => const {StateSlice.history};
}

final class ChartLayoutChanged implements KChartEvent {
  const ChartLayoutChanged(this.layout);

  final ChartLayoutModel layout;

  @override
  Set<StateSlice> get changedSlices => const {StateSlice.layout};
}

final class ChartThemeChanged implements KChartEvent {
  const ChartThemeChanged();

  @override
  Set<StateSlice> get changedSlices => const {StateSlice.theme};
}
