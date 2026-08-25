import 'additional_indicator_definitions.dart';
import 'indicator_registry.dart';
import 'legacy_indicator_definitions.dart';

/// Registers every indicator definition shipped by the v2 engine.
void registerBuiltInIndicatorDefinitions(IndicatorRegistry registry) {
  registerLegacyIndicatorDefinitions(registry);
  registerAdditionalIndicatorDefinitions(registry);
}
