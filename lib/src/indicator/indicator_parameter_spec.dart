import 'indicator_config.dart';
import 'indicator_definition.dart';

/// 指标计算参数的只读描述；设置界面与计算定义共用同一默认值和数值约束。
enum IndicatorParameterKind { positiveInteger, positiveNumber }

final class IndicatorParameterSpec {
  const IndicatorParameterSpec.integer(
    this.key,
    this.label,
    int defaultValue, {
    this.visibleInSettings = true,
    this.notGreaterThanKey,
  })  : kind = IndicatorParameterKind.positiveInteger,
        defaultValue = defaultValue,
        assert(defaultValue > 0);

  const IndicatorParameterSpec.number(
    this.key,
    this.label,
    num defaultValue, {
    this.visibleInSettings = true,
    this.notGreaterThanKey,
  })  : kind = IndicatorParameterKind.positiveNumber,
        defaultValue = defaultValue,
        assert(defaultValue > 0);

  final String key;
  final String label;
  final IndicatorParameterKind kind;
  final num defaultValue;

  /// 兼容算法可能保留旧序列，但候选图表不呈现；这类参数不占设置表单。
  final bool visibleInSettings;

  /// 可选的同组上限参数键，例如 SAR 初始加速和步长不能超过加速上限。
  final String? notGreaterThanKey;

  /// 与计算器的参数规则一致；未指定时读取默认值。
  num read(IndicatorConfig config) => validate(
        config.parameter(key) ?? defaultValue,
      );

  num validate(num value) {
    if (!value.isFinite ||
        value <= 0 ||
        (kind == IndicatorParameterKind.positiveInteger &&
            value.toInt() != value)) {
      throw ArgumentError.value(value, key, validationMessage);
    }
    return value;
  }

  int readInt(IndicatorConfig config) => read(config).toInt();
  double readDouble(IndicatorConfig config) => read(config).toDouble();

  String get validationMessage => kind == IndicatorParameterKind.positiveInteger
      ? '请输入大于 0 的整数'
      : '请输入大于 0 的数字';

  /// 文本框提交前使用同一约束，错误不会进入 IndicatorConfig/计算缓存。
  num parse(String text) {
    final value = num.tryParse(text.trim());
    if (value == null) throw FormatException(validationMessage);
    final valid = validate(value);
    return kind == IndicatorParameterKind.positiveInteger
        ? valid.toInt()
        : valid;
  }

  /// 校验参数组内的关联约束；未显式提供的值仍使用定义声明的默认值。
  static void validateSet(
    Iterable<IndicatorParameterSpec> specs,
    IndicatorConfig config,
  ) {
    final byKey = {for (final spec in specs) spec.key: spec};
    final values = {for (final spec in specs) spec.key: spec.read(config)};
    for (final spec in specs) {
      final upperKey = spec.notGreaterThanKey;
      if (upperKey == null) continue;
      final upper = byKey[upperKey];
      if (upper == null) {
        throw StateError('Unknown parameter bound: $upperKey');
      }
      if (values[spec.key]! > values[upperKey]!) {
        throw ArgumentError.value(
          values[spec.key],
          spec.key,
          '${spec.label}不能超过${upper.label}',
        );
      }
    }
  }
}

/// 可选扩展接口；没有参数的指标无需实现。
abstract interface class ParameterizedIndicatorDefinition
    implements IndicatorDefinition {
  List<IndicatorParameterSpec> get parameterSpecs;
}
