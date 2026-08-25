import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/controller/controller.dart';
import 'package:m_k_chart/src/viewport/viewport.dart';

void main() {
  group('KChartController', () {
    test('publishes one notification for one non-empty transaction', () {
      final controller = KChartController();
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.dispatchBatch([
        const ChartDataChanged(),
        ChartViewportChanged(ChartViewport(width: 80)),
        const ChartDataChanged(),
      ]);

      expect(controller.value.revision, 1);
      expect(controller.value.versionOf(StateSlice.data), 1);
      expect(controller.value.versionOf(StateSlice.viewport), 1);
      expect(notifications, 1);
    });

    test('does not notify for an empty transaction', () {
      final controller = KChartController();
      final before = controller.value;
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.dispatchBatch(const []);

      expect(identical(controller.value, before), isTrue);
      expect(notifications, 0);
    });

    test('keeps runtime state isolated per chart instance', () {
      final first = KChartController();
      final second = KChartController();

      first.dispatch(
        ChartViewportChanged(
          ChartViewport(itemCount: 100, width: 80).scrollByItems(10),
        ),
      );

      expect(first.value.revision, 1);
      expect(first.value.viewport.scrollOffsetItems, 10);
      expect(second.value.revision, 0);
      expect(second.value.viewport, const ChartViewport.initial());
    });

    test('skips equal viewport payloads and commits the last batch value', () {
      final initial = ChartViewport(itemCount: 100, width: 80);
      final controller = KChartController(
        initialState: KChartState(viewport: initial),
      );
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.dispatch(ChartViewportChanged(initial));
      controller.dispatchBatch([
        ChartViewportChanged(initial.scrollByItems(2)),
        ChartViewportChanged(initial.scrollByItems(4)),
      ]);

      expect(controller.value.revision, 1);
      expect(controller.value.versionOf(StateSlice.viewport), 1);
      expect(controller.value.viewport.scrollOffsetItems, 4);
      expect(notifications, 1);
    });

    test('keeps layout payload atomic and skips structurally equal values', () {
      final initial = ChartLayoutModel(width: 200, height: 160);
      final controller = KChartController(
        initialState: KChartState(
          layout: initial,
          viewport: ChartViewport(width: 200),
        ),
      );
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.dispatch(
        ChartLayoutChanged(ChartLayoutModel(width: 200, height: 160)),
      );
      controller.dispatchBatch([
        ChartLayoutChanged(ChartLayoutModel(width: 240, height: 160)),
        ChartLayoutChanged(ChartLayoutModel(width: 280, height: 160)),
      ]);

      expect(controller.value.revision, 1);
      expect(controller.value.versionOf(StateSlice.layout), 1);
      expect(controller.value.versionOf(StateSlice.viewport), 1);
      expect(controller.value.layout?.width, 280);
      expect(controller.value.viewport.width, 280);
      expect(notifications, 1);
    });

    test('height-only layout changes do not invalidate viewport', () {
      final initial = ChartLayoutModel(width: 200, height: 160);
      final controller = KChartController(
        initialState: KChartState(
          layout: initial,
          viewport: ChartViewport(width: 200),
        ),
      );

      controller.dispatch(
        ChartLayoutChanged(ChartLayoutModel(width: 200, height: 180)),
      );

      expect(controller.value.revision, 1);
      expect(controller.value.versionOf(StateSlice.layout), 1);
      expect(controller.value.versionOf(StateSlice.viewport), 0);
      expect(controller.value.viewport.width, 200);
    });

    test('supports a caller-provided initial snapshot', () {
      const initial = KChartState(
        revision: 4,
        versions: StateSliceVersions(data: 3, viewport: 1),
      );

      final controller = KChartController(initialState: initial);

      expect(identical(controller.value, initial), isTrue);
    });

    test('dispose is idempotent and rejects later mutations', () {
      final controller = KChartController();

      controller.dispose();
      controller.dispose();

      expect(controller.isDisposed, isTrue);
      expect(
        () => controller.dispatch(const ChartDataChanged()),
        throwsStateError,
      );
    });
  });
}
