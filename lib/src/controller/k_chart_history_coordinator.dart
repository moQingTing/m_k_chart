part of 'k_chart_data_coordinator.dart';

/// 分页逻辑独立成文件便于阅读，但与数据协调器共享同一事务提交入口。
/// 不单独通知 UI，避免“数据已前插、分页还在 loading”的中间状态。
extension _HistoryCoordination on KChartDataCoordinator {
  bool get _canLoadHistory =>
      !_disposed &&
      _historyLoader != null &&
      _attachment.isAttached &&
      _value.viewport.width > 0 &&
      _value.data.data.isNotEmpty &&
      _value.history.phase != KChartHistoryPhase.exhausted;

  void _scheduleHistoryCheck() {
    if (!_canLoadHistory ||
        _historyCheckScheduled ||
        _activeHistory != null ||
        _value.history.phase != KChartHistoryPhase.idle) {
      return;
    }
    // 不在布局/通知栈中调用宿主 loader；多次状态提交合并为一次检查。
    _historyCheckScheduled = true;
    scheduleMicrotask(() {
      _historyCheckScheduled = false;
      if (!_canLoadHistory ||
          _activeHistory != null ||
          _value.history.phase != KChartHistoryPhase.idle) {
        return;
      }
      final viewport = _value.viewport;
      final distance =
          viewport.maxScrollOffsetItems - viewport.scrollOffsetItems;
      if (distance <= historyThresholdItems) unawaited(_startHistory());
    });
  }

  Future<void> _startHistory() {
    final active = _activeHistory;
    if (active != null) return active.done.future;
    if (!_canLoadHistory) return Future<void>.value();
    final operation = _HistoryOperation(
      KChartHistoryRequest(
        session: session,
        requestId: ++_historyRequestSerial,
        beforeOpenTime: _value.data.data.first.openTime,
      ),
    );
    _activeHistory = operation;
    _commit(
      data: _value.data,
      viewport: _value.viewport,
      selection: _value.selection,
      history: KChartHistoryState.loading(operation.request),
    );
    // loading 的监听器可能换序列或销毁；此时不应再调用宿主 loader。
    if (_acceptsHistory(operation)) unawaited(_runHistory(operation));
    return operation.done.future;
  }

  bool _acceptsHistory(_HistoryOperation operation) =>
      !_disposed &&
      identical(_activeHistory, operation) &&
      _sessions.accepts(operation.request.session) &&
      _attachment.isAttached &&
      _value.data.data.firstOrNull?.openTime ==
          operation.request.beforeOpenTime;

  Future<void> _runHistory(_HistoryOperation operation) async {
    try {
      final page = await _historyLoader!(operation.request);
      if (!_acceptsHistory(operation)) return;
      if (page.candles.isEmpty && page.hasMore) {
        throw StateError(
          'History page made no progress while hasMore is true.',
        );
      }
      final incoming =
          _validateSeries(page.candles, operation.request.session.series);
      final store = KlineStore.stagedFromVerifiedSnapshot(_value.data);
      // Store 校验严格升序、唯一时间及前插边界；用当前快照合并，保留请求期间的实时更新。
      final next = store.prepend(incoming);
      _activeHistory = null;
      _finishData(
        next,
        dataChangeKnown: incoming.isNotEmpty,
        history: page.hasMore
            ? const KChartHistoryState.idle()
            : const KChartHistoryState.exhausted(),
      );
    } catch (error, stackTrace) {
      // 过期请求的成功/失败均静默丢弃，不能覆盖新请求的状态或向已离开的页面报错。
      if (!_acceptsHistory(operation)) return;
      _activeHistory = null;
      _commit(
        data: _value.data,
        viewport: _value.viewport,
        selection: _value.selection,
        history: KChartHistoryState.failed(
          request: operation.request,
          error: error,
          stackTrace: stackTrace,
        ),
      );
    } finally {
      operation.complete();
    }
  }

  void _invalidateHistory() {
    final operation = _activeHistory;
    _activeHistory = null;
    // 只结束逻辑等待，不声称取消 HTTP；旧任务仍接收其 Future 的成功/异常并丢弃。
    operation?.complete();
  }
}

final class _HistoryOperation {
  _HistoryOperation(this.request);

  final KChartHistoryRequest request;
  final Completer<void> done = Completer<void>();

  void complete() {
    if (!done.isCompleted) done.complete();
  }
}
