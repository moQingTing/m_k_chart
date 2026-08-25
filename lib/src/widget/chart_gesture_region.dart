import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../interaction/interaction.dart';
import '../viewport/viewport.dart';

/// Internal Flutter Gesture Arena adapter for [ChartInteractionMachine].
///
/// One standard scale recognizer handles one-finger pan and two-finger scale,
/// while the standard long-press recognizer competes in the same arena. No
/// recognizer overrides rejection or force-accepts a lost gesture.
final class ChartGestureRegion extends StatefulWidget {
  const ChartGestureRegion({
    required this.machine,
    required this.navigationMachine,
    required this.viewport,
    required this.onIntent,
    required this.child,
    this.crosshairIntentBuilder,
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
  final HitTestBehavior behavior;

  @override
  State<ChartGestureRegion> createState() => _ChartGestureRegionState();
}

final class _ChartGestureRegionState extends State<ChartGestureRegion>
    with SingleTickerProviderStateMixin {
  late final Ticker _inertiaTicker = createTicker(_onInertiaTick);
  Duration _lastInertiaElapsed = Duration.zero;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: widget.behavior,
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        onLongPressStart: _onLongPressStart,
        onLongPressMoveUpdate: _onLongPressMoveUpdate,
        onLongPressEnd: _onLongPressEnd,
        onLongPressCancel: _onLongPressCancel,
        child: widget.child,
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
    _inertiaTicker.dispose();
    _emit(widget.machine.cancelActive());
    super.dispose();
  }
}
