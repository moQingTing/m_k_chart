import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/controller/controller.dart';
import 'package:m_k_chart/src/interaction/interaction.dart';
import 'package:m_k_chart/src/viewport/viewport.dart';

void main() {
  test('typed events declare only their owning state slice', () {
    final expectations = <KChartEvent, StateSlice>{
      const ChartDataChanged(): StateSlice.data,
      const ChartViewportChanged(ChartViewport.initial()): StateSlice.viewport,
      const ChartSelectionChanged(ChartCrosshairState.hidden()):
          StateSlice.selection,
      const ChartHistoryPagingChanged(
        ChartHistoryPagingState(
          phase: ChartHistoryPagingPhase.loading,
          requestSerial: 1,
        ),
      ): StateSlice.history,
      ChartLayoutChanged(_layout()): StateSlice.layout,
      const ChartThemeChanged(): StateSlice.theme,
    };

    for (final entry in expectations.entries) {
      expect(entry.key.changedSlices, {entry.value});
    }
  });

  test('a compound input is committed as one controller transaction', () {
    final controller = KChartController();
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.dispatchBatch([
      const ChartDataChanged(),
      ChartViewportChanged(ChartViewport(width: 80)),
      const ChartSelectionChanged(
        ChartCrosshairState.visible(localX: 10, localY: 20),
      ),
    ]);

    expect(controller.value.revision, 1);
    expect(
      controller.value.changedSlicesSince(const KChartState()),
      {StateSlice.data, StateSlice.viewport, StateSlice.selection},
    );
    expect(notifications, 1);
  });
}

ChartLayoutModel _layout() => ChartLayoutModel(width: 200, height: 160);
