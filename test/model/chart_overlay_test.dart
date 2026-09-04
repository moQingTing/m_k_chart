import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/model/model.dart';

void main() {
  test('trading overlays stay SDK-free and validate coordinates', () {
    expect(
      ChartPriceLine(id: 'entry', price: 100).side,
      ChartOverlaySide.neutral,
    );
    expect(
      ChartPriceLine(id: 'entry', price: 100).style,
      ChartPriceLineStyle.solid,
    );
    expect(
      ChartEventOverlay(id: 'fill', epochMilliseconds: 1, price: 2).price,
      2,
    );
    expect(ChartValueMarker(id: 'mark', price: 3, text: '止损').text, '止损');
    expect(() => ChartPriceLine(id: '', price: 1), throwsArgumentError);
    expect(
      () => ChartEventOverlay(id: 'x', epochMilliseconds: -1, price: 1),
      throwsArgumentError,
    );
  });

  test('price line copy keeps identity and updates interactive state', () {
    final source = ChartPriceLine(
      id: 'entry',
      price: 100,
      side: ChartOverlaySide.buy,
      label: '限价买入',
      style: ChartPriceLineStyle.dashed,
    );

    final changed = source.copyWith(price: 101, visible: false);

    expect(changed.id, source.id);
    expect(changed.side, source.side);
    expect(changed.label, source.label);
    expect(changed.price, 101);
    expect(changed.visible, isFalse);
    expect(changed.style, ChartPriceLineStyle.dashed);
  });
}
