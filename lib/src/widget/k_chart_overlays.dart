import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../controller/k_chart_data_coordinator.dart';
import 'k_chart_frame.dart';
import 'k_chart_labels.dart';
import 'k_chart_legend.dart';

typedef KChartSelectionBuilder = Widget Function(
  BuildContext context,
  KChartSelection selection,
);

/// 图表自身的只读覆盖 UI。统一 IgnorePointer，避免信息面板或文字拦截平移/缩放。
final class KChartOverlaysView extends StatelessWidget {
  const KChartOverlaysView({
    required this.frame,
    required this.selection,
    this.labels = const KChartLabels.zhCN(),
    this.selectionBuilder,
    super.key,
  });

  final KChartFrame frame;
  final KChartSelection? selection;
  final KChartLabels labels;
  final KChartSelectionBuilder? selectionBuilder;

  @override
  Widget build(BuildContext context) {
    final main = frame.snapshot.layout.mainPanel.bounds;
    final onRight =
        frame.snapshot.selection.localX < (main.left + main.right) / 2;
    final availableWidth = math.max(0.0, main.width - 16);
    final width = math.min(144.0, availableWidth);
    return IgnorePointer(
      child: Stack(
        children: [
          for (final panel in frame.snapshot.layout.panels)
            if (frame.legends[panel.spec.id]!.items.isNotEmpty)
              Positioned(
                key: ValueKey('k-chart-header-${panel.spec.id}'),
                left: panel.headerBounds.left +
                    math.min(8, panel.headerBounds.width / 2),
                top: panel.headerBounds.top,
                width: math.max(0, panel.headerBounds.width - 16),
                height: panel.headerBounds.height,
                child: KChartLegend(layout: frame.legends[panel.spec.id]!),
              ),
          if (selection != null && width > 0 && main.height > 16)
            Positioned(
              key: const ValueKey('k-chart-details-position'),
              left: onRight ? main.right - width - 8 : main.left + 8,
              top: main.top + 8,
              width: width,
              height: main.height - 16,
              child: ClipRect(
                child: Align(
                  alignment: onRight ? Alignment.topRight : Alignment.topLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: onRight ? Alignment.topRight : Alignment.topLeft,
                    child: SizedBox(
                      width: 144,
                      child: selectionBuilder?.call(context, selection!) ??
                          _details(),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _details() {
    final selected = selection!;
    final candle = selected.candle;
    final theme = frame.snapshot.theme;
    final reference = selected.previousCandle?.close ?? candle.open;
    final change = candle.close - reference;
    final percent = reference == 0 ? 0.0 : change / reference * 100;
    final amplitude =
        reference == 0 ? 0.0 : (candle.high - candle.low) / reference * 100;
    final color = change >= 0 ? theme.upColor : theme.downColor;
    Widget row(String label, String value, {Color? valueColor}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(
            children: [
              Flexible(child: Text(label)),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: TextStyle(color: valueColor),
                ),
              ),
            ],
          ),
        );
    return Container(
      key: const ValueKey('k-chart-details'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: theme.crosshairDetailBackgroundColor,
        border: Border.all(color: theme.crosshairDetailBorderColor),
        borderRadius: BorderRadius.circular(6),
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          color: theme.crosshairDetailTextColor,
          fontSize: 11,
          height: 1.42,
          fontWeight: FontWeight.normal,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            row(labels.time, frame.snapshot.formatCrosshairTime(candle)),
            row(labels.open, theme.formatMainValue(candle.open)),
            row(labels.high, theme.formatMainValue(candle.high)),
            row(labels.low, theme.formatMainValue(candle.low)),
            row(labels.close, theme.formatMainValue(candle.close)),
            row(
              labels.change,
              '${change >= 0 ? '+' : ''}${theme.formatMainValue(change)}',
              valueColor: color,
            ),
            row(
              labels.changePercent,
              '${percent >= 0 ? '+' : ''}${percent.toStringAsFixed(2)}%',
              valueColor: color,
            ),
            row(labels.amplitude, '${amplitude.toStringAsFixed(2)}%'),
            row(labels.volume, theme.formatSecondaryValue(candle.baseVolume)),
            row(labels.amount, theme.formatSecondaryValue(candle.quoteVolume)),
            row(
              labels.selectedValue,
              selected.panelId == 'main'
                  ? theme.formatMainValue(selected.value)
                  : theme.formatSecondaryValue(selected.value),
            ),
          ],
        ),
      ),
    );
  }
}
