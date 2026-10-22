import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../interaction/interaction.dart';
import '../render/chart_trade_overlay_interaction.dart';
import '../viewport/viewport.dart';
import 'chart_axis_scale_gesture_recognizer.dart';

/// 单图表实例的桌面端与触控板输入行为配置。
final class ChartPointerInputPolicy {
  const ChartPointerInputPolicy({
    this.mouseHoverCrosshair = true,
    this.mouseWheelZoom = true,
    this.trackpadPanZoom = true,
    this.mouseWheelZoomSensitivity = 0.002,
  })  : assert(mouseWheelZoomSensitivity > 0),
        assert(mouseWheelZoomSensitivity < double.infinity);

  final bool mouseHoverCrosshair;
  final bool mouseWheelZoom;
  final bool trackpadPanZoom;
  final double mouseWheelZoomSensitivity;
}

typedef ChartTradeOverlayDragCallback = void Function(
  ChartTradeOverlayHit hit,
  Offset localPosition,
);

/// 为纯 Canvas 图表暴露的宿主本地化语义信息。
final class ChartSemanticsConfiguration {
  factory ChartSemanticsConfiguration({
    required String label,
    required String value,
    required String hint,
    TextDirection textDirection = TextDirection.ltr,
    bool liveRegion = false,
    VoidCallback? onTap,
    VoidCallback? onIncrease,
    VoidCallback? onDecrease,
    String? increasedValue,
    String? decreasedValue,
  }) {
    for (final entry in {
      'label': label,
      'value': value,
      'hint': hint,
    }.entries) {
      if (entry.value.trim().isEmpty) {
        throw ArgumentError.value(entry.value, entry.key, 'Must not be empty.');
      }
    }
    if (onIncrease != null && (increasedValue?.trim().isEmpty ?? true)) {
      throw ArgumentError.value(
        increasedValue,
        'increasedValue',
        'Must not be empty when onIncrease is supplied.',
      );
    }
    if (onDecrease != null && (decreasedValue?.trim().isEmpty ?? true)) {
      throw ArgumentError.value(
        decreasedValue,
        'decreasedValue',
        'Must not be empty when onDecrease is supplied.',
      );
    }
    return ChartSemanticsConfiguration._(
      label: label,
      value: value,
      hint: hint,
      textDirection: textDirection,
      liveRegion: liveRegion,
      onTap: onTap,
      onIncrease: onIncrease,
      onDecrease: onDecrease,
      increasedValue: increasedValue,
      decreasedValue: decreasedValue,
    );
  }

  const ChartSemanticsConfiguration._({
    required this.label,
    required this.value,
    required this.hint,
    required this.textDirection,
    required this.liveRegion,
    required this.onTap,
    required this.onIncrease,
    required this.onDecrease,
    required this.increasedValue,
    required this.decreasedValue,
  });

  final String label;
  final String value;
  final String hint;
  final TextDirection textDirection;
  final bool liveRegion;
  final VoidCallback? onTap;
  final VoidCallback? onIncrease;
  final VoidCallback? onDecrease;
  final String? increasedValue;
  final String? decreasedValue;
}

/// 可选的覆盖物回调，可参与图表手势竞技场。
final class ChartTradeOverlayGestureCallbacks {
  const ChartTradeOverlayGestureCallbacks({
    required this.hitTest,
    required this.onTap,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    this.onDragCancel,
  });

  final ChartTradeOverlayHit? Function(Offset localPosition) hitTest;
  final ValueChanged<ChartTradeOverlayHit> onTap;
  final ChartTradeOverlayDragCallback onDragStart;
  final ChartTradeOverlayDragCallback onDragUpdate;
  final ValueChanged<ChartTradeOverlayHit> onDragEnd;
  final ValueChanged<ChartTradeOverlayHit>? onDragCancel;
}

/// [ChartInteractionMachine] 的内部 Flutter Gesture Arena 适配器。
///
/// 单个带轴向门控的缩放识别器处理单指横向拖动和双指缩放，标准长按识别器在同一竞技场竞争；
/// 垂直移动交由父级可滚动组件处理。任何识别器均不会强制接受已输掉的手势。
final class ChartGestureRegion extends StatefulWidget {
  const ChartGestureRegion({
    required this.machine,
    required this.navigationMachine,
    required this.viewport,
    required this.onIntent,
    required this.child,
    this.crosshairIntentBuilder,
    this.onTapUp,
    this.tradeOverlayGestures,
    this.semantics,
    this.excludeChildSemantics = false,
    this.pointerInputPolicy = const ChartPointerInputPolicy(),
    this.behavior = HitTestBehavior.opaque,
    super.key,
  });

