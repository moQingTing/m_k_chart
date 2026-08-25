import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/controller/controller.dart';
import 'package:m_k_chart/src/interaction/interaction.dart';
import 'package:m_k_chart/src/viewport/viewport.dart';

void main() {
  group('KChartState version protocol', () {
    test('starts with zero aggregate and slice versions', () {
      const state = KChartState();

      expect(state.revision, 0);
      expect(state.viewport, const ChartViewport.initial());
      expect(state.layout, isNull);
      expect(state.crosshair, const ChartCrosshairState.hidden());
      expect(state.historyPaging, const ChartHistoryPagingState());
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

    test('viewport payload is replaced in the same version transaction', () {
      const before = KChartState();
      final viewport = ChartViewport(itemCount: 100, width: 80);

      final after = before.bump(
        const [StateSlice.viewport],
        viewport: viewport,
      );

      expect(after.viewport, viewport);
      expect(after.revision, 1);
      expect(after.versionOf(StateSlice.viewport), 1);
    });

    test('layout payload automatically marks its owning state slice', () {
      const before = KChartState();
      final layout = ChartLayoutModel(width: 200, height: 160);

      final after = before.bump(const [], layout: layout);

      expect(after.layout, layout);
      expect(after.revision, 1);
      expect(after.versionOf(StateSlice.layout), 1);
      expect(after.versionOf(StateSlice.viewport), 0);
    });

    test('crosshair payload automatically marks selection state', () {
      const before = KChartState();
      const crosshair = ChartCrosshairState.visible(localX: 12, localY: 34);

      final after = before.bump(const [], crosshair: crosshair);

      expect(after.crosshair, crosshair);
      expect(after.revision, 1);
      expect(after.versionOf(StateSlice.selection), 1);
    });

    test('history paging payload marks only its dedicated state slice', () {
      const before = KChartState();
      const paging = ChartHistoryPagingState(
        phase: ChartHistoryPagingPhase.loading,
        requestSerial: 1,
      );

      final after = before.bump(const [], historyPaging: paging);

      expect(after.historyPaging, paging);
      expect(after.revision, 1);
      expect(after.versionOf(StateSlice.history), 1);
      expect(after.versionOf(StateSlice.data), 0);
      expect(after.versionOf(StateSlice.viewport), 0);
    });
  });
}
