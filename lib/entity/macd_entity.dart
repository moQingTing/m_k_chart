import 'kdj_entity.dart';
import 'rsi_entity.dart';
import 'rw_entity.dart';
import 'volume_entity.dart';

mixin MACDEntity on KDJEntity, RSIEntity, WREntity, VolumeEntity {
  late double dea;
  late double dif;
  late double macd;
  late double ema12;
  late double ema26;
}
