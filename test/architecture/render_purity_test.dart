import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final packageRoot = Directory.current.absolute;
  final renderRoot = Directory('${packageRoot.path}/lib/src/render');

  test('new render module cannot publish state or asynchronous events', () {
    final violations = <String>[];
    final forbidden = <RegExp, String>{
      RegExp(r'''import\s+['"]dart:async['"]'''): 'imports dart:async',
      RegExp(r'\bStreamController\s*<'): 'creates a StreamController',
      RegExp(r'\.sink\.add\s*\('): 'writes to a stream sink',
      RegExp(r'\bnotifyListeners\s*\('): 'notifies application state',
      RegExp(r'\bcommitStateChange\s*\('): 'commits controller state',
      RegExp(r'\.dispatch(?:Batch)?\s*\('): 'dispatches controller events',
      RegExp(r'\bsetState\s*\('): 'mutates widget state',
      RegExp(r'\bIndicatorComputationState\b'):
          'retains private indicator continuation state',
      RegExp(r'\.computationState\b'):
          'reads private indicator continuation state',
      RegExp(r'\.saveLayer\s*\('): 'uses an unapproved offscreen saveLayer',
    };

    final sources = renderRoot
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final source in sources) {
      final content = source.readAsStringSync();
      for (final rule in forbidden.entries) {
        if (rule.key.hasMatch(content)) {
          violations.add(
            '${_relative(source, packageRoot)} ${rule.value}',
          );
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}

String _relative(File file, Directory root) =>
    file.path.substring(root.path.length + 1);
