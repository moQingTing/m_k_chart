import '../model/model.dart';

enum IndicatorChangeKind { unchanged, append, prepend, update, replace }

/// Structural difference between two immutable Kline inputs.
///
/// The half-open ranges identify the portions that were not preserved. An
/// incremental definition can extend the range backwards by its own lookback.
final class IndicatorDataChange {
  const IndicatorDataChange._({
    required this.kind,
    required this.previousVersion,
    required this.currentVersion,
    required this.previousStart,
    required this.previousEnd,
    required this.currentStart,
    required this.currentEnd,
    required this.preservedPrefixLength,
    required this.preservedSuffixLength,
  });

  factory IndicatorDataChange.between(
    VersionedKlineData previous,
    VersionedKlineData current,
  ) {
    final oldData = previous.data;
    final newData = current.data;
    if (!_sameSeries(oldData, newData)) {
      return IndicatorDataChange._replace(previous, current);
    }

    var prefix = 0;
    final shorterLength =
        oldData.length < newData.length ? oldData.length : newData.length;
    while (prefix < shorterLength && oldData[prefix] == newData[prefix]) {
      prefix++;
    }

    var suffix = 0;
    while (suffix < shorterLength - prefix &&
        oldData[oldData.length - suffix - 1] ==
            newData[newData.length - suffix - 1]) {
      suffix++;
    }

    final kind = switch ((oldData.length, newData.length, prefix, suffix)) {
      (final oldLength, final newLength, final commonPrefix, _)
          when oldLength == newLength && commonPrefix == oldLength =>
        IndicatorChangeKind.unchanged,
      (final oldLength, final newLength, final commonPrefix, _)
          when newLength > oldLength && commonPrefix == oldLength =>
        IndicatorChangeKind.append,
      (final oldLength, final newLength, _, final commonSuffix)
          when newLength > oldLength && commonSuffix == oldLength =>
        IndicatorChangeKind.prepend,
      (final oldLength, final newLength, _, _) when oldLength == newLength =>
        IndicatorChangeKind.update,
      _ => IndicatorChangeKind.replace,
    };

    return IndicatorDataChange._(
      kind: kind,
      previousVersion: previous.version,
      currentVersion: current.version,
      previousStart: prefix,
      previousEnd: oldData.length - suffix,
      currentStart: prefix,
      currentEnd: newData.length - suffix,
      preservedPrefixLength: prefix,
      preservedSuffixLength: suffix,
    );
  }

  factory IndicatorDataChange._replace(
    VersionedKlineData previous,
    VersionedKlineData current,
  ) =>
      IndicatorDataChange._(
        kind: IndicatorChangeKind.replace,
        previousVersion: previous.version,
        currentVersion: current.version,
        previousStart: 0,
        previousEnd: previous.data.length,
        currentStart: 0,
        currentEnd: current.data.length,
        preservedPrefixLength: 0,
        preservedSuffixLength: 0,
      );

  final IndicatorChangeKind kind;
  final KlineDataVersion previousVersion;
  final KlineDataVersion currentVersion;
  final int previousStart;
  final int previousEnd;
  final int currentStart;
  final int currentEnd;
  final int preservedPrefixLength;
  final int preservedSuffixLength;

  int get previousChangedLength => previousEnd - previousStart;
  int get currentChangedLength => currentEnd - currentStart;
}

bool _sameSeries(List<Kline> previous, List<Kline> current) {
  if (previous.isEmpty || current.isEmpty) {
    return previous.isEmpty && current.isEmpty;
  }
  return previous.first.hasSameSeries(current.first);
}
