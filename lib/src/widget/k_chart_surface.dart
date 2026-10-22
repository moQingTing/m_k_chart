import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../controller/k_chart_data_coordinator.dart';
import '../controller/k_chart_facade.dart';
import '../drawing/chart_drawing.dart';
import '../drawing/chart_drawing_editor.dart';
import '../drawing/chart_drawing_hit_test.dart';
import '../interaction/interaction.dart';
import '../render/render_layer.dart';
import '../render/render_snapshot.dart';
import '../render/standard_chart_layers.dart';
import '../theme/theme.dart';
import '../viewport/chart_x_transform.dart';
import '../viewport/chart_drawing_anchor_projector.dart';
import '../render/chart_layer_geometry.dart';
import '../render/chart_drawing_renderer.dart';
import 'chart_gesture_region.dart';
import 'k_chart_frame.dart';
import 'k_chart_labels.dart';
import 'k_chart_overlays.dart';
import 'k_chart_render_versions.dart';

/// OPT-04 的内部绘制/输入组件；候选 KChart 已包装此层，但尚未正式公开。
///
/// 它借用唯一 Controller，拥有绘制缓存和手势资源，不负责网络或销毁 Controller。
/// 参数栏和信息面板共用单帧布局；业务回调与时钟由上层管理，便于确定性测试。
/// 保持此层依赖内部 ChartRenderStyle，避免反向依赖旧 Widget/根目录主题实现。
final class KChartSurface extends StatefulWidget {
  const KChartSurface({
    required this.controller,
    required this.style,
    required this.currentTime,
    this.interactionEnabled = true,
    this.emptyBuilder,
    this.labels = const KChartLabels.zhCN(),
    this.selectionBuilder,
    this.onDrawingAnchor,
    this.onDrawingHover,
    this.drawingPreview,
    this.drawingEditingEnabled = false,
    this.drawingSnapToOhlc = false,
    this.selectedDrawingId,
    this.onDrawingSelectionChanged,
    this.onDrawingEditCommitted,
    super.key,
  });

  final KChartController controller;
  final ChartRenderStyle style;
  final int currentTime;
  final bool interactionEnabled;
  final WidgetBuilder? emptyBuilder;
  final KChartLabels labels;
  final KChartSelectionBuilder? selectionBuilder;
  final ValueChanged<ChartDrawingAnchor>? onDrawingAnchor;
  final ValueChanged<ChartDrawingAnchor?>? onDrawingHover;
  final ChartDrawing? drawingPreview;
  final bool drawingEditingEnabled;
  final bool drawingSnapToOhlc;
  final String? selectedDrawingId;
  final ValueChanged<String?>? onDrawingSelectionChanged;
  final void Function(List<ChartDrawing> before, List<ChartDrawing> after)?
      onDrawingEditCommitted;

  @override
  State<KChartSurface> createState() => _KChartSurfaceState();
}

final class _KChartSurfaceState extends State<KChartSurface> {
  late KChartDataCoordinator _runtime;
  late StandardChartRenderPipeline<ChartRenderStyle> _pipeline;
  Object _owner = Object();
  bool _attached = false;
  bool _layoutQueued = false;
  double _desiredWidth = 0;
  bool _rebuildQueued = false;
  bool _handlingIntent = false;
  KChartRenderVersionTracker _renderVersions = KChartRenderVersionTracker();
  KChartFrame? _frame;
  Object _gestureKey = Object();
  ChartInteractionMachine _interaction = ChartInteractionMachine();
  ChartNavigationMachine _navigation = ChartNavigationMachine();
  ChartDrawingAnchor? _lastDrawingHover;
  String? _draggingDrawingId;
  int? _draggingAnchorIndex;
  bool _draggingWholeDrawing = false;
  ChartDrawingAnchor? _dragStartPointerAnchor;
  List<ChartDrawing>? _dragOriginalDrawings;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  void _bind() {
    _runtime = runtimeForKChartWidget(widget.controller);
    _pipeline = StandardChartRenderPipeline<ChartRenderStyle>();
    _renderVersions = KChartRenderVersionTracker();
    _runtime.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(KChartSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      _unbind();
      _owner = Object();
      _attached = false;
      _layoutQueued = false;
      _frame = null;
      _bind();
      _resetGestures();
    } else if (oldWidget.interactionEnabled != widget.interactionEnabled ||
        (oldWidget.onDrawingAnchor == null) !=
            (widget.onDrawingAnchor == null) ||
        oldWidget.onDrawingHover != widget.onDrawingHover ||
        oldWidget.drawingEditingEnabled != widget.drawingEditingEnabled ||
        oldWidget.drawingSnapToOhlc != widget.drawingSnapToOhlc) {
      _resetGestures();
    }
  }

