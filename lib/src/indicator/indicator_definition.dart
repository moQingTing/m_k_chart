import '../model/model.dart';
import 'indicator_change.dart';
import 'indicator_config.dart';
import 'indicator_renderer_descriptor.dart';
import 'indicator_series.dart';

/// 已注册指标类型的计算扩展点。
///
/// 新指标需要实现此接口、提供稳定的 [id] 和 [rendererDescriptor]，再注册到
/// [IndicatorRegistry]。计算结果的长度和序列 id 必须与输入和描述符一致。
abstract interface class IndicatorDefinition {
  String get id;

  IndicatorRendererDescriptor get rendererDescriptor;

  IndicatorResult calculate(
    VersionedKlineData input,
    IndicatorConfig config,
  );
}

/// 可选的人类可读名称；未实现时目录使用第一条输出序列的标签。
abstract interface class NamedIndicatorDefinition
    implements IndicatorDefinition {
  String get displayName;
}

/// 可复用已校验旧结果的指标定义可选实现。
///
/// 仅当 [supportsIncremental] 返回 true 时，缓存才会调用增量接口；实现者必须保证增量
/// 结果与同一输入的全量计算一致。
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
