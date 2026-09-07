import 'dart:collection';

/// A durable, host-owned description of a V2 chart's user preferences.
///
/// The package deliberately does not read or write storage. Applications can
/// persist [toJson] with any JSON store and restore it with [fromJson]. The
/// schema is versioned so older preferences can be migrated without coupling
/// a host to the chart Widget's private state.
final class KChartUserConfig {
  factory KChartUserConfig({
    String? instrumentId,
    String intervalCode = '1m',
    String mainMode = 'candlestick',
    int timeZoneOffsetMinutes = 0,
    Iterable<KChartIndicatorPreference> mainIndicators = const [],
    Iterable<KChartIndicatorPreference> secondaryIndicators = const [],
    bool overlaySecondaryIndicators = false,
    double secondaryPanelHeight = 108,
    double mainIndicatorHeaderHeight = 18,
    double secondaryIndicatorHeaderHeight = 18,
    double mainTimeAxisHeight = 18,
  }) {
    _requireOptionalId(instrumentId, 'instrumentId');
    _requireId(intervalCode, 'intervalCode');
    if (!_mainModes.contains(mainMode)) {
      throw ArgumentError.value(
        mainMode,
        'mainMode',
        'Unsupported chart mode.',
      );
    }
    if (timeZoneOffsetMinutes < -12 * 60 || timeZoneOffsetMinutes > 14 * 60) {
      throw ArgumentError.value(
        timeZoneOffsetMinutes,
        'timeZoneOffsetMinutes',
        'Must be within UTC-12:00 to UTC+14:00.',
      );
    }
    _requireDimension(secondaryPanelHeight, 'secondaryPanelHeight');
    _requireDimension(mainIndicatorHeaderHeight, 'mainIndicatorHeaderHeight');
    _requireDimension(
      secondaryIndicatorHeaderHeight,
      'secondaryIndicatorHeaderHeight',
    );
    _requireDimension(mainTimeAxisHeight, 'mainTimeAxisHeight');
    return KChartUserConfig._(
      instrumentId: instrumentId,
      intervalCode: intervalCode,
      mainMode: mainMode,
      timeZoneOffsetMinutes: timeZoneOffsetMinutes,
      mainIndicators: List.unmodifiable(mainIndicators),
      secondaryIndicators: List.unmodifiable(secondaryIndicators),
      overlaySecondaryIndicators: overlaySecondaryIndicators,
      secondaryPanelHeight: secondaryPanelHeight,
      mainIndicatorHeaderHeight: mainIndicatorHeaderHeight,
      secondaryIndicatorHeaderHeight: secondaryIndicatorHeaderHeight,
      mainTimeAxisHeight: mainTimeAxisHeight,
    );
  }

  const KChartUserConfig._({
    required this.instrumentId,
    required this.intervalCode,
    required this.mainMode,
    required this.timeZoneOffsetMinutes,
    required this.mainIndicators,
    required this.secondaryIndicators,
    required this.overlaySecondaryIndicators,
    required this.secondaryPanelHeight,
    required this.mainIndicatorHeaderHeight,
    required this.secondaryIndicatorHeaderHeight,
    required this.mainTimeAxisHeight,
  });

  /// The schema emitted by [toJson].
  static const schemaVersion = 1;

  static const _mainModes = <String>{
    'candlestick',
    'hollowCandlestick',
    'ohlc',
    'heikinAshi',
    'line',
    'area',
  };

  final String? instrumentId;
  final String intervalCode;
  final String mainMode;
  final int timeZoneOffsetMinutes;
  final List<KChartIndicatorPreference> mainIndicators;
  final List<KChartIndicatorPreference> secondaryIndicators;
  final bool overlaySecondaryIndicators;
  final double secondaryPanelHeight;
  final double mainIndicatorHeaderHeight;
  final double secondaryIndicatorHeaderHeight;
  final double mainTimeAxisHeight;

