import '../model/kline_series.dart';

/// 一次行情加载会话的不可伪造令牌，未来由正式 Controller 发放。
///
/// 开始 HTTP 请求或订阅消息流时捕获此对象，完成时原样交回；不要在回调执行时读取
/// 新的 session，否则会把旧请求错误地当成新请求。generation 仅用于诊断，不能用数字
/// 或 series 相等代替令牌身份检查。此类型当前仍未从正式入口导出。
final class KChartDataSession {
  const KChartDataSession._(this.series, this.generation);

  final KlineSeries series;
  final int generation;
}

/// Controller 实现使用的内部令牌管理器，不属于计划公开的 SDK 类型。
///
/// 数据校验必须先完成，再调用 [begin] 提交新会话。此对象不持有 Store、不发送通知，
/// 也不实际取消网络请求；OPT-03 将它接入统一数据事务。
final class KChartSessionGate {
  KChartSessionGate(KlineSeries series)
      : _current = KChartDataSession._(series, 0);

  KChartDataSession _current;
  bool _disposed = false;

  KChartDataSession get current => _current;

  bool accepts(KChartDataSession session) =>
      !_disposed && identical(session, _current);

  /// 即使 A → B → A 或刷新同一序列，也会生成全新的令牌。
  KChartDataSession begin(KlineSeries series) {
    if (_disposed) throw StateError('Session gate has been disposed.');
    return _current = KChartDataSession._(series, _current.generation + 1);
  }

  /// 销毁后在途结果自然失效；重复销毁安全，最后的只读令牌仍可用于诊断。
  void dispose() => _disposed = true;
}

/// 内部 Widget 挂载所有权检查。不公开 State、BuildContext 或可变渲染资源。
///
/// 一个 Controller 只能同时服务一张图。Widget 更新/卸载时只释放自己的租约，不能因
/// 旧 Widget 的迟到清理而误解绑新 Widget。该守卫的接线由 OPT-03/04 完成。
final class KChartAttachmentGuard {
  Object? _owner;
  bool _disposed = false;

  bool get isAttached => _owner != null;

  void attach(Object owner) {
    if (_disposed) throw StateError('Attachment guard has been disposed.');
    if (_owner != null && !identical(_owner, owner)) {
      throw StateError('A controller can only attach to one chart at a time.');
    }
    _owner = owner;
  }

  void detach(Object owner) {
    if (identical(_owner, owner)) _owner = null;
  }

  void dispose() {
    _disposed = true;
    _owner = null;
  }
}
