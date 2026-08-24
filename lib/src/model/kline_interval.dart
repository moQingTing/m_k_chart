/// Defines whether a Kline interval has a fixed elapsed duration or follows
/// calendar month boundaries.
enum KlineIntervalKind {
  fixed,
  calendarMonth,
}

/// Immutable chart interval independent of any exchange transport API.
final class KlineInterval {
  factory KlineInterval.fixed({
    required String code,
    required Duration duration,
  }) {
    if (code.trim().isEmpty) {
      throw ArgumentError.value(code, 'code', 'Must not be empty.');
    }
    if (duration <= Duration.zero) {
      throw ArgumentError.value(duration, 'duration', 'Must be positive.');
    }
    return KlineInterval._(
      code: code,
      kind: KlineIntervalKind.fixed,
      duration: duration,
      calendarMonths: 0,
    );
  }

  factory KlineInterval.calendarMonth({
    required String code,
    int calendarMonths = 1,
  }) {
    if (code.trim().isEmpty) {
      throw ArgumentError.value(code, 'code', 'Must not be empty.');
    }
    if (calendarMonths <= 0) {
      throw ArgumentError.value(
        calendarMonths,
        'calendarMonths',
        'Must be positive.',
      );
    }
    return KlineInterval._(
      code: code,
      kind: KlineIntervalKind.calendarMonth,
      duration: null,
      calendarMonths: calendarMonths,
    );
  }

  const KlineInterval._({
    required this.code,
    required this.kind,
    required this.duration,
    required this.calendarMonths,
  });

  static final oneSecond = KlineInterval.fixed(
    code: '1s',
    duration: const Duration(seconds: 1),
  );
  static final oneMinute = KlineInterval.fixed(
    code: '1m',
    duration: const Duration(minutes: 1),
  );
  static final threeMinutes = KlineInterval.fixed(
    code: '3m',
    duration: const Duration(minutes: 3),
  );
  static final fiveMinutes = KlineInterval.fixed(
    code: '5m',
    duration: const Duration(minutes: 5),
  );
  static final fifteenMinutes = KlineInterval.fixed(
    code: '15m',
    duration: const Duration(minutes: 15),
  );
  static final thirtyMinutes = KlineInterval.fixed(
    code: '30m',
    duration: const Duration(minutes: 30),
  );
  static final oneHour = KlineInterval.fixed(
    code: '1h',
    duration: const Duration(hours: 1),
  );
  static final twoHours = KlineInterval.fixed(
    code: '2h',
    duration: const Duration(hours: 2),
  );
  static final fourHours = KlineInterval.fixed(
    code: '4h',
    duration: const Duration(hours: 4),
  );
  static final sixHours = KlineInterval.fixed(
    code: '6h',
    duration: const Duration(hours: 6),
  );
  static final eightHours = KlineInterval.fixed(
    code: '8h',
    duration: const Duration(hours: 8),
  );
  static final twelveHours = KlineInterval.fixed(
    code: '12h',
    duration: const Duration(hours: 12),
  );
  static final oneDay = KlineInterval.fixed(
    code: '1d',
    duration: const Duration(days: 1),
  );
  static final threeDays = KlineInterval.fixed(
    code: '3d',
    duration: const Duration(days: 3),
  );
  static final oneWeek = KlineInterval.fixed(
    code: '1w',
    duration: const Duration(days: 7),
  );
  static final oneMonth = KlineInterval.calendarMonth(code: '1M');

  final String code;
  final KlineIntervalKind kind;
  final Duration? duration;
  final int calendarMonths;

  bool get isFixed => kind == KlineIntervalKind.fixed;
  bool get isCalendarBased => kind == KlineIntervalKind.calendarMonth;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KlineInterval &&
          code == other.code &&
          kind == other.kind &&
          duration == other.duration &&
          calendarMonths == other.calendarMonths;

  @override
  int get hashCode => Object.hash(code, kind, duration, calendarMonths);

  @override
  String toString() => code;
}
