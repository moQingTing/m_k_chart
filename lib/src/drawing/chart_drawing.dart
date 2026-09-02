import 'dart:collection';

/// Serializable tool families. Rendering and edit behavior are added by later
/// drawing phases; this enum keeps their persisted identity stable now.
enum ChartDrawingKind {
  trendLine,
  horizontalLine,
  verticalLine,
  ray,
  rectangle,
  parallelChannel,
  fibonacciRetracement,
  text,
  priceMarker;
}

/// An immutable anchor expressed in UTC time and chart price, never pixels.
final class ChartDrawingAnchor {
  factory ChartDrawingAnchor({
    required int epochMilliseconds,
    required double price,
  }) {
    if (epochMilliseconds < 0) {
      throw ArgumentError.value(
        epochMilliseconds,
        'epochMilliseconds',
        'Must be a UTC epoch millisecond value.',
      );
    }
    if (!price.isFinite) {
      throw ArgumentError.value(price, 'price', 'Must be finite.');
    }
    return ChartDrawingAnchor._(
      epochMilliseconds: epochMilliseconds,
      price: price,
    );
  }

  const ChartDrawingAnchor._({
    required this.epochMilliseconds,
    required this.price,
  });

  final int epochMilliseconds;
  final double price;

  Map<String, Object> toJson() => {
        'time': epochMilliseconds,
        'price': price,
      };

  factory ChartDrawingAnchor.fromJson(Map<String, Object?> json) =>
      ChartDrawingAnchor(
        epochMilliseconds: _requiredInt(json['time'], 'anchor.time'),
        price: _requiredDouble(json['price'], 'anchor.price'),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChartDrawingAnchor &&
          epochMilliseconds == other.epochMilliseconds &&
          price == other.price;

  @override
  int get hashCode => Object.hash(epochMilliseconds, price);
}

/// Semantic drawing presentation independent of Flutter's Color type.
final class ChartDrawingStyle {
  factory ChartDrawingStyle({
    String colorKey = 'drawing.default',
    double strokeWidth = 1,
    Iterable<double> dashPattern = const [],
    bool visible = true,
  }) {
    if (colorKey.trim().isEmpty) {
      throw ArgumentError.value(colorKey, 'colorKey', 'Must not be empty.');
    }
    if (!strokeWidth.isFinite || strokeWidth <= 0) {
      throw ArgumentError.value(
        strokeWidth,
        'strokeWidth',
        'Must be positive.',
      );
    }
    final dashes = List<double>.unmodifiable(dashPattern);
    if (dashes.any((value) => !value.isFinite || value <= 0)) {
      throw ArgumentError.value(
        dashPattern,
        'dashPattern',
        'Must be positive.',
      );
    }
    return ChartDrawingStyle._(
      colorKey: colorKey,
      strokeWidth: strokeWidth,
      dashPattern: dashes,
      visible: visible,
    );
  }

  const ChartDrawingStyle._({
    required this.colorKey,
    required this.strokeWidth,
    required this.dashPattern,
    required this.visible,
  });

  final String colorKey;
  final double strokeWidth;
  final List<double> dashPattern;
  final bool visible;

  Map<String, Object> toJson() => {
        'colorKey': colorKey,
        'strokeWidth': strokeWidth,
        'dashPattern': dashPattern,
        'visible': visible,
      };

  factory ChartDrawingStyle.fromJson(Map<String, Object?> json) =>
      ChartDrawingStyle(
        colorKey: _optionalString(json['colorKey']) ?? 'drawing.default',
        strokeWidth: _optionalDouble(json['strokeWidth']) ?? 1,
        dashPattern: _doubleList(json['dashPattern'], 'style.dashPattern'),
        visible: _optionalBool(json['visible']) ?? true,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChartDrawingStyle &&
          colorKey == other.colorKey &&
          strokeWidth == other.strokeWidth &&
          _listEquals(dashPattern, other.dashPattern) &&
          visible == other.visible;

  @override
  int get hashCode =>
      Object.hash(colorKey, strokeWidth, Object.hashAll(dashPattern), visible);
}

/// Versioned, time/price-anchored drawing value owned by the host/controller.
final class ChartDrawing {
  factory ChartDrawing({
    required String id,
    required ChartDrawingKind kind,
    required Iterable<ChartDrawingAnchor> anchors,
    ChartDrawingStyle? style,
    String? text,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty.');
    }
    final immutableAnchors = List<ChartDrawingAnchor>.unmodifiable(anchors);
    if (immutableAnchors.length < _minimumAnchors(kind)) {
      throw ArgumentError.value(
        anchors,
        'anchors',
        '${kind.name} requires at least ${_minimumAnchors(kind)} anchor(s).',
      );
    }
    if (kind == ChartDrawingKind.text &&
        (text == null || text.trim().isEmpty)) {
      throw ArgumentError.value(text, 'text', 'Text drawings require text.');
    }
    return ChartDrawing._(
      id: id,
      kind: kind,
      anchors: immutableAnchors,
      style: style ?? ChartDrawingStyle(),
      text: text,
    );
  }