  /// Converts this immutable preference value to JSON-safe primitives.
  Map<String, Object?> toJson() => UnmodifiableMapView({
        'schemaVersion': schemaVersion,
        if (instrumentId != null) 'instrumentId': instrumentId,
        'intervalCode': intervalCode,
        'mainMode': mainMode,
        'timeZoneOffsetMinutes': timeZoneOffsetMinutes,
        'mainIndicators': mainIndicators.map((item) => item.toJson()).toList(),
        'secondaryIndicators':
            secondaryIndicators.map((item) => item.toJson()).toList(),
        'overlaySecondaryIndicators': overlaySecondaryIndicators,
        'secondaryPanelHeight': secondaryPanelHeight,
        'mainIndicatorHeaderHeight': mainIndicatorHeaderHeight,
        'secondaryIndicatorHeaderHeight': secondaryIndicatorHeaderHeight,
        'mainTimeAxisHeight': mainTimeAxisHeight,
      });

  /// Parses the current schema and migrates the pre-versioned V2 Demo shape.
  ///
  /// Version 0 accepted `period`, `isLine`, `mainState`, `secondaryStates`,
  /// and `timeZoneOffsetHours`. Unknown future versions fail explicitly so a
  /// newer host never has preferences silently discarded by an older package.
  factory KChartUserConfig.fromJson(Map<String, Object?> json) {
    final source = Map<String, Object?>.unmodifiable(json);
    final version = _optionalInt(source['schemaVersion']) ?? 0;
    if (version > schemaVersion) {
      throw UnsupportedError(
        'KChartUserConfig schema $version is newer than $schemaVersion.',
      );
    }
    if (version < 0) {
      throw const FormatException('schemaVersion must not be negative.');
    }
    return switch (version) {
      0 => _fromVersionZero(source),
      schemaVersion => _fromVersionOne(source),
      _ =>
        throw UnsupportedError('Unsupported KChartUserConfig schema $version.'),
    };
  }

  static KChartUserConfig _fromVersionOne(Map<String, Object?> source) =>
      KChartUserConfig(
        instrumentId: _optionalString(source['instrumentId'], 'instrumentId'),
        intervalCode: _requiredString(source['intervalCode'], 'intervalCode'),
        mainMode: _requiredString(source['mainMode'], 'mainMode'),
        timeZoneOffsetMinutes:
            _optionalInt(source['timeZoneOffsetMinutes']) ?? 0,
        mainIndicators:
            _indicatorList(source['mainIndicators'], 'mainIndicators'),
        secondaryIndicators: _indicatorList(
          source['secondaryIndicators'],
          'secondaryIndicators',
        ),
        overlaySecondaryIndicators:
            _optionalBool(source['overlaySecondaryIndicators']) ?? false,
        secondaryPanelHeight:
            _optionalDouble(source['secondaryPanelHeight']) ?? 108,
        mainIndicatorHeaderHeight:
            _optionalDouble(source['mainIndicatorHeaderHeight']) ?? 18,
        secondaryIndicatorHeaderHeight:
            _optionalDouble(source['secondaryIndicatorHeaderHeight']) ?? 18,
        mainTimeAxisHeight: _optionalDouble(source['mainTimeAxisHeight']) ?? 18,
      );