  void _unbind() {
    final runtime = _runtime;
    final owner = _owner;
    _runtime.removeListener(_onChanged);
    _navigation.cancelInertia();
    _pipeline.dispose();
    // dispose/didUpdateWidget 可能正在父级 build 内。延后发布解绑状态，避免让
    // 宿主 ValueListenableBuilder 在构建中被通知；旧租约不能解绑新的实例。
    if (_attached) scheduleMicrotask(() => runtime.detach(owner));
  }

  void _resetGestures() {
    _navigation.cancelInertia();
    _interaction = ChartInteractionMachine();
    _navigation = ChartNavigationMachine();
    _gestureKey = Object();
  }

  void _onChanged() {
    final old = _frame?.state;
    final next = _runtime.value;
    // 数据长度、行情会话或程序导航改变时，旧手势不得继续提交旧几何。
    // 同柱实时刷新不打断手势；手势自身的视口通知也不重置识别器。
    if (old != null &&
        (old.session != next.session ||
            old.data.data.length != next.data.data.length ||
            (!_handlingIntent && old.viewport != next.viewport))) {
      _resetGestures();
    }
    // 分页请求标识、预加载阈值、挂载标志等事务会推进 Controller revision，
    // 但不改变当前画面。此时不重建；命中守卫也按同一视觉输入比较，避免误禁用点击。
    if (old != null && _sameProjectedRuntimeState(old, next)) {
      _frame = _frame!.withRuntimeState(next);
      return;
    }
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_rebuildQueued) return;
      _rebuildQueued = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _rebuildQueued = false;
        if (mounted) setState(() {});
      });
    } else if (mounted) {
      setState(() {});
    }
  }

  void _queueLayout(double width) {
    // 变宽会暂时移除旧手势区域；同时重置机器，避免新区域继承一个未结束的缩放。
    if (_desiredWidth != width) _resetGestures();
    _desiredWidth = width;
    if (_layoutQueued ||
        (_attached && _runtime.value.viewport.width == width)) {
      return;
    }
    _layoutQueued = true;
    final owner = _owner;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 微任务在这一帧所有旧组件的解绑之后执行，支持同帧移除/重挂同一 Controller。
      scheduleMicrotask(() {
        if (!mounted || owner != _owner || _runtime.isDisposed) return;
        _layoutQueued = false;
        if (!_attached) {
          try {
            _runtime.attach(owner);
          } on StateError catch (error, stack) {
            FlutterError.reportError(
              FlutterErrorDetails(
                exception: error,
                stack: stack,
                library: 'm_k_chart',
                context: ErrorDescription('挂载 KChartSurface 时'),
              ),
            );
            return;
          }
          _attached = true;
        }
        // 宿主可在挂载通知中主动销毁控制器；不能随后继续写入宽度。
        if (!_runtime.isDisposed) _runtime.setViewportSize(_desiredWidth);
      });
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
            throw FlutterError('KChartSurface 需要父级提供有限宽度和高度。');
          }
          final size = constraints.biggest;
          _queueLayout(size.width);
          // 首帧/变宽先提交真实布局，再绘制；不能用宽度不一致的快照命中数据。
          if (!_attached ||
              size.isEmpty ||
              _runtime.value.viewport.width != size.width) {
            _frame = null;
            return const SizedBox.expand();
          }
          if (_runtime.value.data.data.isEmpty && widget.emptyBuilder != null) {
            _frame = null;
            return widget.emptyBuilder!(context);
          }
          final versions = _renderVersions.advance(
            state: _runtime.value,
            size: size,
            style: widget.style,
            textScaler: MediaQuery.textScalerOf(context),
            currentTime: widget.currentTime,
          );
          final oldFrame = _frame;
          final KChartFrame frame;
          if (oldFrame != null &&
              identical(oldFrame.state, _runtime.value) &&
              _sameNonClockVersions(oldFrame.snapshot.versions, versions)) {
            frame = oldFrame.snapshot.versions.clock == versions.clock
                ? oldFrame
                : oldFrame.withClock(
                    currentTime: widget.currentTime,
                    versions: versions,
                  );
          } else {
            frame = KChartFrame.project(
              runtime: _runtime,
              size: size,
              style: widget.style,
              currentTime: widget.currentTime,
              textScaler: MediaQuery.textScalerOf(context),
              versions: versions,
            );
          }
          _frame = frame;
          final semantics = _chartSemantics(frame, context);
          final canvas = Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                child: CustomPaint(
                  painter: _KChartSurfacePainter(frame.snapshot, _pipeline),
                  child: const SizedBox.expand(),
                ),
              ),
              if (widget.drawingPreview != null)
                IgnorePointer(
                  child: CustomPaint(
                    painter: _KChartDrawingPreviewPainter(
                      frame: frame,
                      drawing: widget.drawingPreview!,
                      color: widget.style.drawingColor,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              if (widget.selectedDrawingId != null &&
                  _runtime.value.overlays.drawings.any(
                    (drawing) =>
                        drawing.id == widget.selectedDrawingId &&
                        drawing.style.visible,
                  ))
                IgnorePointer(
                  child: CustomPaint(
                    painter: _KChartDrawingSelectionPainter(
                      frame: frame,
                      drawingId: widget.selectedDrawingId!,
                      color: widget.style.drawingColor,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              KChartOverlaysView(
                frame: frame,
                selection: _runtime.view.value.selection,
                labels: widget.labels,
                selectionBuilder: widget.selectionBuilder,
              ),
            ],
          );
          if (!widget.interactionEnabled || _runtime.value.data.data.isEmpty) {
            return Semantics(
              container: true,
              label: semantics.label,
              value: semantics.value,
              hint: semantics.hint,
              textDirection: semantics.textDirection,
              child: canvas,
            );
          }
          // 绘图落点独占点按；不安装浏览手势，避免首点被十字线/平移消费。
          // 切换模式时重置旧识别器，旧手势不得写入新的绘图草稿。
          if (widget.onDrawingAnchor != null) {
            final owner = _owner;
            final gestureKey = _gestureKey;
            return MouseRegion(
              onExit: (_) => _clearDrawingHover(),
              child: Listener(
                onPointerHover: (event) {
                  if (owner == _owner && gestureKey == _gestureKey) {
                    _onDrawingHoverAt(event.localPosition);
                  }
                },
                onPointerMove: (event) {
                  if (owner == _owner && gestureKey == _gestureKey) {
                    _onDrawingHoverAt(event.localPosition);
                  }
                },
                onPointerDown: (event) {
                  if (owner == _owner && gestureKey == _gestureKey) {
                    _onDrawingHoverAt(event.localPosition);
                  }
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) {
                    if (owner == _owner && gestureKey == _gestureKey) {
                      _onDrawingTap(details.localPosition);
                    }
                  },
                  child: canvas,
                ),
              ),
            );
          }
          if (widget.drawingEditingEnabled) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              dragStartBehavior: DragStartBehavior.down,
              onTapUp: (details) => _selectDrawing(details.localPosition),
              onPanStart: (details) => _startDrawingEdit(details.localPosition),
              onPanUpdate: (details) =>
                  _updateDrawingEdit(details.localPosition),
              onPanEnd: (_) => _finishDrawingEdit(),
              onPanCancel: _cancelDrawingEdit,
              child: canvas,
            );
          }
          final gestureKey = _gestureKey;
          final owner = _owner;
          return ChartGestureRegion(
            key: ObjectKey(gestureKey),
            machine: _interaction,
            navigationMachine: _navigation,
            viewport: () => _runtime.value.viewport,
            semantics: semantics,
            excludeChildSemantics: true,
            // 旧识别器可能在这一帧销毁前发送结束/取消回调，不能写入新控制器。
            onIntent: (intent) {
              if (owner == _owner && gestureKey == _gestureKey) {
                _onIntent(intent);
              }
            },
            onTapUp: (position) {
              if (owner == _owner && gestureKey == _gestureKey) {
                _onTap(position);
              }
            },
            child: canvas,
          );
        },
      );

  ChartSemanticsConfiguration _chartSemantics(
    KChartFrame frame,
    BuildContext context,
  ) {
    final state = _runtime.view.value;
    final labels = widget.labels;
    final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
    if (state.data.isEmpty) {
      return ChartSemanticsConfiguration(
        label: labels.chart,
        value: labels.noData,
        hint: labels.zoomHint,
        textDirection: direction,
      );
    }
    final selected = state.selection;
    final candle = selected?.candle ?? state.data.last;
    final theme = widget.style;
    final prefix = selected == null ? labels.latest : labels.selected;
    final selectedValue = selected == null
        ? ''
        : '，${labels.selectedValue} '
            '${selected.panelId == 'main' ? theme.formatMainValue(selected.value) : theme.formatSecondaryValue(selected.value)}';
    return ChartSemanticsConfiguration(
      label: '${labels.chart} ${candle.symbol} ${candle.interval.code}',
      value: '$prefix ${frame.snapshot.formatCrosshairTime(candle)}，'
          '${labels.open} ${theme.formatMainValue(candle.open)}，'
          '${labels.high} ${theme.formatMainValue(candle.high)}，'
          '${labels.low} ${theme.formatMainValue(candle.low)}，'
          '${labels.close} ${theme.formatMainValue(candle.close)}，'
          '${labels.volume} ${theme.formatSecondaryValue(candle.baseVolume)}，'
          '${labels.amount} ${theme.formatSecondaryValue(candle.quoteVolume)}'
          '$selectedValue',
      hint: labels.zoomHint,
      textDirection: direction,
      // 实时尾柱可能每秒变化，不用 liveRegion 避免读屏持续打断用户。
      onTap: widget.interactionEnabled && !state.viewportInfo.isAtLatest
          ? widget.controller.scrollToLatest
          : null,
      onIncrease: widget.interactionEnabled ? () => _semanticZoom(1.25) : null,
      onDecrease: widget.interactionEnabled ? () => _semanticZoom(0.8) : null,
      increasedValue: labels.zoomedIn,
      decreasedValue: labels.zoomedOut,
    );
  }

  void _semanticZoom(double scale) {
    if (!_canHit) return;
    final viewport = _runtime.value.viewport;
    final center = viewport.width / 2;
    if (!_interaction.beginScale(viewport: viewport, focalLocalX: center)) {
      return;
    }
    try {
      final intent = _interaction.updateScale(
        scale: scale,
        focalLocalX: center,
      );
      if (intent != null) _onIntent(intent);
    } finally {
      _interaction.endScale();
    }
  }

  /// 尚未绘制新数据时，拒绝旧画面的命中；下一帧会基于新状态恢复。
  bool get _canHit =>
      mounted &&
      widget.interactionEnabled &&
      !_runtime.isDisposed &&
      _frame?.state.revision == _runtime.value.revision;

  /// 拖动中的绘图写回会推进 revision，但不会改变数据/视口几何；继续使用该帧变换。
  bool get _canUseFrameGeometry =>
      mounted &&
      widget.interactionEnabled &&
      !_runtime.isDisposed &&
      _frame != null &&
      identical(_frame!.state.session, _runtime.value.session) &&
      identical(_frame!.state.data, _runtime.value.data) &&
      _frame!.state.viewport == _runtime.value.viewport;

  void _onTap(Offset position) {
    if (!_canHit) return;
    final marker =
        latestPriceMarkerHitRegionFor(_frame!.snapshot, _pipeline.cache);
    if (marker != null && marker.contains(position)) {
      if (marker.showsChevron) widget.controller.scrollToLatest();
      return; // 价格标签无论有没有箭头，都不能穿透触发信息面板。
    }
    _select(position);
  }

  void _onDrawingTap(Offset position) {
    if (!_canHit) return;
    final marker =
        latestPriceMarkerHitRegionFor(_frame!.snapshot, _pipeline.cache);
    if (marker != null && marker.contains(position)) {
      if (marker.showsChevron) widget.controller.scrollToLatest();
      return; // 与浏览模式一致：最新价标签不能穿透成画线落点。
    }
    final hit = _frame!.hitTest(position);
    if (hit == null || hit.panelId != 'main') return;
    // 命中帧和可见数据同源；锚点只保存 UTC 毫秒及价格，不保存像素。
    widget.onDrawingAnchor?.call(
      ChartDrawingAnchor(
        epochMilliseconds: hit.openTime,
        price: hit.price,
      ),
    );
  }

  void _onDrawingHoverAt(Offset position) {
    if (!_canHit) return;
    final marker =
        latestPriceMarkerHitRegionFor(_frame!.snapshot, _pipeline.cache);
    final hit = marker != null && marker.contains(position)
        ? null
        : _frame!.hitTest(position);
    final anchor = hit == null || hit.panelId != 'main'
        ? null
        : ChartDrawingAnchor(
            epochMilliseconds: hit.openTime,
            price: hit.price,
          );
    if (anchor == _lastDrawingHover) return;
    _lastDrawingHover = anchor;
    widget.onDrawingHover?.call(anchor);
  }

  void _clearDrawingHover() {
    if (_lastDrawingHover == null) return;
    _lastDrawingHover = null;
    widget.onDrawingHover?.call(null);
  }

  ChartDrawingHit? _drawingHitTest(Offset position) {
    if (!_canHit) return null;
    final frame = _frame!;
    final snapshot = frame.snapshot;
    final bounds = snapshot.layout.drawingBounds;
    if (!bounds.contains(x: position.dx, y: position.dy)) return null;
    final xTransform = ChartXTransform(
      viewport: frame.state.viewport,
      data: frame.state.data,
    );
    final panel = snapshot.layout.mainPanel;
    final priceTransform =
        ChartLayerGeometry.rangeFor(snapshot, 'main').transform(panel.bounds);
    for (final drawing in snapshot.anchoredDrawings.reversed) {
      final points = ChartDrawingAnchorProjector.project(
        drawing: drawing,
        xTransform: xTransform,
        priceTransform: priceTransform,
        localXOffset: bounds.left,
      );
      final hit = ChartDrawingHitTester.hitTest(
        drawing: drawing,
        controlPoints: points,
        localX: position.dx,
        localY: position.dy,
      );
      if (hit != null) return hit;
    }
    return null;
  }

  void _selectDrawing(Offset position) {
    if (!widget.drawingEditingEnabled || !_canHit) return;
    final marker =
        latestPriceMarkerHitRegionFor(_frame!.snapshot, _pipeline.cache);
    if (marker != null && marker.contains(position)) {
      if (marker.showsChevron) widget.controller.scrollToLatest();
      return;
    }
    widget.onDrawingSelectionChanged
        ?.call(_drawingHitTest(position)?.drawing.id);
  }

  void _startDrawingEdit(Offset position) {
    if (!widget.drawingEditingEnabled || !_canHit) return;
    final hit = _drawingHitTest(position);
    widget.onDrawingSelectionChanged?.call(hit?.drawing.id);
    if (hit == null || hit.drawing.isLocked) {
      return;
    }
    _draggingDrawingId = hit.drawing.id;
    _draggingWholeDrawing = hit.kind == ChartDrawingHitKind.body;
    _draggingAnchorIndex = _draggingWholeDrawing ? null : hit.anchorIndex;
    _dragStartPointerAnchor = _drawingAnchorAt(position);
    if (_dragStartPointerAnchor == null) {
      _draggingDrawingId = null;
      _draggingAnchorIndex = null;
      _draggingWholeDrawing = false;
      return;
    }
    _dragOriginalDrawings = List.unmodifiable(_runtime.value.overlays.drawings);
  }

  void _updateDrawingEdit(Offset position) {
    final id = _draggingDrawingId;
    final anchorIndex = _draggingAnchorIndex;
    if (id == null ||
        (!_draggingWholeDrawing && anchorIndex == null) ||
        !_canUseFrameGeometry) {
      return;
    }
    final pointerAnchor = _drawingAnchorAt(position);
    final startPointerAnchor = _dragStartPointerAnchor;
    if (pointerAnchor == null || startPointerAnchor == null) return;
    final overlays = _runtime.value.overlays;
    final originals = _dragOriginalDrawings ?? overlays.drawings;
    var editor = ChartDrawingEditor(
      drawings: originals,
      selectedDrawingId: id,
    );
    if (_draggingWholeDrawing) {
      editor = editor.moveDrawing(
        id: id,
        timeDeltaMilliseconds: pointerAnchor.epochMilliseconds -
            startPointerAnchor.epochMilliseconds,
        priceDelta: pointerAnchor.price - startPointerAnchor.price,
      );
      if (widget.drawingSnapToOhlc) {
        final count = editor.drawingById[id]!.anchors.length;
        for (var index = 0; index < count; index++) {
          editor = editor.snapAnchor(
            id: id,
            anchorIndex: index,
            data: _runtime.value.data.data,
          );
        }
      }
    } else {
      final selectedAnchorIndex = anchorIndex!;
      editor = editor.moveAnchor(
        id: id,
        anchorIndex: selectedAnchorIndex,
        anchor: pointerAnchor,
      );
      if (widget.drawingSnapToOhlc) {
        editor = editor.snapAnchor(
          id: id,
          anchorIndex: selectedAnchorIndex,
          data: _runtime.value.data.data,
        );
      }
    }
    _runtime.setOverlays(
      session: _runtime.value.session,
      priceLines: overlays.priceLines,
      events: overlays.events,
      valueMarkers: overlays.valueMarkers,
      drawings: editor.drawings,
    );
  }

  ChartDrawingAnchor? _drawingAnchorAt(Offset position) {
    final hit = _frame?.hitTest(position);
    if (hit == null || hit.panelId != 'main') return null;
    return ChartDrawingAnchor(
      epochMilliseconds: hit.openTime,
      price: hit.price,
    );
  }

  void _finishDrawingEdit() {
    final before = _dragOriginalDrawings;
    final after =
        List<ChartDrawing>.unmodifiable(_runtime.value.overlays.drawings);
    if (before != null && !listEquals(before, after)) {
      widget.onDrawingEditCommitted?.call(before, after);
    }
    _draggingDrawingId = null;
    _draggingAnchorIndex = null;
    _draggingWholeDrawing = false;
    _dragStartPointerAnchor = null;
    _dragOriginalDrawings = null;
  }

  void _cancelDrawingEdit() {
    final original = _dragOriginalDrawings;
    if (original != null) _restoreDrawings(original);
    _finishDrawingEdit();
  }

  void _restoreDrawings(Iterable<ChartDrawing> drawings) {
    final overlays = _runtime.value.overlays;
    _runtime.setOverlays(
      session: _runtime.value.session,
      priceLines: overlays.priceLines,
      events: overlays.events,
      valueMarkers: overlays.valueMarkers,
      drawings: drawings,
    );
  }

  void _select(Offset position) {
    if (!_canHit) return;
    final hit = _frame!.hitTest(position);
    if (hit == null) return;
    _runtime.select(
      openTime: hit.openTime,
      panelId: hit.panelId,
      price: hit.price,
    );
  }

  void _onIntent(ChartInteractionIntent intent) {
    if (!mounted || !widget.interactionEnabled || _runtime.isDisposed) return;
    switch (intent) {
      case ChartViewportIntent():
        final current = _runtime.value.viewport;
        if (intent.viewport.itemCount != current.itemCount ||
            intent.viewport.width != current.width) {
          return;
        }
        _handlingIntent = true;
        try {
          _runtime.applyViewport(intent.viewport, source: intent.source);
        } finally {
          _handlingIntent = false;
        }
      case ChartCrosshairIntent():
        if (intent.isActive) {
          _select(Offset(intent.localX, intent.localY));
        } else {
          _runtime.clearSelection();
        }
      case ChartHistoryPagingIntent():
        break; // 分页由唯一协调器调度，Widget 不维护第二个加载状态机。
    }
  }

  @override
  void dispose() {
    _unbind();
    super.dispose();
  }
}

