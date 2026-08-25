import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/theme/theme.dart';

void main() {
  test(
      'default render style is immutable and resolves colors deterministically',
      () {
    final source = <Color>[const Color(0xff112233)];
    final style = DefaultChartRenderStyle(indicatorPalette: source);
    source.add(const Color(0xff445566));

    expect(style.indicatorPalette, [const Color(0xff112233)]);
    expect(
      style.indicatorColor('ma.fast', 'value'),
      style.indicatorColor('ma.fast', 'value'),
    );
    expect(() => style.indicatorPalette.clear(), throwsUnsupportedError);
  });

  test('render style rejects empty palettes and invalid dimensions', () {
    expect(
      () => DefaultChartRenderStyle(indicatorPalette: const []),
      throwsArgumentError,
    );
    expect(
      () => DefaultChartRenderStyle(gridStrokeWidth: 0),
      throwsArgumentError,
    );
    expect(
      () => DefaultChartRenderStyle(axisFontSize: double.nan),
      throwsArgumentError,
    );
  });
}
