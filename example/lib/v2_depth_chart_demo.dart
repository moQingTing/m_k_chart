import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:m_k_chart/k_chart_theme.dart';
import 'package:m_k_chart/v2_example_support.dart';

DepthBook buildDemoDepthBook(double referencePrice, {int levelCount = 32}) {
  if (!referencePrice.isFinite || referencePrice <= 0) {
    throw ArgumentError.value(
      referencePrice,
      'referencePrice',
      'Must be finite and positive.',
    );
  }
  if (levelCount <= 0 || levelCount > 1000) {
    throw ArgumentError.value(
      levelCount,
      'levelCount',
      'Must be between 1 and 1000.',
    );
  }
  final tick = referencePrice * 0.00045;
  return DepthBook(
    bids: [
      for (var index = 0; index < levelCount; index++)
        DepthLevel(
          price: referencePrice - tick * (index + 1) * (1 + index * 0.012),
          quantity: 0.8 + (index % 7) * 0.31 + math.sqrt(index + 1) * 0.22,
        ),
    ],
    asks: [
      for (var index = 0; index < levelCount; index++)
        DepthLevel(
          price: referencePrice + tick * (index + 1) * (1 + index * 0.017),
          quantity: 0.7 + (index % 5) * 0.37 + math.sqrt(index + 1) * 0.25,
        ),
    ],
  );
}

class V2DepthChartDemo extends StatelessWidget {
  const V2DepthChartDemo({
    required this.referencePrice,
    required this.theme,
    required this.version,
    super.key,
  });

  final double referencePrice;
  final KChartTheme theme;
  final int version;

  @override
  Widget build(BuildContext context) {
    final book = buildDemoDepthBook(referencePrice);
    return Column(
      key: const ValueKey('v2-depth-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'V2 买卖深度',
          style: TextStyle(
            color: Color(0xff0f172a),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '买一 ${theme.formatMainValue(book.bestBid!.price)}  ·  '
          '卖一 ${theme.formatMainValue(book.bestAsk!.price)}  ·  '
          '价差 ${theme.formatMainValue(book.spread!)}',
          key: const ValueKey('v2-depth-summary'),
          style: const TextStyle(
            color: Color(0xff475569),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 220,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final layout = DepthChartLayout(
                size: Size(math.max(1, constraints.maxWidth), 220),
              );
              final snapshot = DepthRenderSnapshot<KChartTheme>(
                book: book,
                theme: theme,
                layout: layout,
                version: version,
              );
              return RepaintBoundary(
                child: CustomPaint(
                  key: const ValueKey('v2-depth-canvas'),
                  size: layout.size,
                  painter: _V2DepthPainter(snapshot),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '绿色为买盘累计量，红色为卖盘累计量；横向距离按真实价格差绘制。',
          style: TextStyle(color: Color(0xff64748b), fontSize: 11),
        ),
      ],
    );
  }
}

final class _V2DepthPainter extends CustomPainter {
  const _V2DepthPainter(this.snapshot);

  final DepthRenderSnapshot<KChartTheme> snapshot;

  @override
  void paint(Canvas canvas, Size size) => StandardDepthCurveRenderer.paint(
        canvas: canvas,
        snapshot: snapshot,
      );

  @override
  bool shouldRepaint(_V2DepthPainter oldDelegate) =>
      oldDelegate.snapshot.version != snapshot.version ||
      oldDelegate.snapshot.book != snapshot.book ||
      oldDelegate.snapshot.theme != snapshot.theme ||
      oldDelegate.snapshot.layout != snapshot.layout;
}