bool _sameNonClockVersions(
  RenderSnapshotVersions first,
  RenderSnapshotVersions second,
) =>
    first.data == second.data &&
    first.viewport == second.viewport &&
    first.selection == second.selection &&
    first.history == second.history &&
    first.layout == second.layout &&
    first.theme == second.theme &&
    first.drawings == second.drawings &&
    first.overlays == second.overlays &&
    first.locale == second.locale;

/// 只比较投射、语义和命中真正读取的控制器状态；策略字段虽影响后续命令，
/// 但命令会另行发布视口/数据变化，不需要为策略值本身重建画面。
bool _sameProjectedRuntimeState(
  KChartRuntimeState old,
  KChartRuntimeState next,
) {
  return identical(old.session, next.session) &&
      identical(old.data, next.data) &&
      old.viewport == next.viewport &&
      old.selection == next.selection &&
      old.selectedIndex == next.selectedIndex &&
      old.history.phase == next.history.phase &&
      identical(old.indicatorBatch, next.indicatorBatch) &&
      listEquals(old.indicators, next.indicators) &&
      old.overlays == next.overlays &&
      kChartSameVisualOptions(old.options, next.options);
}

final class _KChartSurfacePainter extends CustomPainter {
  const _KChartSurfacePainter(this.snapshot, this.pipeline);

