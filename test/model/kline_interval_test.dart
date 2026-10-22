import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/model/model.dart';

void main() {
  group('KlineInterval', () {
    test('provides fixed standard intervals with exact durations', () {
      expect(KlineInterval.oneSecond.code, '1s');
      expect(KlineInterval.oneSecond.duration, const Duration(seconds: 1));
      expect(KlineInterval.oneMinute.duration, const Duration(minutes: 1));
      expect(KlineInterval.threeMinutes.duration, const Duration(minutes: 3));
      expect(KlineInterval.fiveMinutes.duration, const Duration(minutes: 5));
      expect(
        KlineInterval.fifteenMinutes.duration,
        const Duration(minutes: 15),
      );
      expect(KlineInterval.thirtyMinutes.duration, const Duration(minutes: 30));
      expect(KlineInterval.oneHour.duration, const Duration(hours: 1));
      expect(KlineInterval.twoHours.duration, const Duration(hours: 2));
      expect(KlineInterval.fourHours.duration, const Duration(hours: 4));
      expect(KlineInterval.sixHours.duration, const Duration(hours: 6));
      expect(KlineInterval.eightHours.duration, const Duration(hours: 8));
      expect(KlineInterval.twelveHours.duration, const Duration(hours: 12));
      expect(KlineInterval.oneDay.duration, const Duration(days: 1));
      expect(KlineInterval.threeDays.duration, const Duration(days: 3));
      expect(KlineInterval.oneWeek.duration, const Duration(days: 7));
      expect(KlineInterval.oneWeek.isFixed, isTrue);
    });

    test('models a month as a calendar interval instead of thirty days', () {
      expect(KlineInterval.oneMonth.code, '1M');
      expect(KlineInterval.oneMonth.isCalendarBased, isTrue);
      expect(KlineInterval.oneMonth.duration, isNull);
      expect(KlineInterval.oneMonth.calendarMonths, 1);
    });

    test('supports validated custom fixed and calendar intervals', () {
      final fixed = KlineInterval.fixed(
        code: '45m',
        duration: const Duration(minutes: 45),
      );
      final sameFixed = KlineInterval.fixed(
        code: '45m',
        duration: const Duration(minutes: 45),
      );
      final quarterly = KlineInterval.calendarMonth(
        code: '3M',
        calendarMonths: 3,
      );

      expect(fixed, sameFixed);
      expect(fixed.hashCode, sameFixed.hashCode);
      expect(quarterly.calendarMonths, 3);
      expect(quarterly.toString(), '3M');
    });

    test('rejects empty codes and invalid lengths', () {
      expect(
        () =>
            KlineInterval.fixed(code: '', duration: const Duration(minutes: 1)),
        throwsArgumentError,
      );
      expect(
        () => KlineInterval.fixed(code: '0m', duration: Duration.zero),
        throwsArgumentError,
      );
      expect(
        () => KlineInterval.fixed(
          code: 'sub-ms',
          duration: const Duration(microseconds: 1500),
        ),
        throwsArgumentError,
      );
      expect(
        () => KlineInterval.calendarMonth(code: '0M', calendarMonths: 0),
        throwsArgumentError,
      );
    });
  });
}
