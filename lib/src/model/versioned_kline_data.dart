import 'kline.dart';
import 'kline_data_version.dart';

/// Read-only input boundary shared by stores and calculation engines.
///
/// Implementations must keep [data] stable for the lifetime of the view. This
/// lets consumers read a snapshot without copying a large Kline collection.
abstract interface class VersionedKlineData {
  List<Kline> get data;

  KlineDataVersion get version;
}
