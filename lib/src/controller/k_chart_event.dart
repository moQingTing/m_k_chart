import 'k_chart_state.dart';

/// A typed input accepted by [KChartController].
///
/// Events describe what changed. Their concrete payloads will be expanded by
/// the owning data, viewport, interaction, layout, and theme tasks.
abstract interface class KChartEvent {
  Set<StateSlice> get changedSlices;
}

final class ChartDataChanged implements KChartEvent {
  const ChartDataChanged();

  @override
  Set<StateSlice> get changedSlices => const {StateSlice.data};
}

final class ChartViewportChanged implements KChartEvent {
  const ChartViewportChanged();

  @override
  Set<StateSlice> get changedSlices => const {StateSlice.viewport};
}

final class ChartSelectionChanged implements KChartEvent {
  const ChartSelectionChanged();

  @override
  Set<StateSlice> get changedSlices => const {StateSlice.selection};
}

final class ChartLayoutChanged implements KChartEvent {
  const ChartLayoutChanged();

  @override
  Set<StateSlice> get changedSlices => const {StateSlice.layout};
}

final class ChartThemeChanged implements KChartEvent {
  const ChartThemeChanged();

  @override
  Set<StateSlice> get changedSlices => const {StateSlice.theme};
}
