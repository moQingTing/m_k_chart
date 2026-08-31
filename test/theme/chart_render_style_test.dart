import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/theme/theme.dart';

void main() {
  test(
      'default render style is immutable and resolves colors deterministically',
      () {
    final source = <Color>[const Color(0xff112233)];
    final fill = <Color>[
      const Color(0x99112233),
      const Color(0x11112233),
    ];
    final style = DefaultChartRenderStyle(
      indicatorPalette: source,
      areaFillColors: fill,
    );
    source.add(const Color(0xff445566));
    fill.clear();

    expect(style.indicatorPalette, [const Color(0xff112233)]);
    expect(
      style.indicatorColor('ma.fast', 'value'),
      style.indicatorColor('ma.fast', 'value'),
    );
    expect(() => style.indicatorPalette.clear(), throwsUnsupportedError);
    expect(style.areaFillColors, hasLength(2));
    expect(() => style.areaFillColors.clear(), throwsUnsupportedError);
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
    expect(
      () => DefaultChartRenderStyle(areaFillColors: const [Color(0xff000000)]),
      throwsArgumentError,
    );
    expect(
      () => DefaultChartRenderStyle(candleWidthRatio: 1.1),
      throwsArgumentError,
    );
  });

  test('default value formatting keeps exponential values intact', () {
    final style = DefaultChartRenderStyle();

    expect(style.formatMainValue(1e21), isNot(contains(',')));
    expect(style.formatSecondaryValue(-1e21), isNot(contains(',')));
  });
}
