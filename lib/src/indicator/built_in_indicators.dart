import 'additional_indicator_definitions.dart';
import 'indicator_registry.dart';
import 'legacy_indicator_definitions.dart';

/// 注册 V2 引擎内置的全部指标定义。
///
/// 宿主创建 [IndicatorEngine] 后应在启动阶段调用一次；自定义指标可在此之后继续注册。
void registerBuiltInIndicatorDefinitions(IndicatorRegistry registry) {
  registerLegacyIndicatorDefinitions(registry);
  registerAdditionalIndicatorDefinitions(registry);
}
