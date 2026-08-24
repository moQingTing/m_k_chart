/// Monotonically increasing identity for an immutable Kline data snapshot.
final class KlineDataVersion implements Comparable<KlineDataVersion> {
  factory KlineDataVersion(int value) {
    if (value < 0) {
      throw ArgumentError.value(value, 'value', 'Must be non-negative.');
    }
    return KlineDataVersion._(value);
  }

  const KlineDataVersion._(this.value);

  static const zero = KlineDataVersion._(0);

  final int value;

  KlineDataVersion next() => KlineDataVersion(value + 1);

  bool isNewerThan(KlineDataVersion other) => value > other.value;

  @override
  int compareTo(KlineDataVersion other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KlineDataVersion && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'KlineDataVersion($value)';
}
