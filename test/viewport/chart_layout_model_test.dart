import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/viewport/viewport.dart';

void main() {
  group('ChartLayoutModel', () {
    test('allocates main and multiple secondary panels deterministically', () {
      final layout = _multiPanelLayout();

      expect(layout.drawingBounds.left, 10);
      expect(layout.drawingBounds.top, 12);
      expect(layout.drawingBounds.right, 340);
      expect(layout.drawingBounds.bottom, 370);
      expect(layout.timeAxisBounds.left, 10);
      expect(layout.timeAxisBounds.top, 370);
      expect(layout.timeAxisBounds.right, 340);
      expect(layout.timeAxisBounds.bottom, 400);
      expect(layout.mainPanel.spec.id, 'main');
      expect(layout.mainPanel.bounds.top, 12);
      expect(layout.mainPanel.bounds.height, closeTo(186, 1e-12));
      expect(layout.panel('volume').bounds.top, closeTo(202, 1e-12));
      expect(layout.panel('volume').bounds.height, closeTo(82, 1e-12));
      expect(layout.panel('macd').bounds.top, closeTo(288, 1e-12));
      expect(layout.panel('macd').bounds.bottom, 370);
      expect(layout.secondaryPanels.length, 2);
    });

    test('generates exactly interval count plus one grid positions', () {
      final layout = _multiPanelLayout();

      expect(layout.gridColumnXs, [10, 92.5, 175, 257.5, 340]);
      expect(layout.gridColumnXs.length, layout.gridColumns + 1);
      expect(layout.gridRowYsFor('main').length, 5);
      expect(layout.gridRowYsFor('volume').length, 3);
      expect(layout.gridRowYsFor('macd').length, 4);
      expect(layout.gridRowYsFor('main').first, layout.mainPanel.bounds.top);
      expect(layout.gridRowYsFor('main').last, layout.mainPanel.bounds.bottom);
      expect(
        layout.gridRowYsFor('macd').last,
        layout.panel('macd').bounds.bottom,
      );
    });

    test('lets a sole main panel fill all available vertical space', () {
      final layout = ChartLayoutModel(
        width: 300,
        height: 240,
        topPadding: 10,
        bottomAxisHeight: 20,
      );

      expect(layout.panels.length, 1);
      expect(layout.mainPanel.bounds.top, 10);
      expect(layout.mainPanel.bounds.bottom, 220);
      expect(layout.mainPanel.bounds.height, 210);
    });

    test('reserves panel headers outside drawable chart content', () {
      final layout = ChartLayoutModel(
        width: 300,
        height: 240,
        topPadding: 10,
        bottomAxisHeight: 20,
        mainPanel: const ChartPanelSpec.main(headerHeight: 24),
      );

      expect(layout.mainPanel.headerBounds.top, 10);
      expect(layout.mainPanel.headerBounds.bottom, 34);
      expect(layout.mainPanel.gridBounds.top, 10);
      expect(
          layout.mainPanel.gridBounds.bottom, layout.mainPanel.bounds.bottom);
      expect(layout.mainPanel.bounds.top, 34);
      expect(layout.mainPanel.bounds.bottom, 220);
      expect(layout.mainPanel.bounds.height, 186);
    });

    test('reserves an independent main time-axis geometry', () {
      final layout = ChartLayoutModel(
        width: 360,
        height: 400,
        leftPadding: 10,
        rightPadding: 20,
        topPadding: 12,
        bottomAxisHeight: 30,
        mainTimeAxisHeight: 24,
        panelSpacing: 4,
        mainPanel: const ChartPanelSpec.main(minHeight: 120),
        secondaryPanels: const [
          ChartPanelSpec.secondary(id: 'volume', minHeight: 60),
        ],
      );

      expect(layout.drawingBounds.right, 340);
      expect(layout.mainPanel.bounds.right, 340);
      expect(
        layout.mainTimeAxisBounds.top,
        layout.mainPanel.bounds.bottom,
      );
      expect(layout.mainTimeAxisBounds.height, 24);
      expect(
        layout.panel('volume').headerBounds.top,
        layout.mainTimeAxisBounds.bottom + 4,
      );
      expect(layout.gridColumnXs.last, 340);
    });

    test('applies drawable width to a viewport and re-clamps scrolling', () {
      final layout = _multiPanelLayout();
      final viewport = ChartViewport(
        itemCount: 100,
        width: 80,
        itemExtent: 8,
        scrollOffsetItems: 90,
      );

      final resized = layout.applyTo(viewport);

      expect(resized.width, 330);
      expect(resized.itemExtent, 8);
      expect(resized.scrollOffsetItems, 58.75);
      expect(resized.maxScrollOffsetItems, 58.75);
    });

    test('uses chart-local padded bounds for nested layouts', () {
      final layout = _multiPanelLayout();

      expect(layout.mainPanel.bounds.left, 10);
      expect(layout.mainPanel.bounds.right, 340);
      expect(layout.mainPanel.bounds.contains(x: 10, y: 12), isTrue);
      expect(layout.mainPanel.bounds.contains(x: 9.99, y: 12), isFalse);
      expect(
        layout.mainPanel.bounds.contains(
          x: 20,
          y: layout.mainPanel.bounds.bottom,
        ),
        isFalse,
      );
      expect(
        layout.panel('volume').bounds.contains(
              x: 20,
              y: layout.panel('volume').bounds.top,
            ),
        isTrue,
      );
      expect(layout.timeAxisBounds.top, 370);
    });

    test('publishes immutable collections and structural equality', () {
      final first = _multiPanelLayout();
      final second = _multiPanelLayout();

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(
        () => first.panels.add(first.mainPanel),
        throwsUnsupportedError,
      );
      expect(
        () => first.gridColumnXs.add(1),
        throwsUnsupportedError,
      );
      expect(
        () => first.gridRowYsFor('main').add(1),
        throwsUnsupportedError,
      );
      expect(() => first.panel('missing'), throwsArgumentError);
      expect(() => first.gridRowYsFor('missing'), throwsArgumentError);
    });

    test('rejects insufficient, degenerate, and ambiguous layouts', () {
      expect(
        () => ChartLayoutModel(width: 0, height: 200),
        throwsArgumentError,
      );
      expect(
        () => ChartLayoutModel(width: 100, height: double.nan),
        throwsArgumentError,
      );
      expect(
        () => ChartLayoutModel(
          width: 100,
          height: 200,
          leftPadding: 50,
          rightPadding: 50,
        ),
        throwsArgumentError,
      );
      expect(
        () => ChartLayoutModel(
          width: 200,
          height: 300,
          mainPanel: const ChartPanelSpec.main(headerHeight: -1),
        ),
        throwsArgumentError,
      );
      expect(
        () => ChartLayoutModel(width: 100, height: 119),
        throwsArgumentError,
      );
      expect(
        () => ChartLayoutModel(width: 100, height: 200, gridColumns: 0),
        throwsArgumentError,
      );
      expect(
        () => ChartLayoutModel(
          width: 200,
          height: 300,
          secondaryPanels: const [
            ChartPanelSpec.secondary(id: 'main'),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => ChartLayoutModel(
          width: 200,
          height: 300,
          mainPanel: const ChartPanelSpec.secondary(id: 'not-main'),
        ),
        throwsArgumentError,
      );
      expect(
        () => ChartLayoutModel(
          width: 200,
          height: 300,
          mainPanel: const ChartPanelSpec.main(weight: 0),
        ),
        throwsArgumentError,
      );
      expect(
        () => ChartLayoutModel(
          width: 200,
          height: 300,
          mainPanel: const ChartPanelSpec.main(minHeight: 0),
        ),
        throwsArgumentError,
      );
    });
  });
}

ChartLayoutModel _multiPanelLayout() => ChartLayoutModel(
      width: 360,
      height: 400,
      leftPadding: 10,
      rightPadding: 20,
      topPadding: 12,
      bottomAxisHeight: 30,
      panelSpacing: 4,
      gridColumns: 4,
      mainPanel: const ChartPanelSpec.main(
        minHeight: 120,
        weight: 3,
        gridRows: 4,
      ),
      secondaryPanels: const [
        ChartPanelSpec.secondary(
          id: 'volume',
          minHeight: 60,
          weight: 1,
          gridRows: 2,
        ),
        ChartPanelSpec.secondary(
          id: 'macd',
          minHeight: 60,
          weight: 1,
          gridRows: 3,
        ),
      ],
    );
