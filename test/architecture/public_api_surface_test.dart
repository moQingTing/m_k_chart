import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final packageRoot = Directory.current.absolute;
  final libRoot = Directory('${packageRoot.path}/lib');
  final canonicalBarrel = File('${libRoot.path}/m_k_chart.dart');
  final compatibilityBarrel = File('${libRoot.path}/flutter_k_chart.dart');
  final allowlist = _readAllowlist(
    File('${packageRoot.path}/tool/public_api_allowlist.txt'),
  );

  test('canonical barrel exports exactly the frozen file allowlist', () {
    final exports = _exportsFrom(canonicalBarrel.readAsStringSync()).toSet();

    expect(exports, allowlist.exports);
    expect(exports.any((path) => path.startsWith('src/')), isFalse);
    expect(exports.any((path) => path.startsWith('renderer/')), isFalse);
  });

  test('old package barrel is a deprecated canonical forwarding entry', () {
    final source = compatibilityBarrel.readAsStringSync();

    expect(_exportsFrom(source).toSet(), {'m_k_chart.dart'});
    expect(source, contains('@Deprecated('));
  });

  test('exported declarations match the frozen symbol allowlist', () {
    final declarations = <String>{};
    for (final export in allowlist.exports) {
      declarations.addAll(
        _publicDeclarations(File('${libRoot.path}/$export').readAsStringSync()),
      );
    }

    expect(declarations, allowlist.symbols);
  });
}

({Set<String> exports, Set<String> symbols}) _readAllowlist(File file) {
  final exports = <String>{};
  final symbols = <String>{};
  for (final line in file.readAsLinesSync()) {
    if (line.startsWith('export:')) {
      exports.add(line.substring('export:'.length));
    } else if (line.startsWith('symbol:')) {
      symbols.add(line.substring('symbol:'.length));
    }
  }
  return (exports: exports, symbols: symbols);
}

Iterable<String> _exportsFrom(String source) sync* {
  final expression = RegExp(
    r'''^\s*export\s+['"]([^'"]+)['"]''',
    multiLine: true,
  );
  for (final match in expression.allMatches(source)) {
    yield match.group(1)!;
  }
}

Set<String> _publicDeclarations(String source) {
  final declarations = <String>{};
  final types = RegExp(
    r'^(?:(?:abstract|base|final|sealed)\s+)?'
    r'(?:class|enum|mixin|typedef|extension)\s+([A-Za-z]\w*)',
    multiLine: true,
  );
  final functions = RegExp(
    r'^[A-Za-z]\w*(?:<[^\n>{}]+>)?\??\s+([A-Za-z]\w*)\s*\(',
    multiLine: true,
  );

  declarations.addAll(
    types.allMatches(source).map((match) => match.group(1)!),
  );
  declarations.addAll(
    functions.allMatches(source).map((match) => match.group(1)!),
  );
  return declarations;
}
