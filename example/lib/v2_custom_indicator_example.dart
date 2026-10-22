import 'package:m_k_chart/m_k_chart.dart';

/// 典型价格示例：每根 (最高价 + 最低价 + 收盘价) / 3，再乘可编辑倍数。
///
/// 接入方只需实现定义、声明显示名称和参数，然后在创建 Controller 时传入
/// `indicatorDefinitions`；不需要修改核心枚举、Painter 或图例 Widget。
final class V2TypicalPriceIndicator
    implements NamedIndicatorDefinition, ParameterizedIndicatorDefinition {
  const V2TypicalPriceIndicator();

  static const definitionId = 'example.typicalPrice';
  static const _parameters = [
    IndicatorParameterSpec.number('scale', '倍数', 1),
  ];

  @override
  String get id => definitionId;

  @override
  String get displayName => '典型价';

  @override
  List<IndicatorParameterSpec> get parameterSpecs => _parameters;

  @override
  IndicatorRendererDescriptor get rendererDescriptor =>
      IndicatorRendererDescriptor(
        placement: IndicatorPlacement.separatePanel,
        legend: IndicatorLegendDescriptor(
          labelTemplates: const {'value': '典型价×{scale}'},
        ),
        series: [
          IndicatorSeriesDescriptor(
            id: 'value',
            label: '典型价',
            drawingKind: IndicatorDrawingKind.line,
          ),
        ],
      );

  @override
  IndicatorResult calculate(
    VersionedKlineData input,
    IndicatorConfig config,
  ) {
    final scale = _parameters.single.readDouble(config);
    return IndicatorResult(
      instanceId: config.instanceId,
      definitionId: id,
      dataVersion: input.version,
      length: input.data.length,
      series: [
        IndicatorSeries(
          id: 'value',
          values: input.data.map(
            (candle) => (candle.high + candle.low + candle.close) / 3 * scale,
          ),
        ),
      ],
    );
  }
}
