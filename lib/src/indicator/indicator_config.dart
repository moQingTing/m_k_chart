/// Immutable configuration for one indicator instance.
final class IndicatorConfig {
  factory IndicatorConfig({
    required String instanceId,
    required String definitionId,
    Map<String, num> parameters = const {},
    Map<String, String> seriesStyleKeys = const {},
  }) {
    _requireId(instanceId, 'instanceId');
    _requireId(definitionId, 'definitionId');
    _validateKeys(parameters.keys, 'parameter');
    _validateKeys(seriesStyleKeys.keys, 'series style');
    for (final entry in parameters.entries) {
      if (!entry.value.isFinite) {
        throw ArgumentError.value(
          entry.value,
          'parameters[${entry.key}]',
          'Must be finite.',
        );
      }
    }
    for (final entry in seriesStyleKeys.entries) {
      if (entry.value.trim().isEmpty) {
        throw ArgumentError.value(
          entry.value,
          'seriesStyleKeys[${entry.key}]',
          'Must not be empty.',
        );
      }
    }
    return IndicatorConfig._(
      instanceId: instanceId,
      definitionId: definitionId,
      parameters: Map.unmodifiable(parameters),
      seriesStyleKeys: Map.unmodifiable(seriesStyleKeys),
    );
  }

  const IndicatorConfig._({
    required this.instanceId,
    required this.definitionId,
    required this.parameters,
    required this.seriesStyleKeys,
  });

  final String instanceId;
  final String definitionId;

  /// Numeric calculation parameters, such as a period or multiplier.
  final Map<String, num> parameters;

  /// Semantic style references resolved by the theme/render layer.
  final Map<String, String> seriesStyleKeys;

  num? parameter(String key) => parameters[key];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IndicatorConfig &&
          instanceId == other.instanceId &&
          definitionId == other.definitionId &&
          _mapEquals(parameters, other.parameters) &&
          _mapEquals(seriesStyleKeys, other.seriesStyleKeys);

  @override
  int get hashCode => Object.hash(
        instanceId,
        definitionId,
        _mapHash(parameters),
        _mapHash(seriesStyleKeys),
      );
}

void _requireId(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'Must not be empty.');
  }
}

void _validateKeys(Iterable<String> keys, String label) {
  for (final key in keys) {
    if (key.trim().isEmpty) {
      throw ArgumentError('$label keys must not be empty.');
    }
  }
}

bool _mapEquals<K, V>(Map<K, V> first, Map<K, V> second) {
  if (first.length != second.length) {
    return false;
  }
  for (final entry in first.entries) {
    if (!second.containsKey(entry.key) || second[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}

int _mapHash<K, V>(Map<K, V> values) {
  var hash = 0;
  for (final entry in values.entries) {
    hash ^= Object.hash(entry.key, entry.value);
  }
  return hash;
}
