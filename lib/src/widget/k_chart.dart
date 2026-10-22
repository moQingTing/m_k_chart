import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../k_chart_theme.dart';
import '../drawing/chart_drawing.dart';
import '../controller/k_chart_data_coordinator.dart';
import '../controller/k_chart_facade.dart';
import 'k_chart_labels.dart';
import 'k_chart_overlays.dart';
import 'k_chart_surface.dart';

/// OPT-04 的仓库内 Widget 候选包装；正式公共导出仍须经过 OPT-12 准入。
///
/// 宿主拥有 [controller] 并负责销毁。此组件只管理显示时钟、前后台暂停和业务回调；
/// 行情请求、交易操作和数据持久化继续由宿主管理。
final class KChart extends StatefulWidget {
  const KChart({
    required this.controller,
    this.theme,
    this.labels = const KChartLabels.zhCN(),
    this.interactionEnabled = true,
    this.emptyBuilder,
    this.selectionBuilder,
    this.onDrawingAnchor,
    this.onDrawingHover,
    this.drawingPreview,
    this.drawingEditingEnabled = false,
    this.drawingSnapToOhlc = false,
    this.selectedDrawingId,
    this.onDrawingSelectionChanged,
    this.onDrawingEditCommitted,
    this.onSelectionChanged,
    this.onIssue,
    this.currentTimeMilliseconds,
    super.key,
  });

  final KChartController controller;
  final KChartTheme? theme;
  final KChartLabels labels;
  final bool interactionEnabled;
  final WidgetBuilder? emptyBuilder;
  final KChartSelectionBuilder? selectionBuilder;

  /// 非空时进入主图绘图落点模式：点按返回时间/价格锚点，不触发选中或平移。
  /// 草稿、工具类型和持久化由宿主负责；传回 null 即恢复浏览模式。
  final ValueChanged<ChartDrawingAnchor>? onDrawingAnchor;

  /// 绘图模式下指针移入/移动主图时发送临时锚点；移出或进入非主图时为 null。
  final ValueChanged<ChartDrawingAnchor?>? onDrawingHover;

  /// 仅供预览的绘图对象，不会写入 Controller 覆盖物集合。
  final ChartDrawing? drawingPreview;

  /// 启用后点选绘图并可拖动控制点；绘图模式不参与图表平移或 K 线选中。
  final bool drawingEditingEnabled;

  /// 启用后，拖动控制点或图形本体时将时间/价格吸附到最近 K 线的 OHLC。
  final bool drawingSnapToOhlc;
  final String? selectedDrawingId;
  final ValueChanged<String?>? onDrawingSelectionChanged;

  /// 完成一次锚点或图形本体拖动时回调原始与最终绘图快照；一次手势只回调一次。
  final void Function(List<ChartDrawing> before, List<ChartDrawing> after)?
      onDrawingEditCommitted;
  final ValueChanged<KChartSelection?>? onSelectionChanged;
  final ValueChanged<KChartIssue>? onIssue;

  /// 可注入服务端同步时钟；不提供时使用设备时间。仅影响倒计时，不改 K 线时间戳。
  final int Function()? currentTimeMilliseconds;

  @override
  State<KChart> createState() => _KChartState();
}

final class _KChartState extends State<KChart> with WidgetsBindingObserver {
  static final KChartTheme _defaultTheme = KChartTheme.light();

  Timer? _clock;
  // 倒计时只通知下方显示树；每秒不重建负责生命周期和业务回调的外层 KChart。
  late final ValueNotifier<int> _clockTime;
  bool _foreground = true;
  bool _tickerEnabled = true;
  bool _callbacksQueued = false;
  bool _forceSelectionCallback = false;
  bool _forceIssueCallbacks = false;
  KChartSelection? _lastSelection;
  Map<(KChartIssueKind, String?), KChartIssue> _lastIssues = {};