  final RenderSnapshot<ChartRenderStyle> snapshot;
  final StandardChartRenderPipeline<ChartRenderStyle> pipeline;

  @override
  void paint(Canvas canvas, Size size) =>
      pipeline.paint(RenderLayerContext(canvas: canvas, snapshot: snapshot));

  @override
  bool shouldRepaint(_KChartSurfacePainter oldDelegate) =>
      !identical(snapshot, oldDelegate.snapshot) ||
      !identical(pipeline, oldDelegate.pipeline);
}

/// 单独绘制临时画线，避免把未完成草稿写入行情覆盖物或渲染缓存。
final class _KChartDrawingPreviewPainter extends CustomPainter {
  const _KChartDrawingPreviewPainter({
    required this.frame,
    required this.drawing,
    required this.color,
  });

  final KChartFrame frame;
  final ChartDrawing drawing;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (drawing.anchors.isEmpty || frame.state.data.isEmpty) return;
    final layout = frame.snapshot.layout;
    final panel = layout.mainPanel;
    final range = ChartLayerGeometry.rangeFor(frame.snapshot, 'main');
    ChartDrawingRenderer.paintAnchored(
      canvas: canvas,
      drawing: drawing,
      xTransform: ChartXTransform(
        viewport: frame.state.viewport,
        data: frame.state.data,
      ),
      priceTransform: range.transform(panel.bounds),
      bounds: Rect.fromLTRB(
        layout.drawingBounds.left,
        layout.drawingBounds.top,
        layout.drawingBounds.right,
        layout.drawingBounds.bottom,
      ),
      color: color,
      formatPrice: frame.snapshot.theme.formatMainValue,
      textFontSize: frame.snapshot.theme.axisFontSize,
    );
  }

  @override
  bool shouldRepaint(_KChartDrawingPreviewPainter oldDelegate) =>
      !identical(frame.snapshot, oldDelegate.frame.snapshot) ||
      drawing != oldDelegate.drawing ||
      color != oldDelegate.color;
}

