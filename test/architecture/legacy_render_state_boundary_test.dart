import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final packageRoot = Directory.current.absolute;

  test('legacy Painter has no static bounds or paint-time state publishing',
      () {
    final painter = File('${packageRoot.path}/lib/renderer/chart_painter.dart')
        .readAsStringSync();
    final basePainter =
        File('${packageRoot.path}/lib/renderer/base_chart_painter.dart')
            .readAsStringSync();

    expect(painter, isNot(contains('static double maxScrollX')));
    expect(basePainter, isNot(contains('static double maxScrollX')));
    expect(painter, isNot(contains('StreamSink')));
    expect(painter, isNot(contains('sink.add(')));
  });

  test('legacy Widget isolates chart refresh from its full widget build', () {
    final widget =
        File('${packageRoot.path}/lib/k_chart_widget.dart').readAsStringSync();

    expect(widget, isNot(contains('setState(')));
    expect(widget, isNot(contains('StreamController')));
    expect(widget, contains('ListenableBuilder'));
    expect(widget, contains('RepaintBoundary'));
  });
}
