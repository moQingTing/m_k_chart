import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/controller/controller.dart';

void main() {
  test('typed events declare only their owning state slice', () {
    const expectations = <KChartEvent, StateSlice>{
      ChartDataChanged(): StateSlice.data,
      ChartViewportChanged(): StateSlice.viewport,
      ChartSelectionChanged(): StateSlice.selection,
      ChartLayoutChanged(): StateSlice.layout,
      ChartThemeChanged(): StateSlice.theme,
    };

    for (final entry in expectations.entries) {
      expect(entry.key.changedSlices, {entry.value});
    }
  });

  test('a compound input is committed as one controller transaction', () {
    final controller = KChartController();
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.dispatchBatch(const [
      ChartDataChanged(),
      ChartViewportChanged(),
      ChartSelectionChanged(),
    ]);

    expect(controller.value.revision, 1);
    expect(
      controller.value.changedSlicesSince(const KChartState()),
      {StateSlice.data, StateSlice.viewport, StateSlice.selection},
    );
    expect(notifications, 1);
  });
}
