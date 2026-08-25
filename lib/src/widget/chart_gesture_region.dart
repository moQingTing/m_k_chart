import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../interaction/interaction.dart';
import '../viewport/viewport.dart';
import 'chart_axis_scale_gesture_recognizer.dart';

/// Desktop and trackpad behavior for one chart instance.
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

/// Internal Flutter Gesture Arena adapter for [ChartInteractionMachine].
///
/// One axis-gated scale recognizer handles one-finger horizontal pan and
/// two-finger scale, while the standard long-press recognizer competes in the
/// same arena. Vertical movement is left to a parent scrollable. No recognizer
/// force-accepts a lost gesture.
final class ChartGestureRegion extends StatefulWidget {
  const ChartGestureRegion({
    required this.machine,
    required this.navigationMachine,
    required this.viewport,
    required this.onIntent,
    required this.child,
    this.crosshairIntentBuilder,
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
  double _trackpadStartLocalX = 0;

  @override
  void initState() {
    super.initState();
    _inertiaTicker = createTicker(_onInertiaTick);
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
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
    _emit(
      widget.machine.updateScale(
        scale: event.scale,
        focalLocalX: _trackpadStartLocalX + event.localPan.dx,
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
    _inertiaTicker.dispose();
    _emit(widget.machine.cancelActive());
    super.dispose();
  }
}
