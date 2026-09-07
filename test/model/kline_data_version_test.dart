import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/model/model.dart';

void main() {
  test('KlineDataVersion is ordered and advances immutably', () {
    const initial = KlineDataVersion.zero;
    final next = initial.next();
    final third = next.next();

    expect(initial.value, 0);
    expect(next, KlineDataVersion(1));
    expect(third.isNewerThan(next), isTrue);
    expect(initial.compareTo(third), lessThan(0));
    expect(initial, isNot(next));
  });

  test('KlineDataVersion rejects negative values in every build mode', () {
    expect(() => KlineDataVersion(-1), throwsArgumentError);
  });
}
