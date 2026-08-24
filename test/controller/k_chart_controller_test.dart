import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/controller/controller.dart';

void main() {
  group('KChartController', () {
    test('publishes one notification for one non-empty transaction', () {
      final controller = KChartController();
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.commitStateChange(const [
        StateSlice.data,
        StateSlice.viewport,
        StateSlice.data,
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

      controller.commitStateChange(const []);

      expect(identical(controller.value, before), isTrue);
      expect(notifications, 0);
    });

    test('keeps runtime state isolated per chart instance', () {
      final first = KChartController();
      final second = KChartController();

      first.commitStateChange(const [StateSlice.selection]);

      expect(first.value.revision, 1);
      expect(first.value.versionOf(StateSlice.selection), 1);
      expect(second.value.revision, 0);
      expect(second.value.versionOf(StateSlice.selection), 0);
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
        () => controller.commitStateChange(const [StateSlice.data]),
        throwsStateError,
      );
    });
  });
}
