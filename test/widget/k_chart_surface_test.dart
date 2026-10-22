import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/widgets.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/k_chart_theme.dart';
import 'package:m_k_chart/src/controller/k_chart_candidate_api.dart';
import 'package:m_k_chart/src/controller/k_chart_facade.dart' as binding;
import 'package:m_k_chart/src/drawing/chart_drawing_editor.dart';
import 'package:m_k_chart/src/interaction/interaction.dart';
import 'package:m_k_chart/src/render/chart_layer_geometry.dart';
import 'package:m_k_chart/src/render/standard_chart_layers.dart';
import 'package:m_k_chart/src/widget/chart_gesture_region.dart';
import 'package:m_k_chart/src/widget/k_chart_frame.dart';
import 'package:m_k_chart/src/widget/k_chart_overlays.dart';
import 'package:m_k_chart/src/widget/k_chart_surface.dart';
import 'package:m_k_chart/src/render/render_snapshot.dart';
import 'package:m_k_chart/src/viewport/chart_drawing_anchor_projector.dart';
import 'package:m_k_chart/src/viewport/chart_x_transform.dart';

import '../support/v2_kline_fixture.dart';

void main() {
  final candles = buildV2KlineFixture(100);
  final series = KlineSeries.fromKline(candles.first);
  final theme = KChartTheme.light();
  KChartController create({
    Iterable<Kline>? data,
    KChartOptions? options,
    KChartHistoryLoader? historyLoader,
  }) {
    final controller = KChartController(
      series: series,
      initialData: data ?? candles,
      options: options,
      historyLoader: historyLoader,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  Widget surface(
    KChartController controller, {
    double width = 480,
    double height = 500,
    bool enabled = true,
    Key? key,
    WidgetBuilder? emptyBuilder,
    int? currentTime,
    ValueChanged<ChartDrawingAnchor>? onDrawingAnchor,
    ValueChanged<ChartDrawingAnchor?>? onDrawingHover,
    ChartDrawing? drawingPreview,
    bool drawingEditingEnabled = false,
    bool drawingSnapToOhlc = false,
    String? selectedDrawingId,
    ValueChanged<String?>? onDrawingSelectionChanged,
    void Function(List<ChartDrawing>, List<ChartDrawing>)?
        onDrawingEditCommitted,
  }) =>
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            height: height,
            child: KChartSurface(
              key: key,
              controller: controller,
              style: theme,
              currentTime: currentTime ?? candles.last.openTime + 10000,
              interactionEnabled: enabled,
              emptyBuilder: emptyBuilder,
              onDrawingAnchor: onDrawingAnchor,
              onDrawingHover: onDrawingHover,
              drawingPreview: drawingPreview,
              drawingEditingEnabled: drawingEditingEnabled,
              drawingSnapToOhlc: drawingSnapToOhlc,
              selectedDrawingId: selectedDrawingId,
              onDrawingSelectionChanged: onDrawingSelectionChanged,
              onDrawingEditCommitted: onDrawingEditCommitted,
            ),
          ),
        ),
      );

  Future<void> mount(WidgetTester tester, Widget widget) async {
    await tester.pumpWidget(widget);
    await tester.pump(); // 等待帧后挂载/布局通知对应的绘制帧。
  }

  testWidgets('挂载、重建、卸载只借用控制器，布局通知不在 build 中发出', (tester) async {
    final chart = create();
    var notifications = 0;
    chart.addListener(() {
      expect(
        SchedulerBinding.instance.schedulerPhase,
        isNot(SchedulerPhase.persistentCallbacks),
      );
      notifications++;
    });
    await mount(tester, surface(chart));
    expect(chart.value.viewportInfo.isAttached, isTrue);
    expect(chart.value.viewportInfo.hasLayout, isTrue);
    expect(find.byType(CustomPaint), findsOneWidget);
    final revision = chart.value.revision;
    final batch = binding.runtimeForKChartWidget(chart).value.indicatorBatch;
    await mount(tester, surface(chart));
    expect(chart.value.revision, revision);
    expect(
      binding.runtimeForKChartWidget(chart).value.indicatorBatch,
      same(batch),
    );
    expect(notifications, 2); // 挂载、首个有效宽度；普通重建没有重复通知。
    await tester.pumpWidget(const SizedBox());
    expect(chart.value.viewportInfo.isAttached, isFalse);
    expect(chart.isDisposed, isFalse);
    chart.updateKline(
      candles.last.copyWith(close: candles.last.close + 0.1),
      session: chart.session,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('非视觉配置通知不重建画面且不禁用命中；视觉配置仍刷新', (tester) async {
    final chart = create();
    await mount(tester, surface(chart));
    final overlayFinder = find.byType(KChartOverlaysView);
    final before = tester.widget<KChartOverlaysView>(overlayFinder);
    final revision = chart.value.revision;

    chart.setOptions(
      chart.value.options.copyWith(historyThresholdItems: 5),
    );
    expect(chart.value.revision, greaterThan(revision));
    await tester.pump();
    expect(tester.widget<KChartOverlaysView>(overlayFinder), same(before));

    await tester.pumpWidget(
      surface(chart, currentTime: candles.last.openTime + 11000),
    );
    final clockFrame = tester.widget<KChartOverlaysView>(overlayFinder).frame;
    expect(clockFrame.snapshot.layout, same(before.frame.snapshot.layout));
    expect(
      clockFrame.snapshot.versions.layout,
      before.frame.snapshot.versions.layout,
    );
    expect(
      clockFrame.snapshot.versions.clock,
      before.frame.snapshot.versions.clock + 1,
    );

    // 跳过重建时帧已接到最新 revision，点击仍应读取最新 Controller。
    await tester.tapAt(const Offset(120, 180));
    await tester.pump();
    expect(chart.value.selection, isNotNull);
    final selected = tester.widget<KChartOverlaysView>(overlayFinder);
    expect(selected, isNot(same(before)));

    chart.setOptions(chart.value.options.copyWith(gridColumns: 3));
    await tester.pump();
    expect(
      tester.widget<KChartOverlaysView>(overlayFinder),
      isNot(same(selected)),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('控制器通知可安全驱动上层 ValueListenableBuilder，包括卸载', (tester) async {
    final chart = create();
    final show = ValueNotifier(true);
    addTearDown(show.dispose);
    await mount(
      tester,
      ValueListenableBuilder<KChartViewState>(
        valueListenable: chart,
        builder: (context, value, _) => ValueListenableBuilder<bool>(
          valueListenable: show,
          builder: (context, visible, _) =>
              visible ? surface(chart) : const SizedBox(),
        ),
      ),
    );
    show.value = false;
    await tester.pump();
    await tester.pump();
    expect(chart.value.viewportInfo.isAttached, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('换控制器解绑旧实例、清除旧帧，不销毁任一控制器', (tester) async {
    final first = create();
    final second = create(data: candles.take(40));
    await mount(tester, surface(first));
    await tester.tapAt(const Offset(120, 180));
    await tester.pump();
    expect(first.value.selection, isNotNull);
    await mount(tester, surface(second));
    expect(first.value.viewportInfo.isAttached, isFalse);
    expect(second.value.viewportInfo.isAttached, isTrue);
    expect(second.value.selection, isNull);
    first.clearSelection();
    first.scrollToTime(epochMilliseconds: candles[10].openTime);
    await tester.pump();
    expect(second.value.data.length, 40);
    expect(first.isDisposed || second.isDisposed, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('同一帧替换 Widget key 可以重挂同一控制器', (tester) async {
    final chart = create();
    await mount(tester, surface(chart, key: const ValueKey('a')));
    await mount(tester, surface(chart, key: const ValueKey('b')));
    expect(chart.value.viewportInfo.isAttached, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('不同控制器双图独立，同一控制器双图明确拒绝', (tester) async {
    final first = create();
    final second = create();
    Widget pair(KChartController right) => Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: [
              SizedBox(
                width: 300,
                height: 500,
                child: surface(first, width: 300),
              ),
              SizedBox(
                width: 300,
                height: 500,
                child: surface(right, width: 300),
              ),
            ],
          ),
        );
    await mount(tester, pair(second));
    expect(
      first.value.viewportInfo.isAttached &&
          second.value.viewportInfo.isAttached,
      isTrue,
    );
    await tester.tapAt(const Offset(100, 180));
    await tester.pump();
    expect(first.value.selection, isNotNull);
    expect(second.value.selection, isNull);
    await tester.pumpWidget(pair(first));
    expect(tester.takeException(), isA<StateError>());
    expect(first.value.viewportInfo.isAttached, isTrue);
    expect(second.value.viewportInfo.isAttached, isFalse);
  });

  testWidgets('尺寸变化保持缩放，零宽再恢复不发生非法布局或重新首屏缩放', (tester) async {
    final chart = create();
    await mount(tester, surface(chart));
    final runtime = binding.runtimeForKChartWidget(chart);
    final extent = runtime.value.viewport.itemExtent;
    await mount(tester, surface(chart, width: 320));
    expect(runtime.value.viewport.width, 320);
    expect(runtime.value.viewport.itemExtent, extent);
    await mount(tester, surface(chart, width: 0));
    expect(runtime.value.viewport.width, 0);
    expect(find.byType(CustomPaint), findsNothing);
    await mount(tester, surface(chart));
    expect(runtime.value.viewport.width, 480);
    expect(runtime.value.viewport.itemExtent, extent);
    expect(tester.takeException(), isNull);
  });

  testWidgets('空态不生成假行情，首次数据到达自动绘制', (tester) async {
    final chart = create(data: []);
    Widget empty(BuildContext context) => const Text('暂无行情');
    await mount(tester, surface(chart, emptyBuilder: empty));
    expect(find.text('暂无行情'), findsOneWidget);
    expect(chart.value.viewportInfo.hasLayout, isTrue);
    chart.appendData(candles, session: chart.session);
    await tester.pump();
    expect(find.text('暂无行情'), findsNothing);
    expect(find.byType(CustomPaint), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('主副图分别命中，尾部替换与新增不消除选中，拖动才清除', (tester) async {
    final chart = create(
      options: KChartOptions(
        secondaryPanels: [KChartSecondaryPanelOptions(id: 'volume')],
      ),
    );
    await mount(tester, surface(chart));
    await tester.tapAt(const Offset(150, 180));
    await tester.pump();
    expect(chart.value.selection!.panelId, 'main');
    await tester.tapAt(const Offset(150, 450));
    await tester.pump();
    final selected = chart.value.selection!;
    expect(selected.panelId, 'volume');
    expect(selected.value, inInclusiveRange(0, 1));
    chart.updateKline(
      candles.last.copyWith(close: candles.last.close + 0.1),
      session: chart.session,
    );
    await tester.pump();
    chart.appendData(
      buildV2KlineFixture(1, startIndex: 100),
      session: chart.session,
    );
    await tester.pump();
    expect(chart.value.selection!.candle.openTime, selected.candle.openTime);
    expect(chart.value.selection!.value, selected.value);
    await tester.drag(find.byType(KChartSurface), const Offset(80, 0));
    await tester.pumpAndSettle();
    expect(chart.value.selection, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('绘图模式只接收主图锚点，不选中副图或拖动视口', (tester) async {
    final chart = create(
      options: KChartOptions(
        secondaryPanels: [KChartSecondaryPanelOptions(id: 'volume')],
      ),
    );
    final anchors = <ChartDrawingAnchor>[];
    await mount(tester, surface(chart, onDrawingAnchor: anchors.add));
    final before = chart.value.viewportInfo;
    await tester.tapAt(const Offset(150, 180));
    await tester.pump();
    expect(anchors, hasLength(1));
    expect(anchors.single.epochMilliseconds, greaterThan(0));
    expect(anchors.single.price.isFinite, isTrue);
    expect(chart.value.selection, isNull);
    await tester.tapAt(const Offset(150, 450));
    await tester.pump();
    expect(anchors, hasLength(1), reason: '副图不能为主图绘图落点');
    await tester.drag(find.byType(KChartSurface), const Offset(80, 0));
    await tester.pump();
    expect(chart.value.viewportInfo.visibleStartTime, before.visibleStartTime);
    expect(chart.value.viewportInfo.visibleEndTime, before.visibleEndTime);
    expect(chart.value.selection, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('参数栏和时间轴不命中，长按结束隐藏十字线', (tester) async {
    final chart = create(
      options: KChartOptions(
        secondaryPanels: [KChartSecondaryPanelOptions(id: 'volume')],
      ),
    );
    await mount(tester, surface(chart));
    await tester.tapAt(const Offset(150, 8));
    await tester.pump();
    expect(chart.value.selection, isNull);
    await tester.tapAt(const Offset(150, 335));
    await tester.pump();
    expect(chart.value.selection, isNull);
    final touch = await tester.startGesture(const Offset(150, 180));
    await tester.pump(const Duration(seconds: 1));
    expect(chart.value.selection, isNotNull);
    await touch.up();
    await tester.pump();
    expect(chart.value.selection, isNull);
  });

  testWidgets('禁止交互不禁止数据写入或程序导航', (tester) async {
    final chart = create();
    await mount(tester, surface(chart, enabled: false));
    expect(find.byType(ChartGestureRegion), findsNothing);
    await tester.tapAt(const Offset(150, 180));
    await tester.pump();
    expect(chart.value.selection, isNull);
    chart.scrollToTime(epochMilliseconds: candles[10].openTime);
    chart.updateKline(
      candles.last.copyWith(close: candles.last.close + 0.1),
      session: chart.session,
    );
    await tester.pump();
    expect(chart.value.viewportInfo.isAtLatest, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('最新价格箭头点击回到最新且不穿透选中', (tester) async {
    final chart = create();
    await mount(tester, surface(chart));
    chart.scrollToTime(epochMilliseconds: candles[10].openTime);
    await tester.pump();
    final runtime = binding.runtimeForKChartWidget(chart);
    final frame = KChartFrame.project(
      runtime: runtime,
      size: const Size(480, 500),
      style: theme,
      currentTime: candles.last.openTime + 10000,
      versions: const RenderSnapshotVersions(),
    );
    final pipeline = StandardChartRenderPipeline();
    addTearDown(pipeline.dispose);
    final marker =
        latestPriceMarkerHitRegionFor(frame.snapshot, pipeline.cache)!;
    expect(marker.showsChevron, isTrue);
    await tester.tapAt(marker.bounds.center);
    await tester.pump();
    expect(chart.value.viewportInfo.isAtLatest, isTrue);
    expect(chart.value.selection, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('绘图模式点击最新价格箭头仍回到最新，不生成锚点', (tester) async {
    final chart = create();
    final anchors = <ChartDrawingAnchor>[];
    await mount(tester, surface(chart, onDrawingAnchor: anchors.add));
    chart.scrollToTime(epochMilliseconds: candles[10].openTime);
    await tester.pump();
    final frame = KChartFrame.project(
      runtime: binding.runtimeForKChartWidget(chart),
      size: const Size(480, 500),
      style: theme,
      currentTime: candles.last.openTime + 10000,
      versions: const RenderSnapshotVersions(),
    );
    final pipeline = StandardChartRenderPipeline();
    addTearDown(pipeline.dispose);
    final marker =
        latestPriceMarkerHitRegionFor(frame.snapshot, pipeline.cache)!;
    expect(marker.showsChevron, isTrue);
    await tester.tapAt(marker.bounds.center);
    await tester.pump();
    expect(chart.value.viewportInfo.isAtLatest, isTrue);
    expect(anchors, isEmpty);
    expect(chart.value.selection, isNull);
  });

  testWidgets('绘图预览随主图指针移动绘制，离开图表后清除悬停锚点', (tester) async {
    final chart = create();
    final anchors = <ChartDrawingAnchor?>[];
    final preview = ChartDrawing(
      id: 'preview',
      kind: ChartDrawingKind.trendLine,
      anchors: [
        ChartDrawingAnchor(
          epochMilliseconds: candles[30].openTime,
          price: candles[30].close,
        ),
        ChartDrawingAnchor(
          epochMilliseconds: candles[40].openTime,
          price: candles[40].close,
        ),
      ],
    );
    await mount(
      tester,
      surface(
        chart,
        onDrawingAnchor: (_) {},
        onDrawingHover: anchors.add,
        drawingPreview: preview,
      ),
    );
    expect(find.byType(CustomPaint), findsNWidgets(2));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: const Offset(150, 180));
    await gesture.moveTo(const Offset(150, 180));
    await tester.pump();
    expect(anchors, hasLength(1));
    expect(anchors.single, isNotNull);
    await gesture.moveTo(const Offset(150, 520));
    await tester.pump();
    expect(anchors.last, isNull);
    await gesture.removePointer();
    expect(tester.takeException(), isNull);
  });

  testWidgets('编辑模式可命中绘图、显示锚点并拖动控制点', (tester) async {
    final chart = create();
    final drawing = ChartDrawing(
      id: 'editable-trend',
      kind: ChartDrawingKind.trendLine,
      anchors: [
        ChartDrawingAnchor(
          epochMilliseconds: candles[35].openTime,
          price: candles[35].close,
        ),
        ChartDrawingAnchor(
          epochMilliseconds: candles[65].openTime,
          price: candles[65].close,
        ),
      ],
    );
    chart.setOverlays(session: chart.session, drawings: [drawing]);
    final selections = <String?>[];
    final editCommits = <(List<ChartDrawing>, List<ChartDrawing>)>[];
    await mount(
      tester,
      surface(
        chart,
        drawingEditingEnabled: true,
        drawingSnapToOhlc: true,
        onDrawingSelectionChanged: selections.add,
        onDrawingEditCommitted: (before, after) =>
            editCommits.add((before, after)),
      ),
    );
    final runtime = binding.runtimeForKChartWidget(chart);
    final frame = KChartFrame.project(
      runtime: runtime,
      size: const Size(480, 500),
      style: theme,
      currentTime: candles.last.openTime + 10000,
      versions: const RenderSnapshotVersions(),
    );
    final points = ChartDrawingAnchorProjector.project(
      drawing: drawing,
      xTransform: ChartXTransform(
        viewport: runtime.value.viewport,
        data: runtime.value.data,
      ),
      priceTransform: ChartLayerGeometry.rangeFor(
        frame.snapshot,
        'main',
      ).transform(frame.snapshot.layout.mainPanel.bounds),
      localXOffset: frame.snapshot.layout.drawingBounds.left,
    );
    final bodyPoint = Offset(
      (points.first.localX + points.last.localX) / 2,
      (points.first.localY + points.last.localY) / 2,
    );
    await tester.tapAt(bodyPoint);
    await tester.pump();
    expect(selections.last, drawing.id);

    final control = Offset(points.first.localX, points.first.localY);
    const dragDelta = Offset(24, 18);
    final expectedRawAnchor = frame.hitTest(control + dragDelta)!;
    final expectedAnchor = ChartDrawingOhlcSnapper.snap(
      anchor: ChartDrawingAnchor(
        epochMilliseconds: expectedRawAnchor.openTime,
        price: expectedRawAnchor.price,
      ),
      data: candles,
    ).anchor;
    await tester.dragFrom(control, dragDelta);
    await tester.pumpAndSettle();
    final moved = chart.value.overlays.drawings.single.anchors.first;
    expect(moved, isNot(drawing.anchors.first));
    expect(moved, expectedAnchor);
    expect(editCommits, hasLength(1));
    expect(editCommits.single.$1.single.anchors.first, drawing.anchors.first);
    expect(editCommits.single.$2.single.anchors.first, moved);
    expect(chart.value.selection, isNull, reason: '编辑模式不显示 K 线信息面板');
    expect(tester.takeException(), isNull);
  });

  testWidgets('编辑模式拖动绘图本体时所有锚点按相同位移整体移动', (tester) async {
    final chart = create();
    final drawing = ChartDrawing(
      id: 'movable-trend',
      kind: ChartDrawingKind.trendLine,
      anchors: [
        ChartDrawingAnchor(
          epochMilliseconds: candles[35].openTime,
          price: candles[35].close,
        ),
        ChartDrawingAnchor(
          epochMilliseconds: candles[65].openTime,
          price: candles[65].close,
        ),
      ],
    );
    chart.setOverlays(session: chart.session, drawings: [drawing]);
    final commits = <(List<ChartDrawing>, List<ChartDrawing>)>[];
    await mount(
      tester,
      surface(
        chart,
        drawingEditingEnabled: true,
        onDrawingEditCommitted: (before, after) => commits.add((before, after)),
      ),
    );
    final runtime = binding.runtimeForKChartWidget(chart);
    final frame = KChartFrame.project(
      runtime: runtime,
      size: const Size(480, 500),
      style: theme,
      currentTime: candles.last.openTime + 10000,
      versions: const RenderSnapshotVersions(),
    );
    final points = ChartDrawingAnchorProjector.project(
      drawing: drawing,
      xTransform: ChartXTransform(
        viewport: runtime.value.viewport,
        data: runtime.value.data,
      ),
      priceTransform: ChartLayerGeometry.rangeFor(
        frame.snapshot,
        'main',
      ).transform(frame.snapshot.layout.mainPanel.bounds),
      localXOffset: frame.snapshot.layout.drawingBounds.left,
    );
    final body = Offset(
      (points.first.localX + points.last.localX) / 2,
      (points.first.localY + points.last.localY) / 2,
    );
    await tester.dragFrom(body, const Offset(24, 18));
    await tester.pumpAndSettle();
    final moved = chart.value.overlays.drawings.single;
    final timeDelta = moved.anchors.first.epochMilliseconds -
        drawing.anchors.first.epochMilliseconds;
    final priceDelta = moved.anchors.first.price - drawing.anchors.first.price;
    expect(timeDelta, isNot(0));
    expect(priceDelta, isNot(0));
    expect(
      moved.anchors.last.epochMilliseconds -
          drawing.anchors.last.epochMilliseconds,
      timeDelta,
    );
    expect(moved.anchors.last.price - drawing.anchors.last.price, priceDelta);
    expect(commits, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('拖动中新增数据后旧几何意图不能覆盖新窗口', (tester) async {
    final chart = create();
    await mount(tester, surface(chart));
    final oldRegion =
        tester.widget<ChartGestureRegion>(find.byType(ChartGestureRegion));
    final viewport = oldRegion.viewport();
    chart.appendData(
      buildV2KlineFixture(1, startIndex: 100),
      session: chart.session,
    );
    oldRegion.onIntent(
      ChartViewportIntent(viewport, source: ChartViewportChangeSource.pan),
    );
    await tester.pump();
    expect(chart.value.data.length, 101);
    expect(binding.runtimeForKChartWidget(chart).value.viewport.itemCount, 101);
    expect(tester.takeException(), isNull);
  });

  testWidgets('挂载触发历史请求，卸载后迟到响应不写入', (tester) async {
    final response = Completer<KChartHistoryPage>();
    var calls = 0;
    final chart = create(
      data: candles.skip(80),
      historyLoader: (_) {
        calls++;
        return response.future;
      },
    );
    await mount(tester, surface(chart));
    expect(calls, 1);
    await tester.pumpWidget(const SizedBox());
    response
        .complete(KChartHistoryPage(candles: candles.take(80), hasMore: false));
    await tester.pump();
    expect(chart.value.data.length, 20);
    expect(chart.isDisposed, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('相同数据长度的控制器切换后，旧识别器不能写入新图', (tester) async {
    final first = create();
    final second = create();
    await mount(tester, surface(first));
    final oldRegion =
        tester.widget<ChartGestureRegion>(find.byType(ChartGestureRegion));
    final oldViewport = oldRegion.viewport();
    await mount(tester, surface(second));
    final revision = second.value.revision;
    oldRegion.onTapUp!(const Offset(150, 180));
    oldRegion.onIntent(
      ChartViewportIntent(
        oldViewport.scrollByItems(5),
        source: ChartViewportChangeSource.pan,
      ),
    );
    await tester.pump();
    expect(second.value.revision, revision);
    expect(second.value.selection, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('双指缩放改变槽宽但保留点击选中的数据身份', (tester) async {
    final chart = create();
    await mount(tester, surface(chart));
    await tester.tapAt(const Offset(150, 180));
    await tester.pump();
    final time = chart.value.selection!.candle.openTime;
    final extent =
        binding.runtimeForKChartWidget(chart).value.viewport.itemExtent;
    final first = await tester.startGesture(const Offset(180, 240));
    final second = await tester.startGesture(const Offset(260, 240));
    await tester.pump();
    await first.moveTo(const Offset(140, 240));
    await second.moveTo(const Offset(300, 240));
    await tester.pump();
    await first.moveTo(const Offset(100, 240));
    await second.moveTo(const Offset(340, 240));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pumpAndSettle();
    expect(
      binding.runtimeForKChartWidget(chart).value.viewport.itemExtent,
      greaterThan(extent),
    );
    expect(chart.value.selection!.candle.openTime, time);
    expect(tester.takeException(), isNull);
  });
}
