import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../controller/k_chart_data_coordinator.dart';
import '../indicator/indicator.dart';
import '../model/chart_main_mode.dart';
import '../render/render_snapshot.dart';
import '../theme/theme.dart';

/// 参数栏显示项。标签、数值和颜色来自当前提交，不能从旧 Demo 的可变配置反查。
final class KChartLegendEntry {
  const KChartLegendEntry({
    required this.id,
    required this.label,
    required this.value,
    required this.color,
    this.labelColor,
    this.separator = ': ',
  });

  final String id;
  final String label;
  final double? value;
  final Color color;
  final Color? labelColor;
  final String separator;
}

/// 参数栏完全读取指标描述符；新增指标无需在此按 definitionId 写特例。
List<KChartLegendEntry> kChartLegendEntries({
  required KChartRuntimeState state,
  required Iterable<RenderIndicatorSnapshot> indicators,
  required String panelId,
  required ChartRenderStyle style,
  required List<IndicatorParameterSpec> Function(String) parametersFor,
}) {
  if (panelId == 'main' && !state.options.mainMode.showsMainIndicators) {
    return const [];
  }
  final index = state.data.data.isEmpty
      ? null
      : state.selectedIndex ??
          (state.viewport.visibleRange.end - 1)
              .clamp(0, state.data.data.length - 1);
  final entries = <KChartLegendEntry>[];
  for (final indicator in indicators) {
    if (indicator.panelId != panelId) continue;
    final config = state.indicators
        .firstWhere(
          (binding) => binding.config.instanceId == indicator.instanceId,
        )
        .config;
    final specs = parametersFor(config.definitionId);
    final descriptors = indicator.descriptor.series;
    double? valueOf(IndicatorSeriesDescriptor descriptor) => index == null
        ? null
        : indicator.seriesById(descriptor.id)!.values[index];
    final legend = indicator.descriptor.legend;
    final shown = legend.display == IndicatorLegendDisplay.firstAvailable
        ? [
            descriptors.firstWhere(
              (item) => valueOf(item) != null,
              orElse: () => descriptors.first,
            ),
          ]
        : descriptors;
    for (final descriptor in shown) {
      final value = valueOf(descriptor);
      final baseColor =
          style.indicatorColor(indicator.instanceId, descriptor.id);
      final candle = index == null ? null : state.data.data[index];
      final color = value == null || candle == null
          ? baseColor
          : switch (descriptor.colorStrategy) {
              IndicatorColorStrategy.series => baseColor,
              IndicatorColorStrategy.candleDirection =>
                candle.close >= candle.open ? style.upColor : style.downColor,
              IndicatorColorStrategy.valueSign =>
                value >= 0 ? style.upColor : style.downColor,
              IndicatorColorStrategy.pricePosition =>
                value <= candle.close ? style.upColor : style.downColor,
            };
      entries.add(
        KChartLegendEntry(
          id: '${indicator.instanceId}:${legend.display == IndicatorLegendDisplay.firstAvailable ? 'selected' : descriptor.id}',
          label: _label(
            config,
            descriptor,
            specs,
            legend.labelTemplates[descriptor.id],
          ),
          value: value,
          color: color,
          labelColor: legend.neutralLabel ? style.axisTextColor : null,
          separator: legend.separator,
        ),
      );
    }
  }
  return List.unmodifiable(entries);
}

String _label(
  IndicatorConfig config,
  IndicatorSeriesDescriptor descriptor,
  List<IndicatorParameterSpec> specs,
  String? template,
) {
  if (template == null) return descriptor.label;
  final defaults = {for (final spec in specs) spec.key: spec.defaultValue};
  return template.replaceAllMapped(RegExp(r'\{([^{}]+)\}'), (match) {
    final name = match.group(1)!;
    final value = config.parameters[name] ?? defaults[name];
    if (value == null) return '?';
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  });
}

/// 测量和展示共用相同的文字/缩放/坐标，避免 Wrap 与预估行高不同导致覆盖 K 线。
final class KChartLegendLayout {
  KChartLegendLayout._(this.width, this.height, this.items, this.textScaler);

  factory KChartLegendLayout.measure({
    required List<KChartLegendEntry> entries,
    required double width,
    required String Function(double) formatValue,
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    final items = <({String id, TextSpan text, Rect rect})>[];
    var x = 0.0;
    var y = 0.0;
    var lineHeight = 0.0;
    for (final entry in entries) {
      final text = TextSpan(
        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.normal),
        children: [
          TextSpan(
            text: '${entry.label}${entry.separator}',
            style: TextStyle(color: entry.labelColor ?? entry.color),
          ),
          TextSpan(
            text: entry.value == null ? '--' : formatValue(entry.value!),
            style: TextStyle(color: entry.color),
          ),
        ],
      );
      final painter = TextPainter(
        text: text,
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      final itemWidth = math.min(width, painter.width.ceilToDouble());
      final itemHeight = painter.height.ceilToDouble();
      painter.dispose();
      if (x > 0 && x + itemWidth > width) {
        x = 0;
        y += lineHeight + 2;
        lineHeight = 0;
      }
      items.add(
        (
          id: entry.id,
          text: text,
          rect: Rect.fromLTWH(x, y, itemWidth, itemHeight)
        ),
      );
      lineHeight = math.max(lineHeight, itemHeight);
      x += itemWidth + 12;
    }
    return KChartLegendLayout._(
      width,
      y + lineHeight,
      List.unmodifiable(items),
      textScaler,
    );
  }

  final double width;
  final double height;
  final List<({String id, TextSpan text, Rect rect})> items;
  final TextScaler textScaler;
}

/// 无背景，靠左上下居中；固定高度不足时整体等比缩小，不能溢出到数据区。
final class KChartLegend extends StatelessWidget {
  const KChartLegend({required this.layout, super.key});
  final KChartLegendLayout layout;

  @override
  Widget build(BuildContext context) => ClipRect(
        child: Align(
          alignment: Alignment.centerLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: layout.width,
              height: layout.height,
              child: Stack(
                children: [
                  for (final item in layout.items)
                    Positioned.fromRect(
                      rect: item.rect,
                      child: RichText(
                        key: ValueKey('k-chart-legend-${item.id}'),
                        text: item.text,
                        textDirection: TextDirection.ltr,
                        textScaler: layout.textScaler,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
}
