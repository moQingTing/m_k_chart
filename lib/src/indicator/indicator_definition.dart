import '../model/model.dart';
import 'indicator_change.dart';
import 'indicator_config.dart';
import 'indicator_renderer_descriptor.dart';
import 'indicator_series.dart';

/// Calculation extension point for a registered indicator type.
abstract interface class IndicatorDefinition {
  String get id;

  IndicatorRendererDescriptor get rendererDescriptor;

  IndicatorResult calculate(
    VersionedKlineData input,
    IndicatorConfig config,
  );
}

/// Optional extension for definitions that can reuse a validated prior result.
abstract interface class IncrementalIndicatorDefinition
    implements IndicatorDefinition {
  bool supportsIncremental(IndicatorDataChange change);

  IndicatorResult calculateIncrementally(
    VersionedKlineData input,
    IndicatorConfig config,
    IndicatorResult previous,
    IndicatorDataChange change,
  );
}
