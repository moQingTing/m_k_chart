import 'indicator_definition.dart';
import 'indicator_parameter_spec.dart';
import 'indicator_renderer_descriptor.dart';

/// 宿主可读取的指标目录快照；不暴露可变注册表或计算引擎。
final class IndicatorCatalogEntry {
  factory IndicatorCatalogEntry.fromDefinition(IndicatorDefinition definition) {
    final descriptor = definition.rendererDescriptor;
    final name = definition is NamedIndicatorDefinition
        ? definition.displayName.trim()
        : '';
    return IndicatorCatalogEntry._(
      definitionId: definition.id,
      displayName: name.isEmpty ? descriptor.series.first.label : name,
      placement: descriptor.placement,
      series: List.unmodifiable(
        descriptor.series.where((item) => item.showInChart),
      ),
      parameters: List.unmodifiable(
        definition is ParameterizedIndicatorDefinition
            ? definition.parameterSpecs
            : const <IndicatorParameterSpec>[],
      ),
    );
  }

  const IndicatorCatalogEntry._({
    required this.definitionId,
    required this.displayName,
    required this.placement,
    required this.series,
    required this.parameters,
  });

  final String definitionId;
  final String displayName;
  final IndicatorPlacement placement;
  final List<IndicatorSeriesDescriptor> series;
  final List<IndicatorParameterSpec> parameters;
}
