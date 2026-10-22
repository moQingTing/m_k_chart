import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final packageRoot = Directory.current.absolute;

  test('new runtime modules do not declare mutable static state', () {
    const runtimeModules = {'controller', 'interaction', 'render', 'viewport'};
    final violations = <String>[];
    final mutableStaticField = RegExp(
      r'^\s*static\s+(?!const\b)'
      r'(?:final\s+|late\s+|var\s+|[A-Za-z_]\w*(?:<[^;\n]+>)?\??\s+)'
      r'[A-Za-z_]\w*\s*(?:=|;)',
      multiLine: true,
    );

    for (final module in runtimeModules) {
      final root = Directory('${packageRoot.path}/lib/src/$module');
      final sources = root
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));
      for (final source in sources) {
        if (mutableStaticField.hasMatch(source.readAsStringSync())) {
          violations.add(_relative(source, packageRoot));
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Runtime state must belong to a chart instance:\n'
          '${violations.join('\n')}',
    );
  });
}

String _relative(File file, Directory root) =>
    file.path.substring(root.path.length + 1);
