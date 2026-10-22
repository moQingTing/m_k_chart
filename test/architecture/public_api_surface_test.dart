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
    final declarations = _exportedDeclarations(
      libRoot,
      canonicalBarrel,
    );

    expect(declarations, allowlist.symbols);
  });
}

Set<String> _exportedDeclarations(Directory libRoot, File entry) {
  final declarations = <String>{};
  final visited = <String>{};

  void visit(File library, {Set<String>? only}) {
    final path = library.absolute.path;
    if (!visited.add(path)) return;
    final source = library.readAsStringSync();
    final own = _publicDeclarations(source);
    declarations.addAll(only == null ? own : own.intersection(only));

    final parts = RegExp(
      r'''^\s*part\s+['"]([^'"]+)['"];''',
      multiLine: true,
    );
    for (final match in parts.allMatches(source)) {
      final part =
          File(library.parent.uri.resolve(match.group(1)!).toFilePath());
      final partDeclarations = _publicDeclarations(part.readAsStringSync());
      declarations.addAll(
        only == null ? partDeclarations : partDeclarations.intersection(only),
      );
    }

    final exports = RegExp(
      r'''^\s*export\s+['"]([^'"]+)['"]([^;]*);''',
      multiLine: true,
    );
    for (final match in exports.allMatches(source)) {
      final target =
          File(library.parent.uri.resolve(match.group(1)!).toFilePath());
      final combinators = match.group(2)!;
      final shown = RegExp(r'\bshow\s+([^;]+)')
          .firstMatch(combinators)
          ?.group(1)
          ?.split(',')
          .map((name) => name.trim())
          .where((name) => name.isNotEmpty)
          .toSet();
      visit(target, only: shown);
    }
  }

  for (final export in _exportsFrom(entry.readAsStringSync())) {
    visit(File(libRoot.uri.resolve(export).toFilePath()));
  }
  return declarations;
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
    r'^(?:(?:abstract|base|final|interface|sealed)\s+)*'
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
