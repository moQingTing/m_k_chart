import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/k_chart_theme.dart';
import 'package:m_k_chart/src/controller/k_chart_candidate_api.dart';
import 'package:m_k_chart/src/controller/k_chart_facade.dart' as binding;
import 'package:m_k_chart/src/render/render.dart';
import 'package:m_k_chart/src/theme/theme.dart';
import 'package:m_k_chart/src/widget/k_chart_frame.dart';

import '../support/v2_kline_fixture.dart';

void main() {
  test('中间时间轴先画普通时间再画选中时间，旧 Demo 默认仍不重复画中间轴', () {
    final candles = buildV2KlineFixture(100);
    final chart = KChartController(
      series: KlineSeries.fromKline(candles.first),
      initialData: candles,
      options: KChartOptions(
        secondaryPanels: [KChartSecondaryPanelOptions(id: 'sub')],
      ),
    );
    addTearDown(chart.dispose);
    final runtime = binding.runtimeForKChartWidget(chart)..setViewportSize(480);
    runtime.select(
      openTime: candles[80].openTime,
      panelId: 'main',
      price: candles[80].close,
    );
    final frame = KChartFrame.project(
      runtime: runtime,
      size: const Size(480, 500),
      style: KChartTheme.light(),
      versions: const RenderSnapshotVersions(),
      currentTime: candles.last.openTime,
    );
    expect(frame.snapshot.showIntermediateTimeAxis, isTrue);
    final calls = <String>[];
    void paint({required bool enabled}) {
      final pipeline = StandardChartRenderPipeline<ChartRenderStyle>();
      final snapshot = RenderSnapshot<ChartRenderStyle>(
        data: frame.snapshot.data,
        viewport: frame.snapshot.viewport,
        layout: frame.snapshot.layout,
        theme: frame.snapshot.theme,
        versions: const RenderSnapshotVersions(),
        selection: frame.snapshot.selection,
        showIntermediateTimeAxis: enabled,
        axisTimeFormatter: (time, zone) {
          calls.add('axis');
          return '时间';
        },
        crosshairTimeFormatter: (time, code, zone) {
          calls.add('selection');
          return '选中时间';
        },
      );
      final recorder = PictureRecorder();
      pipeline.paint(
        RenderLayerContext(canvas: Canvas(recorder), snapshot: snapshot),
      );
      recorder.endRecording().dispose();
      pipeline.dispose();
    }

    paint(enabled: true);
    expect(calls.where((value) => value == 'axis'), isNotEmpty);
    expect(calls.last, 'selection');
    calls.clear();
    paint(enabled: false);
    expect(calls, ['selection']);
  });
}
