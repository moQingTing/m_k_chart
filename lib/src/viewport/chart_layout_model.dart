import 'chart_viewport.dart';

enum ChartPanelKind {
  main,
  secondary,
}

/// 单个图表面板的不可变尺寸请求。
final class ChartPanelSpec {
  const ChartPanelSpec.main({
    this.id = 'main',
    this.weight = 3,
    this.minHeight = 120,
    this.headerHeight = 0,
    this.gridRows = 4,
    this.showHorizontalGrid = true,
  }) : kind = ChartPanelKind.main;

  const ChartPanelSpec.secondary({
    required this.id,
    this.weight = 1,
    this.minHeight = 60,
    this.headerHeight = 0,
    this.gridRows = 2,
    this.showHorizontalGrid = true,
  }) : kind = ChartPanelKind.secondary;

  final String id;
  final ChartPanelKind kind;
  final double weight;
  final double minHeight;

  /// 面板网格顶部的预留高度，用于参数栏等覆盖内容。该区域不绘制指标或 K 线，但网格会将其
  /// 作为独立的第一行保留。
  final double headerHeight;

  /// 纵向分段数量；实际生成的横线数为 [gridRows] + 1，包含面板上下边界。
  final int gridRows;

  /// 是否绘制面板内部横向网格线。为 false 时只保留完整网格区域的上下边界；跟随数据的竖线
  /// 对所有面板仍然可用。
  final bool showHorizontalGrid;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChartPanelSpec &&
          id == other.id &&
          kind == other.kind &&
          weight == other.weight &&
          minHeight == other.minHeight &&
          headerHeight == other.headerHeight &&
          gridRows == other.gridRows &&
          showHorizontalGrid == other.showHorizontalGrid;

  @override
  int get hashCode => Object.hash(
        id,
        kind,
        weight,
        minHeight,
        headerHeight,
        gridRows,
        showHorizontalGrid,
      );
}

/// 图表局部逻辑像素坐标中的矩形。
final class ChartLayoutRect {
  const ChartLayoutRect._({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;

  bool contains({required double x, required double y}) =>
      x >= left && x < right && y >= top && y < bottom;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChartLayoutRect &&
          left == other.left &&
          top == other.top &&
          right == other.right &&
          bottom == other.bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);

  @override
  String toString() => 'ChartLayoutRect($left, $top, $right, $bottom)';
}

final class ChartPanelLayout {
  const ChartPanelLayout._({
    required this.spec,
    required this.headerBounds,
    required this.bounds,
  });

  final ChartPanelSpec spec;

  /// 此面板网格顶部预留、不参与数据绘制的参数栏区域。
  final ChartLayoutRect headerBounds;

  /// K 线或指标的完整绘制区域。
  final ChartLayoutRect bounds;

  /// 完整视觉网格区域，包含预留的 [headerBounds]。
  ///
  /// K 线和指标始终裁剪至 [bounds]，因此参数栏文字不会被图表数据覆盖。
  ChartLayoutRect get gridBounds => headerBounds.height == 0
      ? bounds
      : ChartLayoutRect._(
          left: headerBounds.left,
          top: headerBounds.top,
          right: headerBounds.right,
          bottom: bounds.bottom,
        );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChartPanelLayout &&
          spec == other.spec &&
          headerBounds == other.headerBounds &&
          bounds == other.bounds;

