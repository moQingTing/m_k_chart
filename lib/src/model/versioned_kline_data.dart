import 'kline.dart';
import 'kline_data_version.dart';

/// 数据仓库、指标引擎和渲染器共用的只读 K 线输入边界。
///
/// 实现在视图生命周期内必须保持 [data] 稳定。这使消费者无需复制大量 K 线即可安全读取
/// 快照；数据变更必须发布新的版本化视图。
abstract interface class VersionedKlineData {
  List<Kline> get data;

  KlineDataVersion get version;
}