  final ChartInteractionMachine machine;
  final ChartNavigationMachine navigationMachine;
  final ChartViewport Function() viewport;
  final ValueChanged<ChartInteractionIntent> onIntent;
  final Widget child;
  final ChartCrosshairIntent Function(double localX, double localY)?
      crosshairIntentBuilder;
  final ValueChanged<Offset>? onTapUp;
  final ChartTradeOverlayGestureCallbacks? tradeOverlayGestures;
  final ChartSemanticsConfiguration? semantics;

  /// 纯画布可只保留显式图表语义；默认保留子节点，兼容宿主自定义控件。
  final bool excludeChildSemantics;
  final ChartPointerInputPolicy pointerInputPolicy;
  final HitTestBehavior behavior;

  @override
  State<ChartGestureRegion> createState() => _ChartGestureRegionState();
}

final class _ChartGestureRegionState extends State<ChartGestureRegion>
    with SingleTickerProviderStateMixin {
  late final Ticker _inertiaTicker;
  Duration _lastInertiaElapsed = Duration.zero;
  bool _mouseCrosshairVisible = false;
  bool _trackpadActive = false;
  bool _trackpadHasScaled = false;
  double _trackpadStartLocalX = 0;
  ChartTradeOverlayHit? _activeTradeOverlayHit;

  @override
  void initState() {
    super.initState();
    _inertiaTicker = createTicker(_onInertiaTick);
  }

  @override
  Widget build(BuildContext context) {
    final gestureRegion = MouseRegion(
      onExit: _onPointerExit,
      child: Listener(
        behavior: widget.behavior,
        onPointerDown: _onPointerDown,
        onPointerHover: _onPointerHover,
        onPointerSignal: _onPointerSignal,
        onPointerPanZoomStart: _onPointerPanZoomStart,
        onPointerPanZoomUpdate: _onPointerPanZoomUpdate,
        onPointerPanZoomEnd: _onPointerPanZoomEnd,
        child: RawGestureDetector(
          behavior: widget.behavior,
          gestures: <Type, GestureRecognizerFactory>{
            TapGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
              () => TapGestureRecognizer(debugOwner: this),
              (recognizer) => recognizer.onTapUp = _onTapUp,
            ),
            if (widget.tradeOverlayGestures != null)
              _ChartTradeOverlayVerticalDragGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                      _ChartTradeOverlayVerticalDragGestureRecognizer>(
                () => _ChartTradeOverlayVerticalDragGestureRecognizer(
                  debugOwner: this,
                ),
                (recognizer) {
                  recognizer
                    ..overlayHitTest = widget.tradeOverlayGestures?.hitTest
                    ..dragStartBehavior = DragStartBehavior.down
                    ..onStart = _onTradeOverlayDragStart
                    ..onUpdate = _onTradeOverlayDragUpdate
                    ..onEnd = _onTradeOverlayDragEnd
                    ..onCancel = _onTradeOverlayDragCancel;
                },
              ),
            ChartAxisScaleGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<
                    ChartAxisScaleGestureRecognizer>(
              () => ChartAxisScaleGestureRecognizer(
                debugOwner: this,
                supportedDevices: const <PointerDeviceKind>{
                  PointerDeviceKind.touch,
                  PointerDeviceKind.stylus,
                  PointerDeviceKind.invertedStylus,
                  PointerDeviceKind.mouse,
                },
              ),
              (recognizer) {
                recognizer
                  ..onStart = _onScaleStart
                  ..onUpdate = _onScaleUpdate
                  ..onEnd = _onScaleEnd;
              },
            ),
            LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<
                LongPressGestureRecognizer>(
              () => LongPressGestureRecognizer(
                debugOwner: this,
                supportedDevices: const <PointerDeviceKind>{
                  PointerDeviceKind.touch,
                  PointerDeviceKind.stylus,
                  PointerDeviceKind.invertedStylus,
                },
              ),
              (recognizer) {
                recognizer
                  ..onLongPressStart = _onLongPressStart
                  ..onLongPressMoveUpdate = _onLongPressMoveUpdate
                  ..onLongPressEnd = _onLongPressEnd
                  ..onLongPressCancel = _onLongPressCancel;
              },
            ),
          },
          child: widget.child,
        ),
      ),
    );
    final semantics = widget.semantics;
    if (semantics == null) return gestureRegion;
    return Semantics(
      container: true,
      label: semantics.label,
      value: semantics.value,
      hint: semantics.hint,
      textDirection: semantics.textDirection,
      liveRegion: semantics.liveRegion,
      button: semantics.onTap != null,
      onTap: semantics.onTap,
      onIncrease: semantics.onIncrease,
      onDecrease: semantics.onDecrease,
      increasedValue: semantics.increasedValue,
      decreasedValue: semantics.decreasedValue,
      // 纯画布的手势识别器也会生成 tap 语义；按调用方选择是否只保留显式动作。
      child: widget.excludeChildSemantics
          ? ExcludeSemantics(child: gestureRegion)
          : gestureRegion,
    );
  }

  void _onTapUp(TapUpDetails details) {
    final overlayCallbacks = widget.tradeOverlayGestures;
    final hit = overlayCallbacks?.hitTest(details.localPosition);
    if (hit != null) {
      overlayCallbacks!.onTap(hit);
      return;
    }
    widget.onTapUp?.call(details.localPosition);
  }

  void _onTradeOverlayDragStart(DragStartDetails details) {
    final callbacks = widget.tradeOverlayGestures;
    final hit = callbacks?.hitTest(details.localPosition);
    if (callbacks == null || hit == null) return;
    _cancelInertia();
    _activeTradeOverlayHit = hit;
    callbacks.onDragStart(hit, details.localPosition);
  }

  void _onTradeOverlayDragUpdate(DragUpdateDetails details) {
    final hit = _activeTradeOverlayHit;
    if (hit == null) return;
    widget.tradeOverlayGestures?.onDragUpdate(hit, details.localPosition);
  }

  void _onTradeOverlayDragEnd(DragEndDetails details) {
    final hit = _activeTradeOverlayHit;
    _activeTradeOverlayHit = null;
    if (hit != null) widget.tradeOverlayGestures?.onDragEnd(hit);
  }

  void _onTradeOverlayDragCancel() {
    final hit = _activeTradeOverlayHit;
    _activeTradeOverlayHit = null;
    if (hit != null) widget.tradeOverlayGestures?.onDragCancel?.call(hit);
  }

  void _onScaleStart(ScaleStartDetails details) {
    _cancelInertia();
    if (details.pointerCount >= 2) {
      widget.machine.beginScale(
        viewport: widget.viewport(),
        focalLocalX: details.localFocalPoint.dx,
      );
      return;
    }
    widget.machine.beginPan(widget.viewport());
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount >= 2) {
      if (widget.machine.mode == ChartInteractionMode.panning) {
        widget.machine.cancelPan();
        widget.machine.beginScale(
          viewport: widget.viewport(),
          focalLocalX: details.localFocalPoint.dx,
        );
      }
      final intent = widget.machine.updateScale(
        scale: details.horizontalScale,
        focalLocalX: details.localFocalPoint.dx,
      );
      _emit(intent);
      return;
    }

    if (widget.machine.mode == ChartInteractionMode.panning) {
      _emit(widget.machine.updatePan(details.focalPointDelta.dx));
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    switch (widget.machine.mode) {
      case ChartInteractionMode.panning:
        widget.machine.endPan();
        if (widget.navigationMachine.startInertia(
          viewport: widget.viewport(),
          velocityLocalXPerSecond: details.velocity.pixelsPerSecond.dx,
        )) {
          _lastInertiaElapsed = Duration.zero;
          _inertiaTicker.start();
        }
      case ChartInteractionMode.scaling:
        widget.machine.endScale();
      case ChartInteractionMode.idle:
      case ChartInteractionMode.crosshair:
        break;
    }
  }

  void _onLongPressStart(LongPressStartDetails details) {
    _cancelInertia();
    _emitCrosshair(
      widget.machine.beginCrosshair(
        localX: details.localPosition.dx,
        localY: details.localPosition.dy,
      ),
    );
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    _emitCrosshair(
      widget.machine.updateCrosshair(
        localX: details.localPosition.dx,
        localY: details.localPosition.dy,
      ),
    );
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    _emit(widget.machine.endCrosshair());
  }

  void _onLongPressCancel() {
    _emit(widget.machine.cancelCrosshair());
  }

  void _emit(ChartInteractionIntent? intent) {
    if (intent != null) {
      widget.onIntent(intent);
    }
  }

  void _emitCrosshair(ChartCrosshairIntent? intent) {
    if (intent == null || !intent.isActive) {
      _emit(intent);
      return;
    }
    _emit(
      widget.crosshairIntentBuilder?.call(intent.localX, intent.localY) ??
          intent,
    );
  }

  ChartCrosshairIntent _buildCrosshair(double localX, double localY) =>
      widget.crosshairIntentBuilder?.call(localX, localY) ??
      ChartCrosshairIntent.show(localX: localX, localY: localY);

  void _onPointerDown(PointerDownEvent event) {
    if (_mouseCrosshairVisible) {
      _hideMouseCrosshair();
    }
  }

  void _onPointerHover(PointerHoverEvent event) {
    if (!widget.pointerInputPolicy.mouseHoverCrosshair ||
        event.kind != PointerDeviceKind.mouse ||
        event.buttons != 0) {
      return;
    }
    _mouseCrosshairVisible = true;
    _emit(_buildCrosshair(event.localPosition.dx, event.localPosition.dy));
  }

  void _onPointerExit(PointerExitEvent event) {
    _hideMouseCrosshair();
  }

  void _hideMouseCrosshair() {
    if (!_mouseCrosshairVisible) {
      return;
    }
    _mouseCrosshairVisible = false;
    _emit(const ChartCrosshairIntent.hide());
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !widget.machine.isIdle) {
      return;
    }
    final horizontal = event.scrollDelta.dx.abs() > event.scrollDelta.dy.abs();
    if (!horizontal && !widget.pointerInputPolicy.mouseWheelZoom) {
      return;
    }
    GestureBinding.instance.pointerSignalResolver.register(
      event,
      (resolvedEvent) =>
          _handlePointerScroll(resolvedEvent as PointerScrollEvent),
    );
  }

  void _handlePointerScroll(PointerScrollEvent event) {
    if (!widget.machine.isIdle) {
      return;
    }
    _cancelInertia();
    final horizontal = event.scrollDelta.dx.abs() > event.scrollDelta.dy.abs();
    if (horizontal) {
      widget.machine.beginPan(widget.viewport());
      _emit(widget.machine.updatePan(-event.scrollDelta.dx));
      widget.machine.endPan();
    } else {
      widget.machine.beginScale(
        viewport: widget.viewport(),
        focalLocalX: event.localPosition.dx,
      );
      final exponent = (-event.scrollDelta.dy *
              widget.pointerInputPolicy.mouseWheelZoomSensitivity)
          .clamp(-4.0, 4.0);
      final scale = math.exp(exponent);
      _emit(
        widget.machine.updateScale(
          scale: scale,
          focalLocalX: event.localPosition.dx,
        ),
      );
      widget.machine.endScale();
    }
    if (_mouseCrosshairVisible) {
      _emit(_buildCrosshair(event.localPosition.dx, event.localPosition.dy));
    }
  }

  void _onPointerPanZoomStart(PointerPanZoomStartEvent event) {
    if (!widget.pointerInputPolicy.trackpadPanZoom || !widget.machine.isIdle) {
      return;
    }
    _cancelInertia();
    _trackpadStartLocalX = event.localPosition.dx;
    _trackpadHasScaled = false;
    _trackpadActive = widget.machine.beginScale(
      viewport: widget.viewport(),
      focalLocalX: _trackpadStartLocalX,
    );
  }

  void _onPointerPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    if (!_trackpadActive ||
        !event.scale.isFinite ||
        event.scale <= 0 ||
        !event.localPan.dx.isFinite) {
      return;
    }
    // 触控板复用焦点缩放算法实现平移，但纯平移必须仍带上浏览语义。
    // 一旦本次手势发生缩放，即使比例回到 1，也不应误判为新的横向浏览。
    _trackpadHasScaled = _trackpadHasScaled || event.scale != 1;
    _emit(
      widget.machine.updateScale(
        scale: event.scale,
        focalLocalX: _trackpadStartLocalX + event.localPan.dx,
        source: _trackpadHasScaled
            ? ChartViewportChangeSource.scale
            : ChartViewportChangeSource.pan,
      ),
    );
  }

  void _onPointerPanZoomEnd(PointerPanZoomEndEvent event) {
    if (!_trackpadActive) {
      return;
    }
    _trackpadActive = false;
    widget.machine.endScale();
  }

  void _onInertiaTick(Duration elapsed) {
    final delta = elapsed - _lastInertiaElapsed;
    _lastInertiaElapsed = elapsed;
    _emit(widget.navigationMachine.advanceInertia(delta));
    if (!widget.navigationMachine.isInertiaActive) {
      _inertiaTicker.stop();
    }
  }

  void _cancelInertia() {
    widget.navigationMachine.cancelInertia();
    if (_inertiaTicker.isActive) {
      _inertiaTicker.stop();
    }
  }

  @override
  void dispose() {
    _cancelInertia();
    _hideMouseCrosshair();
    if (_trackpadActive) {
      _trackpadActive = false;
      widget.machine.cancelScale();
    }
    _onTradeOverlayDragCancel();
    _inertiaTicker.dispose();
    _emit(widget.machine.cancelActive());
    super.dispose();
  }
}

final class _ChartTradeOverlayVerticalDragGestureRecognizer
    extends VerticalDragGestureRecognizer {
  _ChartTradeOverlayVerticalDragGestureRecognizer({super.debugOwner});

  ChartTradeOverlayHit? Function(Offset localPosition)? overlayHitTest;

  @override
  bool isPointerAllowed(PointerEvent event) =>
      overlayHitTest?.call(event.localPosition) != null &&
      super.isPointerAllowed(event);
}
