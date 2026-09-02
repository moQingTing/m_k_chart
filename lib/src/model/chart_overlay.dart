/// Semantic direction for trading overlays, independent of any exchange SDK.
enum ChartOverlaySide { buy, sell, neutral }

/// A horizontal price reference line with optional label and action identity.
final class ChartPriceLine {
  factory ChartPriceLine({
    required String id,
    required double price,
    ChartOverlaySide side = ChartOverlaySide.neutral,
    String? label,
    bool visible = true,
  }) {
    if (id.trim().isEmpty || !price.isFinite) {
      throw ArgumentError('Invalid price line.');
    }
    return ChartPriceLine._(id, price, side, label, visible);
  }
  const ChartPriceLine._(
    this.id,
    this.price,
    this.side,
    this.label,
    this.visible,
  );
  final String id;
  final double price;
  final ChartOverlaySide side;
  final String? label;
  final bool visible;

  ChartPriceLine copyWith({double? price, bool? visible}) => ChartPriceLine(
        id: id,
        price: price ?? this.price,
        side: side,
        label: label,
        visible: visible ?? this.visible,
      );
}

/// A time/price annotation point for executions, alerts, or user events.
final class ChartEventOverlay {
  factory ChartEventOverlay({
    required String id,
    required int epochMilliseconds,
    required double price,
    ChartOverlaySide side = ChartOverlaySide.neutral,
    String? label,
  }) {
    if (id.trim().isEmpty || epochMilliseconds < 0 || !price.isFinite) {
      throw ArgumentError('Invalid event overlay.');
    }
    return ChartEventOverlay._(id, epochMilliseconds, price, side, label);
  }
  const ChartEventOverlay._(
    this.id,
    this.epochMilliseconds,
    this.price,
    this.side,
    this.label,
  );
  final String id;
  final int epochMilliseconds;
  final double price;
  final ChartOverlaySide side;
  final String? label;
}

/// A compact value marker placed on a price coordinate.
final class ChartValueMarker {
  factory ChartValueMarker({
    required String id,
    required double price,
    required String text,
    ChartOverlaySide side = ChartOverlaySide.neutral,
  }) {
    if (id.trim().isEmpty || text.trim().isEmpty || !price.isFinite) {
      throw ArgumentError('Invalid value marker.');
    }
    return ChartValueMarker._(id, price, text, side);
  }
  const ChartValueMarker._(this.id, this.price, this.text, this.side);
  final String id;
  final double price;
  final String text;
  final ChartOverlaySide side;
}
