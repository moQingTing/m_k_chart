import 'dart:math' as math;

import 'package:flutter/gestures.dart';

/// Scale recognizer that lets a parent vertical drag win for one-finger input.
///
/// A horizontal first movement continues through the standard scale callbacks
/// with pointerCount 1. Adding a second pointer keeps the same sequence and
/// enables the framework's focus-scale calculation.
final class ChartAxisScaleGestureRecognizer extends ScaleGestureRecognizer {
  ChartAxisScaleGestureRecognizer({
    super.debugOwner,
    super.supportedDevices,
  });

  final Set<int> _activePointers = <int>{};
  final Map<int, Offset> _startPositions = <int, Offset>{};
  bool _axisGatePassed = false;

  @override
  bool isPointerPanZoomAllowed(PointerPanZoomStartEvent event) => false;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _activePointers.add(event.pointer);
    _startPositions[event.pointer] = event.position;
    if (_activePointers.length >= 2) {
      _axisGatePassed = true;
    }
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent &&
        !_axisGatePassed &&
        _activePointers.length == 1) {
      final start = _startPositions[event.pointer];
      if (start != null) {
        final delta = event.position - start;
        final slop = computePanSlop(event.kind, gestureSettings);
        if (math.max(delta.dx.abs(), delta.dy.abs()) <= slop) {
          return;
        }
        if (delta.dy.abs() >= delta.dx.abs()) {
          resolve(GestureDisposition.rejected);
          return;
        }
        _axisGatePassed = true;
      }
    }

    super.handleEvent(event);
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _activePointers.remove(event.pointer);
      _startPositions.remove(event.pointer);
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    super.didStopTrackingLastPointer(pointer);
    _activePointers.clear();
    _startPositions.clear();
    _axisGatePassed = false;
  }

  @override
  String get debugDescription => 'chart axis scale';
}