  @override
  int get hashCode => Object.hash(spec, headerBounds, bounds);
}

/// 主图、副图、时间轴和网格坐标的确定性图表局部几何模型。
///
/// 渲染、命中测试与叠加组件必须共用此模型，不能各自推导像素边界；否则在自适应参数栏、
/// 多副图或 RTL 布局下容易出现错位。
final class ChartLayoutModel {
  factory ChartLayoutModel({
    required double width,
    required double height,
    double leftPadding = 0,
    double rightPadding = 0,
    double topPadding = 0,
    double bottomAxisHeight = 0,
    double mainTimeAxisHeight = 0,
    double panelSpacing = 0,
    int gridColumns = 4,
    ChartPanelSpec mainPanel = const ChartPanelSpec.main(),
    List<ChartPanelSpec> secondaryPanels = const [],
  }) {
    _validateDimensions(
      width: width,
      height: height,
      leftPadding: leftPadding,
      rightPadding: rightPadding,
      topPadding: topPadding,
      bottomAxisHeight: bottomAxisHeight,
      mainTimeAxisHeight: mainTimeAxisHeight,
      panelSpacing: panelSpacing,
      gridColumns: gridColumns,
    );
    final specs = [mainPanel, ...secondaryPanels];
    _validatePanels(specs);

    final drawableLeft = leftPadding;
    final drawableRight = width - rightPadding;
    final drawableBottom = height - bottomAxisHeight;
    if (drawableRight <= drawableLeft) {
      throw ArgumentError('Horizontal padding leaves no drawable width.');
    }

    final totalSpacing = panelSpacing * (specs.length - 1);
    final resolvedMainTimeAxisHeight =
        specs.length > 1 ? mainTimeAxisHeight : 0.0;
    final availablePanelHeight =
        drawableBottom - topPadding - totalSpacing - resolvedMainTimeAxisHeight;
    final reservedHeaderHeight = specs.fold<double>(
      0,
      (total, spec) => total + spec.headerHeight,
    );
    final minimumContentHeight = specs.fold<double>(
      0,
      (total, spec) => total + spec.minHeight,
    );
    if (availablePanelHeight < reservedHeaderHeight + minimumContentHeight) {
      throw ArgumentError(
        'Chart height provides $availablePanelHeight logical pixels for '
        'panel headers and content, but '
        '${reservedHeaderHeight + minimumContentHeight} is required.',
      );
    }

    final totalWeight = specs.fold<double>(
      0,
      (total, spec) => total + spec.weight,
    );
    final weightedContentHeight =
        availablePanelHeight - reservedHeaderHeight - minimumContentHeight;
    final layouts = <ChartPanelLayout>[];
    var top = topPadding;
    var mainTimeAxisBounds = ChartLayoutRect._(
      left: drawableLeft,
      top: topPadding,
      right: drawableRight,
      bottom: topPadding,
    );
    for (var index = 0; index < specs.length; index++) {
      final spec = specs[index];
      final isLast = index == specs.length - 1;
      final contentTop = top + spec.headerHeight;
      final contentHeight =
          spec.minHeight + weightedContentHeight * spec.weight / totalWeight;
      final bottom = isLast ? drawableBottom : contentTop + contentHeight;
      layouts.add(
        ChartPanelLayout._(
          spec: spec,
          headerBounds: ChartLayoutRect._(
            left: drawableLeft,
            top: top,
            right: drawableRight,
            bottom: contentTop,
          ),
          bounds: ChartLayoutRect._(
            left: drawableLeft,
            top: contentTop,
            right: drawableRight,
            bottom: bottom,
          ),
        ),
      );
      if (index == 0 && specs.length > 1) {
        mainTimeAxisBounds = ChartLayoutRect._(
          left: drawableLeft,
          top: bottom,
          right: drawableRight,
          bottom: bottom + resolvedMainTimeAxisHeight,
        );
        top = mainTimeAxisBounds.bottom + panelSpacing;
      } else {
        top = bottom + panelSpacing;
      }
    }

    final immutableLayouts = List<ChartPanelLayout>.unmodifiable(layouts);
    final panelById = Map<String, ChartPanelLayout>.unmodifiable({
      for (final panel in immutableLayouts) panel.spec.id: panel,
    });
    final columnXs = List<double>.unmodifiable(
      List<double>.generate(
        gridColumns + 1,
        (index) =>
            drawableLeft + (drawableRight - drawableLeft) * index / gridColumns,
      ),
    );
    final rowYs = Map<String, List<double>>.unmodifiable({
      for (final panel in immutableLayouts)
        panel.spec.id: List<double>.unmodifiable(
          List<double>.generate(
            panel.spec.gridRows + 1,
            (index) =>
                panel.bounds.top +
                panel.bounds.height * index / panel.spec.gridRows,
          ),
        ),
    });

    return ChartLayoutModel._(
      width: width,
      height: height,
      leftPadding: leftPadding,
      rightPadding: rightPadding,
      topPadding: topPadding,
      bottomAxisHeight: bottomAxisHeight,
      mainTimeAxisHeight: mainTimeAxisHeight,
      panelSpacing: panelSpacing,
      gridColumns: gridColumns,
      drawingBounds: ChartLayoutRect._(
        left: drawableLeft,
        top: topPadding,
        right: drawableRight,
        bottom: drawableBottom,
      ),
      timeAxisBounds: ChartLayoutRect._(
        left: drawableLeft,
        top: drawableBottom,
        right: drawableRight,
        bottom: height,
      ),
      mainTimeAxisBounds: mainTimeAxisBounds,
      panels: immutableLayouts,
      panelById: panelById,
      gridColumnXs: columnXs,
      gridRowYs: rowYs,
    );
  }

  const ChartLayoutModel._({
    required this.width,
    required this.height,
    required this.leftPadding,
    required this.rightPadding,
    required this.topPadding,
    required this.bottomAxisHeight,
    required this.mainTimeAxisHeight,
    required this.panelSpacing,
    required this.gridColumns,
    required this.drawingBounds,
    required this.timeAxisBounds,
    required this.mainTimeAxisBounds,
    required this.panels,
    required this.panelById,
    required this.gridColumnXs,
    required this.gridRowYs,
  });

