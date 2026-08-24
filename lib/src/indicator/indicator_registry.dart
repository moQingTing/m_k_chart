import '../model/model.dart';
import 'indicator_config.dart';
import 'indicator_definition.dart';
import 'indicator_series.dart';

/// Instance-owned registry; chart instances do not share mutable definitions.
final class IndicatorRegistry {
  final Map<String, IndicatorDefinition> _definitions = {};

  Map<String, IndicatorDefinition> get definitions =>
      Map.unmodifiable(_definitions);

  void register(IndicatorDefinition definition) {
    if (definition.id.trim().isEmpty) {
      throw ArgumentError.value(definition.id, 'definition.id');
    }
    if (_definitions.containsKey(definition.id)) {
      throw StateError('Indicator ${definition.id} is already registered.');
    }
    _definitions[definition.id] = definition;
  }

  IndicatorDefinition? find(String definitionId) => _definitions[definitionId];

  IndicatorResult calculate(
    VersionedKlineData input,
    IndicatorConfig config,
  ) {
    final definition = _definitions[config.definitionId];
    if (definition == null) {
      throw StateError('Indicator ${config.definitionId} is not registered.');
    }
    final result = definition.calculate(input, config);
    _validateResult(definition, input, config, result);
    return result;
  }
}

void _validateResult(
  IndicatorDefinition definition,
  VersionedKlineData input,
  IndicatorConfig config,
  IndicatorResult result,
) {
  if (result.instanceId != config.instanceId ||
      result.definitionId != config.definitionId) {
    throw StateError('Indicator result identity does not match its config.');
  }
  if (result.dataVersion != input.version ||
      result.length != input.data.length) {
    throw StateError('Indicator result does not match its input snapshot.');
  }
  final expected = definition.rendererDescriptor.series
      .map((descriptor) => descriptor.id)
      .toSet();
  final actual = result.series.map((series) => series.id).toSet();
  if (expected.length != actual.length || !expected.containsAll(actual)) {
    throw StateError(
      'Indicator result series do not match its renderer contract.',
    );
  }
}
