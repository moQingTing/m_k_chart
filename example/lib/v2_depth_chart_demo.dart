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

class V2DepthChartDemo extends StatefulWidget {
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
  State<V2DepthChartDemo> createState() => _V2DepthChartDemoState();
}

class _V2DepthChartDemoState extends State<V2DepthChartDemo> {
  late final DepthRealtimeCoordinator _coordinator;
  var _nextSnapshotId = 1000;
  int? _recoverySnapshotId;
  var _status = '已应用初始深度快照';

  @override
  void initState() {
    super.initState();
    _coordinator = DepthRealtimeCoordinator();
    _applyBaseSnapshot(widget.referencePrice, _nextSnapshotId);
  }

  @override
  void didUpdateWidget(V2DepthChartDemo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.referencePrice != widget.referencePrice) {
      _coordinator.beginNextGeneration();
      _nextSnapshotId += 1000;
      _recoverySnapshotId = null;
      _applyBaseSnapshot(widget.referencePrice, _nextSnapshotId);
      _status = '行情变化，已切换到新一代深度快照';
    }
  }

  void _applyBaseSnapshot(double referencePrice, int updateId) {
    final book = buildDemoDepthBook(referencePrice);
    _coordinator.applySnapshot(
      DepthBookSnapshotEvent(
        symbol: 'DEMO-USDT',
        lastUpdateId: updateId,
        bids: book.bids,
        asks: book.asks,
      ),
      generation: _coordinator.generation,
    );
  }

  void _simulateDelta() {
    final state = _coordinator.state;
    final updateId = state.lastUpdateId;
    final bestBid = state.book.bestBid;
    if (!state.isSynchronized || updateId == null || bestBid == null) return;
    final result = _coordinator.addDelta(
      DepthDeltaEvent(
        symbol: state.symbol!,
        firstUpdateId: updateId + 1,
        finalUpdateId: updateId + 1,
        previousFinalUpdateId: updateId,
        bids: [
          DepthLevelUpdate(
            price: bestBid.price,
            quantity: bestBid.quantity + 0.75,
          ),
        ],
      ),
      generation: _coordinator.generation,
    );
    setState(() {
      _status = result.outcome == DepthMergeOutcome.deltaApplied
          ? '已合并增量 · update ID ${result.state.lastUpdateId}'
          : '增量未应用：${result.outcome.name}';
    });
  }

  void _simulateGap() {
    final state = _coordinator.state;
    final updateId = state.lastUpdateId;
    final bestAsk = state.book.bestAsk;
    if (!state.isSynchronized || updateId == null || bestAsk == null) return;
    _recoverySnapshotId = updateId + 1;
    final result = _coordinator.addDelta(
      DepthDeltaEvent(
        symbol: state.symbol!,
        firstUpdateId: updateId + 2,
        finalUpdateId: updateId + 2,
        previousFinalUpdateId: updateId + 1,
        asks: [
          DepthLevelUpdate(
            price: bestAsk.price,
            quantity: bestAsk.quantity + 0.6,
          ),
        ],
      ),
      generation: _coordinator.generation,
    );
    setState(() {
      _status = result.outcome == DepthMergeOutcome.outOfSync
          ? '检测到 update ID 缺口，需要重新同步'
          : '未触发预期缺口：${result.outcome.name}';
    });
  }

  void _recoverSnapshot() {
    final recoveryId = _recoverySnapshotId;
    if (recoveryId == null) return;
    _applyBaseSnapshot(widget.referencePrice, recoveryId);
    final state = _coordinator.state;
    setState(() {
      _recoverySnapshotId = null;
      _status = state.isSynchronized
          ? '已重新同步 · update ID ${state.lastUpdateId}'
          : '重新同步失败，仍需快照';
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = _coordinator.state;
    final book = state.book;
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
          '买一 ${widget.theme.formatMainValue(book.bestBid!.price)}  ·  '
          '卖一 ${widget.theme.formatMainValue(book.bestAsk!.price)}  ·  '
          '价差 ${widget.theme.formatMainValue(book.spread!)}',
          key: const ValueKey('v2-depth-summary'),
          style: const TextStyle(
            color: Color(0xff475569),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            OutlinedButton(
              key: const ValueKey('depth-simulate-delta'),
              onPressed: state.isSynchronized ? _simulateDelta : null,
              child: const Text('模拟正常增量'),
            ),
            OutlinedButton(
              key: const ValueKey('depth-simulate-gap'),
              onPressed: state.isSynchronized ? _simulateGap : null,
              child: const Text('模拟丢包'),
            ),
            FilledButton(
              key: const ValueKey('depth-recover-snapshot'),
              onPressed: state.requiresSnapshot && _recoverySnapshotId != null
                  ? _recoverSnapshot
                  : null,
              child: const Text('重新同步'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _status,
          key: const ValueKey('v2-depth-sync-status'),
          style: TextStyle(
            color: state.isSynchronized
                ? const Color(0xff0369a1)
                : const Color(0xffbe123c),
            fontSize: 12,
            fontWeight: FontWeight.w600,
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
                theme: widget.theme,
                layout: layout,
                version: state.version.value + widget.version,
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
