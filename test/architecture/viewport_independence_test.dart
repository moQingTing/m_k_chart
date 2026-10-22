import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final packageRoot = Directory.current.absolute;
  final viewportRoot = Directory('${packageRoot.path}/lib/src/viewport');

  test('viewport math has no Flutter, global-coordinate, or legacy dependency',
      () {
    const forbidden = <String, String>{
      'package:flutter/': 'Flutter framework',
      'dart:ui': 'dart:ui coordinate types',
      'RenderBox': 'render tree state',
      'globalToLocal': 'global coordinate conversion',
      'ChartPainter': 'legacy painter',
      'KChartWidget': 'legacy widget',
      '../../renderer/': 'legacy renderer module',
      '../../k_chart_widget.dart': 'legacy widget module',
    };
    final violations = <String>[];

    for (final source in viewportRoot
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))) {
      final contents = source.readAsStringSync();
      for (final entry in forbidden.entries) {
        if (contents.contains(entry.key)) {
          violations.add(
            '${_relative(source, packageRoot)} references ${entry.value}',
          );
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}

String _relative(File file, Directory root) =>
    file.path.substring(root.path.length + 1);
