import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/controller/controller.dart';

void main() {
  group('KChartState version protocol', () {
    test('starts with zero aggregate and slice versions', () {
      const state = KChartState();

      expect(state.revision, 0);
      for (final slice in StateSlice.values) {
        expect(state.versionOf(slice), 0);
      }
    });

    test('empty transaction preserves state identity', () {
      const state = KChartState();

      expect(identical(state, state.bump(const [])), isTrue);
    });

    test('one transaction bumps aggregate revision only once', () {
      const before = KChartState();
      final after = before.bump(const [
        StateSlice.data,
        StateSlice.viewport,
        StateSlice.data,
      ]);

      expect(after.revision, 1);
      expect(after.versionOf(StateSlice.data), 1);
      expect(after.versionOf(StateSlice.viewport), 1);
      expect(after.versionOf(StateSlice.selection), 0);
    });

    test('successive transactions keep independent slice versions', () {
      const initial = KChartState();
      final selected = initial.bump(const [StateSlice.selection]);
      final themed = selected.bump(const [StateSlice.theme]);

      expect(themed.revision, 2);
      expect(themed.versionOf(StateSlice.selection), 1);
      expect(themed.versionOf(StateSlice.theme), 1);
      expect(themed.versionOf(StateSlice.data), 0);
      expect(themed.versionOf(StateSlice.viewport), 0);
      expect(themed.versionOf(StateSlice.layout), 0);
    });

    test('reports the exact changed slices between snapshots', () {
      const before = KChartState();
      final after = before.bump(const [
        StateSlice.layout,
        StateSlice.theme,
      ]);

      expect(
        after.changedSlicesSince(before),
        {StateSlice.layout, StateSlice.theme},
      );
      expect(after.hasChangedSince(before, StateSlice.data), isFalse);
    });

    test('value equality supports deterministic repaint comparisons', () {
      const left = KChartState(
        revision: 2,
        versions: StateSliceVersions(data: 1, viewport: 1),
      );
      const right = KChartState(
        revision: 2,
        versions: StateSliceVersions(data: 1, viewport: 1),
      );

      expect(left, right);
      expect(left.hashCode, right.hashCode);
    });
  });
}
