import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _requiredModules = <String>{
  'adapter',
  'controller',
  'data',
  'drawing',
  'indicator',
  'interaction',
  'model',
  'render',
  'theme',
  'viewport',
  'widget',
};

const _allowedDependencies = <String, Set<String>>{
  'model': {},
  'theme': {},
  'data': {'model'},
  'indicator': {'model'},
  'drawing': {'model', 'theme'},
  'viewport': {'model', 'indicator', 'drawing'},
  'interaction': {'model', 'viewport'},
  'controller': {
    'model',
    'theme',
    'data',
    'indicator',
    'drawing',
    'viewport',
    'interaction',
  },
  'render': {'model', 'theme', 'indicator', 'drawing', 'viewport'},
  'widget': {
    'model',
    'theme',
    'data',
    'indicator',
    'drawing',
    'viewport',
    'interaction',
    'controller',
    'render',
  },
  'adapter': {
    'model',
    'theme',
    'data',
    'indicator',
    'drawing',
    'viewport',
    'interaction',
    'controller',
    'render',
  },
};

void main() {
  final packageRoot = Directory.current.absolute;
  final libRoot = Directory('${packageRoot.path}/lib');
  final srcRoot = Directory('${libRoot.path}/src');

  test('all internal module entrypoints exist', () {
    for (final module in _requiredModules) {
      expect(
        File('${srcRoot.path}/$module/$module.dart').existsSync(),
        isTrue,
        reason: 'Missing lib/src/$module/$module.dart',
      );
    }
    expect(_allowedDependencies.keys.toSet(), _requiredModules);
  });

  test('internal imports follow the approved dependency direction', () {
    final violations = <String>[];
    final sources = srcRoot
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final source in sources) {
      final sourceModule = _moduleFor(source, srcRoot);
      final imports = _importsFrom(source.readAsStringSync());
      for (final import in imports) {
        final target = _resolvePackageImport(import, source, libRoot);
        if (target == null || !target.path.startsWith(libRoot.path)) {
          continue;
        }
        if (!target.path.startsWith(srcRoot.path)) {
          if (sourceModule != 'adapter') {
            violations.add(
              '${_relative(source, packageRoot)} imports legacy $import',
            );
          }
          continue;
        }

        final targetModule = _moduleFor(target, srcRoot);
        if (targetModule == sourceModule) {
          continue;
        }
        final allowed = _allowedDependencies[sourceModule] ?? const {};
        if (!allowed.contains(targetModule)) {
          violations.add(
            '${_relative(source, packageRoot)}: '
            '$sourceModule -> $targetModule is not allowed',
          );
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}

Iterable<String> _importsFrom(String source) sync* {
  final expression = RegExp(
    r'''^\s*import\s+['"]([^'"]+)['"]''',
    multiLine: true,
  );
  for (final match in expression.allMatches(source)) {
    yield match.group(1)!;
  }
}

File? _resolvePackageImport(String import, File source, Directory libRoot) {
  if (import.startsWith('dart:') ||
      (import.startsWith('package:') &&
          !import.startsWith('package:m_k_chart/'))) {
    return null;
  }
  if (import.startsWith('package:m_k_chart/')) {
    return File(
      '${libRoot.path}/${import.substring('package:m_k_chart/'.length)}',
    ).absolute;
  }
  return File.fromUri(source.absolute.uri.resolve(import));
}

String _moduleFor(File file, Directory srcRoot) {
  final relative = file.path.substring(srcRoot.path.length + 1);
  return relative.split(Platform.pathSeparator).first;
}

String _relative(File file, Directory root) =>
    file.path.substring(root.path.length + 1);