  final double width;
  final double height;
  final double leftPadding;
  final double rightPadding;
  final double topPadding;
  final double bottomAxisHeight;
  final double mainTimeAxisHeight;
  final double panelSpacing;

  /// 横向分段数量；[gridColumnXs] 会包含多一个边界坐标。
  final int gridColumns;

  final ChartLayoutRect drawingBounds;
  final ChartLayoutRect timeAxisBounds;
  final ChartLayoutRect mainTimeAxisBounds;
  final List<ChartPanelLayout> panels;
  final Map<String, ChartPanelLayout> panelById;
  final List<double> gridColumnXs;
  final Map<String, List<double>> gridRowYs;

  ChartPanelLayout get mainPanel => panels.first;
  Iterable<ChartPanelLayout> get secondaryPanels => panels.skip(1);

  ChartPanelLayout panel(String id) {
    final result = panelById[id];
    if (result == null) {
      throw ArgumentError.value(id, 'id', 'Unknown panel.');
    }
    return result;
  }

  List<double> gridRowYsFor(String panelId) {
    final result = gridRowYs[panelId];
    if (result == null) {
      throw ArgumentError.value(panelId, 'panelId', 'Unknown panel.');
    }
    return result;
  }

  ChartViewport applyTo(ChartViewport viewport) =>
      viewport.copyWith(width: drawingBounds.width);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChartLayoutModel &&
          width == other.width &&
          height == other.height &&
          leftPadding == other.leftPadding &&
          rightPadding == other.rightPadding &&
          topPadding == other.topPadding &&
          bottomAxisHeight == other.bottomAxisHeight &&
          mainTimeAxisHeight == other.mainTimeAxisHeight &&
          panelSpacing == other.panelSpacing &&
          gridColumns == other.gridColumns &&
          _listEquals(panels, other.panels);

  @override
  int get hashCode => Object.hashAll([
        width,
        height,
        leftPadding,
        rightPadding,
        topPadding,
        bottomAxisHeight,
        mainTimeAxisHeight,
        panelSpacing,
        gridColumns,
        ...panels,
      ]);
}

void _validateDimensions({
  required double width,
  required double height,
  required double leftPadding,
  required double rightPadding,
  required double topPadding,
  required double bottomAxisHeight,
  required double mainTimeAxisHeight,
  required double panelSpacing,
  required int gridColumns,
}) {
  final values = <String, double>{
    'width': width,
    'height': height,
    'leftPadding': leftPadding,
    'rightPadding': rightPadding,
    'topPadding': topPadding,
    'bottomAxisHeight': bottomAxisHeight,
    'mainTimeAxisHeight': mainTimeAxisHeight,
    'panelSpacing': panelSpacing,
  };
  for (final entry in values.entries) {
    if (!entry.value.isFinite || entry.value < 0) {
      throw ArgumentError.value(
        entry.value,
        entry.key,
        'Must be finite and non-negative.',
      );
    }
  }
  if (width <= 0 || height <= 0) {
    throw ArgumentError('Chart width and height must be positive.');
  }
  if (topPadding + bottomAxisHeight >= height) {
    throw ArgumentError('Vertical padding leaves no drawable height.');
  }
  if (gridColumns <= 0) {
    throw ArgumentError.value(gridColumns, 'gridColumns', 'Must be positive.');
  }
}

void _validatePanels(List<ChartPanelSpec> specs) {
  final ids = <String>{};
  for (var index = 0; index < specs.length; index++) {
    final spec = specs[index];
    final expectedKind =
        index == 0 ? ChartPanelKind.main : ChartPanelKind.secondary;
    if (spec.kind != expectedKind) {
      throw ArgumentError(
        index == 0
            ? 'The first panel must be a main panel.'
            : 'Only secondary panels may follow the main panel.',
      );
    }
    if (spec.id.trim().isEmpty || !ids.add(spec.id)) {
      throw ArgumentError.value(
        spec.id,
        'panel id',
        'Must be unique/non-empty.',
      );
    }
    if (!spec.weight.isFinite || spec.weight <= 0) {
      throw ArgumentError.value(spec.weight, 'weight', 'Must be positive.');
    }
    if (!spec.minHeight.isFinite || spec.minHeight <= 0) {
      throw ArgumentError.value(
        spec.minHeight,
        'minHeight',
        'Must be finite and positive.',
      );
    }
    if (!spec.headerHeight.isFinite || spec.headerHeight < 0) {
      throw ArgumentError.value(
        spec.headerHeight,
        'headerHeight',
        'Must be finite and non-negative.',
      );
    }
    if (spec.gridRows <= 0) {
      throw ArgumentError.value(spec.gridRows, 'gridRows', 'Must be positive.');
    }
  }
}

bool _listEquals<T>(List<T> first, List<T> second) {
  if (first.length != second.length) {
    return false;
  }
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) {
      return false;
    }
  }
  return true;
}