  int _readTime() =>
      widget.currentTimeMilliseconds?.call() ??
      DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    // 路由可能在应用已处于后台时才挂载；此时不会再收到一次 paused 事件，
    // 因此必须从 Binding 的当前状态初始化，而不是默认认为可见。
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _clockTime = ValueNotifier<int>(_readTime());
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_onControllerChanged);
    _syncClock();
    _scheduleCallbacks(); // 挂载已有选中/错误的控制器时交付当前快照。
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final enabled = TickerMode.valuesOf(context).enabled;
    if (_tickerEnabled != enabled) {
      _tickerEnabled = enabled;
      if (enabled) _clockTime.value = _readTime();
      _syncClock();
    }
  }

  @override
  void didUpdateWidget(KChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _clockTime.value = _readTime();
      _forceSelectionCallback = true;
      _forceIssueCallbacks = true;
      _syncClock();
      _scheduleCallbacks();
    }
    if (oldWidget.currentTimeMilliseconds != widget.currentTimeMilliseconds) {
      _clockTime.value = _readTime();
    }
  }

  void _onControllerChanged() {
    _syncClock();
    _scheduleCallbacks();
  }

  void _syncClock() {
    final active = _foreground &&
        _tickerEnabled &&
        !widget.controller.isDisposed &&
        widget.controller.value.data.isNotEmpty;
    if (!active) {
      _clock?.cancel();
      _clock = null;
      return;
    }
    _clock ??= Timer.periodic(const Duration(seconds: 1), (_) {
      final now = _readTime();
      if (mounted && now != _clockTime.value) {
        _clockTime.value = now;
      }
    });
  }

  void _scheduleCallbacks() {
    if (_callbacksQueued) return;
    // 控制器的视口/布局通知不一定改变业务回调。未变化时不排队帧后任务；
    // 错误消失也算变化，必须更新基线，保证同一错误再次出现仍可交付。
    if (!_forceSelectionCallback && !_forceIssueCallbacks) {
      final snapshot = widget.controller.value;
      if (_sameSelection(_lastSelection, snapshot.selection) &&
          _sameIssues(_lastIssues, snapshot.issues)) {
        return;
      }
    }
    _callbacksQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _callbacksQueued = false;
      if (!mounted || widget.controller.isDisposed) return;
      final snapshot = widget.controller.value;
      final selection = snapshot.selection;
      final changed =
          _forceSelectionCallback || !_sameSelection(_lastSelection, selection);
      _lastSelection = selection;
      _forceSelectionCallback = false;

      final previousIssues = _lastIssues;
      _lastIssues = {
        for (final issue in snapshot.issues)
          (issue.kind, issue.instanceId): issue,
      };
      final forceIssues = _forceIssueCallbacks;
      _forceIssueCallbacks = false;

      // 回调只在帧后执行；业务监听器可以安全导航、更新控制器或关闭此 Widget。
      final controller = widget.controller;
      if (changed) widget.onSelectionChanged?.call(selection);
      if (!mounted ||
          !identical(controller, widget.controller) ||
          controller.value.revision != snapshot.revision) {
        return;
      }
      for (final issue in snapshot.issues) {
        if (!mounted ||
            !identical(controller, widget.controller) ||
            controller.value.revision != snapshot.revision) {
          return;
        }
        final previous = previousIssues[(issue.kind, issue.instanceId)];
        if (forceIssues ||
            previous == null ||
            !identical(previous.error, issue.error) ||
            !identical(previous.stackTrace, issue.stackTrace)) {
          widget.onIssue?.call(issue);
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _clockTime.value = _readTime();
    }
    _syncClock();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: _clockTime,
        builder: (context, currentTime, _) => KChartSurface(
          controller: widget.controller,
          style: widget.theme ?? _defaultTheme,
          currentTime: currentTime,
          interactionEnabled: widget.interactionEnabled,
          emptyBuilder: widget.emptyBuilder,
          labels: widget.labels,
          selectionBuilder: widget.selectionBuilder,
          onDrawingAnchor: widget.onDrawingAnchor,
          onDrawingHover: widget.onDrawingHover,
          drawingPreview: widget.drawingPreview,
          drawingEditingEnabled: widget.drawingEditingEnabled,
          drawingSnapToOhlc: widget.drawingSnapToOhlc,
          selectedDrawingId: widget.selectedDrawingId,
          onDrawingSelectionChanged: widget.onDrawingSelectionChanged,
          onDrawingEditCommitted: widget.onDrawingEditCommitted,
        ),
      );

  @override
  void dispose() {
    _clock?.cancel();
    _clockTime.dispose();
    widget.controller.removeListener(_onControllerChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

bool _sameSelection(KChartSelection? first, KChartSelection? second) =>
    identical(first, second) ||
    (first != null &&
        second != null &&
        first.candle == second.candle &&
        first.previousCandle == second.previousCandle &&
        first.panelId == second.panelId &&
        first.value == second.value);

bool _sameIssues(
  Map<(KChartIssueKind, String?), KChartIssue> previous,
  List<KChartIssue> current,
) {
  if (previous.length != current.length) return false;
  for (final issue in current) {
    final old = previous[(issue.kind, issue.instanceId)];
    if (old == null ||
        !identical(old.error, issue.error) ||
        !identical(old.stackTrace, issue.stackTrace)) {
      return false;
    }
  }
  return true;
}
