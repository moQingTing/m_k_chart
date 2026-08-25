/// A half-open range of Kline indices visible in a chart viewport.
///
/// [start] is inclusive and [end] is exclusive. Partially visible items are
/// included, so [length] can be one greater than the number of whole slots
/// that fit in the viewport.
final class VisibleIndexRange {
  const VisibleIndexRange(this.start, this.end)
      : assert(start >= 0),
        assert(end >= start);

  const VisibleIndexRange.empty() : this(0, 0);

  final int start;
  final int end;

  int get length => end - start;
  bool get isEmpty => start == end;
  bool get isNotEmpty => !isEmpty;

  bool contains(int index) => index >= start && index < end;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VisibleIndexRange && start == other.start && end == other.end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'VisibleIndexRange($start, $end)';
}
