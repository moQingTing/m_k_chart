import '../model/model.dart';
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