/// 在所选绘图的每个锚点上绘制控制柄，明确当前可拖动的位置。
final class _KChartDrawingSelectionPainter extends CustomPainter {
  const _KChartDrawingSelectionPainter({
    required this.frame,
    required this.drawingId,
    required this.color,
  });

  final KChartFrame frame;
  final String drawingId;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    ChartDrawing? drawing;
    for (final item in frame.snapshot.anchoredDrawings) {
      if (item.id == drawingId) {
        drawing = item;
        break;
      }
    }
    if (drawing == null) return;
    final panel = frame.snapshot.layout.mainPanel;
    final points = ChartDrawingAnchorProjector.project(
      drawing: drawing,
      xTransform: ChartXTransform(
        viewport: frame.state.viewport,
        data: frame.state.data,
      ),
      priceTransform: ChartLayerGeometry.rangeFor(
        frame.snapshot,
        panel.spec.id,
      ).transform(panel.bounds),
      localXOffset: frame.snapshot.layout.drawingBounds.left,
    );
    final border = Paint()
      ..color = const Color(0xffffffff)
      ..style = PaintingStyle.fill;
    final handle = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(
        frame.snapshot.layout.drawingBounds.left,
        frame.snapshot.layout.drawingBounds.top,
        frame.snapshot.layout.drawingBounds.right,
        frame.snapshot.layout.drawingBounds.bottom,
      ),
    );
    for (final point in points) {
      final center = Offset(point.localX, point.localY);
      canvas.drawCircle(center, 6, border);
      canvas.drawCircle(center, 4, handle);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_KChartDrawingSelectionPainter oldDelegate) =>
      !identical(frame.snapshot, oldDelegate.frame.snapshot) ||
      drawingId != oldDelegate.drawingId ||
      color != oldDelegate.color;
}
