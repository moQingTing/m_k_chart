/// 旧 Demo 的请求代际守卫；只管理请求身份，不负责发起或取消网络请求。
///
/// 新的完整窗口加载会切换代际。旧代际的刷新即使仍在等待网络，也不能阻塞新代际
/// 的轮询；路由隐藏时暂停刷新，旧响应到达后由调用方丢弃。
final class V2DemoRefreshGate {
  int _generation = 0;
  int _visibilityGeneration = 0;
  bool _refreshPaused = false;
  V2DemoRefreshTicket? _activeRefresh;

  /// 开始新窗口加载，同时使此前所有完整加载及实时刷新结果过期。
  int beginLoad() => ++_generation;

  /// 页面离开时废弃在途的完整窗口加载；不会取消实际网络请求。
  void invalidateLoad() => _generation++;

  /// 同一加载与可见代际最多允许一个实时刷新。
  V2DemoRefreshTicket? beginRefresh() {
    if (_refreshPaused) return null;
    final active = _activeRefresh;
    if (active != null &&
        active.loadGeneration == _generation &&
        active.visibilityGeneration == _visibilityGeneration) {
      return null;
    }
    final ticket = V2DemoRefreshTicket._(
      loadGeneration: _generation,
      visibilityGeneration: _visibilityGeneration,
    );
    _activeRefresh = ticket;
    return ticket;
  }

  /// 完整窗口加载只按数据代际判断；暂停轮询不改变已有加载结果的契约。
  bool isCurrent(int generation) => generation == _generation;

  /// 仅当前可见页面发起且尚未被替代的刷新可提交结果。
  bool isCurrentRefresh(V2DemoRefreshTicket ticket) =>
      !_refreshPaused &&
      identical(_activeRefresh, ticket) &&
      ticket.loadGeneration == _generation &&
      ticket.visibilityGeneration == _visibilityGeneration;

  /// 离开页面时使在途刷新失效，并允许恢复后立即启动新刷新。
  void pauseRefresh() {
    _refreshPaused = true;
    _visibilityGeneration++;
    _activeRefresh = null;
  }

  void resumeRefresh() => _refreshPaused = false;

  /// 旧请求完成不能释放新代际或恢复后新请求的占位。
  void finishRefresh(V2DemoRefreshTicket ticket) {
    if (identical(_activeRefresh, ticket)) {
      _activeRefresh = null;
    }
  }
}

/// 一次实时刷新所属的数据与页面可见代际；由守卫创建并验证身份。
final class V2DemoRefreshTicket {
  const V2DemoRefreshTicket._({
    required this.loadGeneration,
    required this.visibilityGeneration,
  });

  final int loadGeneration;
  final int visibilityGeneration;
}
