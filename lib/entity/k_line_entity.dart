import '../entity/k_entity.dart';

class KLineEntity extends KEntity {
  double open = 0;
  double high = 0;
  double low = 0;
  double close = 0;
  double vol = 0;
  double amount = 0;
  int count = 0;

  /// 时间
  int id = 0;

  KLineEntity(
      // {
      //   required this.open,
      //   required this.high,
      //   required this.low,
      //   required this.close,
      //   required this.vol,
      //   required this.amount,
      //   required this.count,
      //   required this.id,
      // }
      );

  KLineEntity.fromJson(Map<String, dynamic> json) {
    open = json['open'] ?? 0;
    high = json['high'] ?? 0;
    low = json['low'] ?? 0;
    close = json['close'] ?? 0;
    vol = json['vol'] ?? 0;
    amount = json['amount'] ?? 0;
    count = json['count'] ?? 0;
    id = json['id'] ?? 0;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['open'] = open;
    data['close'] = close;
    data['high'] = high;
    data['low'] = low;
    data['vol'] = vol;
    data['amount'] = amount;
    data['count'] = count;
    return data;
  }

  @override
  String toString() {
    return 'MarketModel{open: $open, high: $high, low: $low, close: $close, vol: $vol, id: $id}';
  }
}