  static KChartUserConfig _fromVersionZero(Map<String, Object?> source) {
    final mainState = _optionalString(source['mainState'], 'mainState');
    final legacyMain = mainState == null || _legacyNone(mainState)
        ? const <KChartIndicatorPreference>[]
        : [
            KChartIndicatorPreference(
              instanceId: '${_legacyId(mainState)}-1',
              definitionId: 'legacy.${_legacyId(mainState)}',
            ),
          ];
    final legacySecondary = _legacyIndicatorList(source['secondaryStates']);
    return KChartUserConfig(
      instrumentId: _optionalString(source['instrumentId'], 'instrumentId'),
      intervalCode: _optionalString(source['period'], 'period') ?? '1m',
      mainMode:
          (_optionalBool(source['isLine']) ?? false) ? 'line' : 'candlestick',
      timeZoneOffsetMinutes:
          (_optionalInt(source['timeZoneOffsetHours']) ?? 0) * 60,
      mainIndicators: legacyMain,
      secondaryIndicators: legacySecondary,
      overlaySecondaryIndicators:
          _optionalBool(source['overlaySecondaryIndicators']) ?? false,
      secondaryPanelHeight:
          _optionalDouble(source['secondaryPanelHeight']) ?? 108,
      mainIndicatorHeaderHeight:
          _optionalDouble(source['mainIndicatorHeaderHeight']) ?? 18,
      secondaryIndicatorHeaderHeight:
          _optionalDouble(source['secondaryIndicatorHeaderHeight']) ?? 18,
      mainTimeAxisHeight: _optionalDouble(source['mainTimeAxisHeight']) ?? 18,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KChartUserConfig &&
          instrumentId == other.instrumentId &&
          intervalCode == other.intervalCode &&
          mainMode == other.mainMode &&
          timeZoneOffsetMinutes == other.timeZoneOffsetMinutes &&
          _listEquals(mainIndicators, other.mainIndicators) &&
          _listEquals(secondaryIndicators, other.secondaryIndicators) &&
          overlaySecondaryIndicators == other.overlaySecondaryIndicators &&
          secondaryPanelHeight == other.secondaryPanelHeight &&
          mainIndicatorHeaderHeight == other.mainIndicatorHeaderHeight &&
          secondaryIndicatorHeaderHeight ==
              other.secondaryIndicatorHeaderHeight &&
          mainTimeAxisHeight == other.mainTimeAxisHeight;

  @override
  int get hashCode => Object.hash(
        instrumentId,
        intervalCode,
        mainMode,
        timeZoneOffsetMinutes,
        Object.hashAll(mainIndicators),
        Object.hashAll(secondaryIndicators),
        overlaySecondaryIndicators,
        secondaryPanelHeight,
        mainIndicatorHeaderHeight,
        secondaryIndicatorHeaderHeight,
        mainTimeAxisHeight,
      );
}

/// A JSON-safe indicator instance reference used by [KChartUserConfig].
final class KChartIndicatorPreference {
  factory KChartIndicatorPreference({
    required String instanceId,
    required String definitionId,
    Map<String, num> parameters = const {},
    Map<String, String> seriesStyleKeys = const {},
  }) {
    _requireId(instanceId, 'instanceId');
    _requireId(definitionId, 'definitionId');
    _validateMap(parameters, 'parameters', (value) => value.isFinite);
    _validateMap(
      seriesStyleKeys,
      'seriesStyleKeys',
      (value) => value.trim().isNotEmpty,
    );
    return KChartIndicatorPreference._(
      instanceId: instanceId,
      definitionId: definitionId,
      parameters: Map.unmodifiable(parameters),
      seriesStyleKeys: Map.unmodifiable(seriesStyleKeys),
    );
  }

  const KChartIndicatorPreference._({
    required this.instanceId,
    required this.definitionId,
    required this.parameters,
    required this.seriesStyleKeys,
  });

  final String instanceId;
  final String definitionId;
  final Map<String, num> parameters;
  final Map<String, String> seriesStyleKeys;

  Map<String, Object?> toJson() => UnmodifiableMapView({
        'instanceId': instanceId,
        'definitionId': definitionId,
        'parameters': Map<String, num>.from(parameters),
        'seriesStyleKeys': Map<String, String>.from(seriesStyleKeys),
      });

  factory KChartIndicatorPreference.fromJson(Map<String, Object?> json) =>
      KChartIndicatorPreference(
        instanceId: _requiredString(json['instanceId'], 'instanceId'),
        definitionId: _requiredString(json['definitionId'], 'definitionId'),
        parameters: _numberMap(json['parameters'], 'parameters'),
        seriesStyleKeys: _stringMap(json['seriesStyleKeys'], 'seriesStyleKeys'),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KChartIndicatorPreference &&
          instanceId == other.instanceId &&
          definitionId == other.definitionId &&
          _mapEquals(parameters, other.parameters) &&
          _mapEquals(seriesStyleKeys, other.seriesStyleKeys);

  @override
  int get hashCode => Object.hash(
        instanceId,
        definitionId,
        _mapHash(parameters),
        _mapHash(seriesStyleKeys),
      );
}

List<KChartIndicatorPreference> _indicatorList(Object? value, String name) {
  if (value == null) return const [];
  if (value is! List) throw FormatException('$name must be a JSON array.');
  return List<KChartIndicatorPreference>.unmodifiable(
    value.map((item) {
      if (item is! Map) throw FormatException('$name entries must be objects.');
      return KChartIndicatorPreference.fromJson(_objectMap(item, name));
    }),
  );
}

List<KChartIndicatorPreference> _legacyIndicatorList(Object? value) {
  if (value == null) {
    return const [];
  }
  if (value is! List) {
    throw const FormatException('secondaryStates must be a JSON array.');
  }
  final occurrence = <String, int>{};
  return List<KChartIndicatorPreference>.unmodifiable(
    value.map((item) {
      if (item is! String || item.trim().isEmpty) {
        throw const FormatException(
          'secondaryStates entries must be non-empty strings.',
        );
      }
      final id = _legacyId(item);
      final next = (occurrence[id] ?? 0) + 1;
      occurrence[id] = next;
      return KChartIndicatorPreference(
        instanceId: '$id-$next',
        definitionId: 'legacy.$id',
      );
    }),
  );
}

String _legacyId(String value) {
  final normalized = value.trim().split('.').last;
  if (normalized.isEmpty) {
    throw FormatException('Invalid legacy indicator $value.');
  }
  return normalized;
}

bool _legacyNone(String value) => _legacyId(value) == 'none';

Map<String, Object?> _objectMap(Map value, String name) => Map.fromEntries(
      value.entries.map((entry) {
        if (entry.key is! String) {
          throw FormatException('$name keys must be strings.');
        }
        return MapEntry(entry.key as String, entry.value);
      }),
    );

Map<String, num> _numberMap(Object? value, String name) {
  if (value == null) return const {};
  if (value is! Map) throw FormatException('$name must be an object.');
  final result = <String, num>{};
  for (final entry in value.entries) {
    if (entry.key is! String ||
        entry.value is! num ||
        !(entry.value as num).isFinite) {
      throw FormatException('$name must contain finite numeric values.');
    }
    result[entry.key as String] = entry.value as num;
  }
  return result;
}

Map<String, String> _stringMap(Object? value, String name) {
  if (value == null) return const {};
  if (value is! Map) throw FormatException('$name must be an object.');
  final result = <String, String>{};
  for (final entry in value.entries) {
    if (entry.key is! String || entry.value is! String) {
      throw FormatException('$name must contain string values.');
    }
    result[entry.key as String] = entry.value as String;
  }
  return result;
}

String _requiredString(Object? value, String name) {
  final result = _optionalString(value, name);
  if (result == null) throw FormatException('$name is required.');
  return result;
}

String? _optionalString(Object? value, String name) {
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$name must be a non-empty string.');
  }
  return value;
}

int? _optionalInt(Object? value) {
  if (value == null) return null;
  if (value is! int) throw const FormatException('Expected an integer.');
  return value;
}

double? _optionalDouble(Object? value) {
  if (value == null) return null;
  if (value is! num || !value.isFinite) {
    throw const FormatException('Expected a finite number.');
  }
  return value.toDouble();
}

bool? _optionalBool(Object? value) {
  if (value == null) return null;
  if (value is! bool) throw const FormatException('Expected a boolean.');
  return value;
}

void _requireId(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'Must not be empty.');
  }
}

void _requireOptionalId(String? value, String name) {
  if (value != null) _requireId(value, name);
}

void _requireDimension(double value, String name) {
  if (!value.isFinite || value < 0) {
    throw ArgumentError.value(value, name, 'Must be finite and non-negative.');
  }
}

void _validateMap<T>(
  Map<String, T> values,
  String name,
  bool Function(T value) isValid,
) {
  for (final entry in values.entries) {
    if (entry.key.trim().isEmpty || !isValid(entry.value)) {
      throw ArgumentError.value(values, name, 'Contains an invalid entry.');
    }
  }
}

bool _listEquals<T>(List<T> first, List<T> second) {
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}

bool _mapEquals<K, V>(Map<K, V> first, Map<K, V> second) {
  if (first.length != second.length) return false;
  for (final entry in first.entries) {
    if (second[entry.key] != entry.value) return false;
  }
  return true;
}

int _mapHash<K, V>(Map<K, V> values) {
  var hash = 0;
  for (final entry in values.entries) {
    hash ^= Object.hash(entry.key, entry.value);
  }
  return hash;
}
