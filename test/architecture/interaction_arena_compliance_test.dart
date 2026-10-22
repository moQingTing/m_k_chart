import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final packageRoot = Directory.current.absolute;

  test('new interaction path never overrides arena rejection or force accepts',
      () {
    final violations = <String>[];
    for (final module in ['interaction', 'widget']) {
      final root = Directory('${packageRoot.path}/lib/src/$module');
      for (final source in root
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))) {
        final contents = source.readAsStringSync();
        if (contents.contains('rejectGesture(') ||
            contents.contains('acceptGesture(')) {
          violations.add(_relative(source, packageRoot));
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'New recognizers must honor Gesture Arena decisions:\n'
          '${violations.join('\n')}',
    );
  });

  test('interaction core remains independent from Flutter and widget state',
      () {
    final interactionRoot =
        Directory('${packageRoot.path}/lib/src/interaction');
    const forbidden = <String, String>{
      'package:flutter/': 'Flutter framework',
      'dart:ui': 'dart:ui',
      'BuildContext': 'Widget context',
      'GestureRecognizer': 'Flutter recognizer',
      'KChartController': 'Controller mutation',
    };
    final violations = <String>[];

    for (final source in interactionRoot
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
