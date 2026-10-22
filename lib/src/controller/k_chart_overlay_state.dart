part of 'k_chart_data_coordinator.dart';

/// 覆盖物命令不推进行情版本，单独返回接收状态，避免借用数据更新回执。
enum KChartOverlayUpdateStatus { applied, unchanged, ignoredStaleSession }

/// 当前行情会话拥有的不可变覆盖物集合，所有坐标均为时间/价格，不含像素。
///
/// 四类对象共用 id 空间，防止后续命中事件只携带 id 时发生歧义。
/// 时间落在当前行情窗口外的对象仍保留，是否可见由后续投射层判断。
final class KChartOverlays {
  factory KChartOverlays({
    Iterable<ChartPriceLine> priceLines = const [],
    Iterable<ChartEventOverlay> events = const [],
    Iterable<ChartValueMarker> valueMarkers = const [],
    Iterable<ChartDrawing> drawings = const [],
  }) {
    final lines = List<ChartPriceLine>.unmodifiable(priceLines);
    final points = List<ChartEventOverlay>.unmodifiable(events);
    final markers = List<ChartValueMarker>.unmodifiable(valueMarkers);
    final shapes = List<ChartDrawing>.unmodifiable(drawings);
    final ids = <String>{};
    for (final id in [
      ...lines.map((item) => item.id),
      ...points.map((item) => item.id),
      ...markers.map((item) => item.id),
      ...shapes.map((item) => item.id),
    ]) {
      if (!ids.add(id)) throw ArgumentError('Duplicate overlay id: $id');
    }
    return KChartOverlays._(lines, points, markers, shapes);
  }

  const KChartOverlays._(
    this.priceLines,
    this.events,
    this.valueMarkers,
    this.drawings,
  );
  const KChartOverlays._empty()
      : priceLines = const [],
        events = const [],
        valueMarkers = const [],
        drawings = const [];

  final List<ChartPriceLine> priceLines;
  final List<ChartEventOverlay> events;
  final List<ChartValueMarker> valueMarkers;
  final List<ChartDrawing> drawings;

  bool get isEmpty =>
      priceLines.isEmpty &&
      events.isEmpty &&
      valueMarkers.isEmpty &&
      drawings.isEmpty;

  // 旧模型不具备结构相等；这里只比较语义字段，不改变旧渲染路径的对象身份约定。
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KChartOverlays &&
          _overlayListEquals(priceLines, other.priceLines, _lineKey) &&
          _overlayListEquals(events, other.events, _eventKey) &&
          _overlayListEquals(valueMarkers, other.valueMarkers, _markerKey) &&
          listEquals(drawings, other.drawings);

  @override
  int get hashCode => Object.hash(
        Object.hashAll(priceLines.map(_lineKey)),
        Object.hashAll(events.map(_eventKey)),
        Object.hashAll(valueMarkers.map(_markerKey)),
        Object.hashAll(drawings),
      );
}

Object _lineKey(ChartPriceLine item) =>
    (item.id, item.price, item.side, item.label, item.visible, item.style);
Object _eventKey(ChartEventOverlay item) =>
    (item.id, item.epochMilliseconds, item.price, item.side, item.label);
Object _markerKey(ChartValueMarker item) =>
    (item.id, item.price, item.text, item.side);

/// 直接遍历比较，避免为了判断无变化而分配两份中间列表。
bool _overlayListEquals<T>(
  List<T> first,
  List<T> second,
  Object Function(T) key,
) {
  if (identical(first, second)) return true;
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (key(first[index]) != key(second[index])) return false;
  }
  return true;
}