  const ChartDrawing._({
    required this.id,
    required this.kind,
    required this.anchors,
    required this.style,
    required this.text,
  });

  static const schemaVersion = 1;

  final String id;
  final ChartDrawingKind kind;
  final List<ChartDrawingAnchor> anchors;
  final ChartDrawingStyle style;
  final String? text;

  Map<String, Object?> toJson() => UnmodifiableMapView({
        'schemaVersion': schemaVersion,
        'id': id,
        'kind': kind.name,
        'anchors': anchors.map((anchor) => anchor.toJson()).toList(),
        'style': style.toJson(),
        if (text != null) 'text': text,
      });

  factory ChartDrawing.fromJson(Map<String, Object?> json) {
    final version = _optionalInt(json['schemaVersion']) ?? 0;
    if (version > schemaVersion) {
      throw UnsupportedError(
        'Drawing schema $version is newer than $schemaVersion.',
      );
    }
    return switch (version) {
      0 => _fromLegacyJson(json),
      schemaVersion => ChartDrawing(
          id: _requiredString(json['id'], 'id'),
          kind: _kind(json['kind']),
          anchors: _anchors(json['anchors'], 'anchors'),
          style: _style(json['style']),
          text: _optionalString(json['text']),
        ),
      _ => throw UnsupportedError('Unsupported drawing schema $version.'),
    };
  }

  static ChartDrawing _fromLegacyJson(Map<String, Object?> json) =>
      ChartDrawing(
        id: _requiredString(json['id'], 'id'),
        kind: _kind(json['type']),
        anchors: _anchors(json['points'], 'points'),
        style: ChartDrawingStyle(
          colorKey: _optionalString(json['color']) ?? 'drawing.default',
          strokeWidth: _optionalDouble(json['width']) ?? 1,
        ),
        text: _optionalString(json['text']),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChartDrawing &&
          id == other.id &&
          kind == other.kind &&
          _listEquals(anchors, other.anchors) &&
          style == other.style &&
          text == other.text;

  @override
  int get hashCode =>
      Object.hash(id, kind, Object.hashAll(anchors), style, text);
}

int _minimumAnchors(ChartDrawingKind kind) => switch (kind) {
      ChartDrawingKind.horizontalLine ||
      ChartDrawingKind.verticalLine ||
      ChartDrawingKind.text ||
      ChartDrawingKind.priceMarker =>
        1,
      ChartDrawingKind.parallelChannel => 3,
      _ => 2,
    };

ChartDrawingKind _kind(Object? value) {
  final name = _requiredString(value, 'kind');
  for (final kind in ChartDrawingKind.values) {
    if (kind.name == name) return kind;
  }
  throw FormatException('Unknown drawing kind $name.');
}

ChartDrawingStyle _style(Object? value) {
  if (value == null) return ChartDrawingStyle();
  return ChartDrawingStyle.fromJson(_map(value, 'style'));
}

List<ChartDrawingAnchor> _anchors(Object? value, String name) {
  if (value is! List) throw FormatException('$name must be an array.');
  return List<ChartDrawingAnchor>.unmodifiable(
    value.map((item) => ChartDrawingAnchor.fromJson(_map(item, name))),
  );
}

Map<String, Object?> _map(Object? value, String name) {
  if (value is! Map) throw FormatException('$name must be an object.');
  return Map<String, Object?>.from(value);
}

List<double> _doubleList(Object? value, String name) {
  if (value == null) return const [];
  if (value is! List || value.any((item) => item is! num)) {
    throw FormatException('$name must be a numeric array.');
  }
  return value.cast<num>().map((item) => item.toDouble()).toList();
}

String _requiredString(Object? value, String name) =>
    _optionalString(value) ?? (throw FormatException('$name is required.'));

String? _optionalString(Object? value) {
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) {
    throw const FormatException('Expected a non-empty string.');
  }
  return value;
}

int _requiredInt(Object? value, String name) =>
    value is int ? value : (throw FormatException('$name must be an integer.'));

int? _optionalInt(Object? value) => value == null
    ? null
    : value is int
        ? value
        : (throw const FormatException('Expected an integer.'));

double _requiredDouble(Object? value, String name) =>
    value is num && value.isFinite
        ? value.toDouble()
        : (throw FormatException('$name must be finite.'));

double? _optionalDouble(Object? value) => value == null
    ? null
    : value is num && value.isFinite
        ? value.toDouble()
        : (throw const FormatException('Expected a finite number.'));

bool? _optionalBool(Object? value) => value == null
    ? null
    : value is bool
        ? value
        : (throw const FormatException('Expected a boolean.'));

bool _listEquals<T>(List<T> first, List<T> second) {
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}
