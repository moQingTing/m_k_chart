import 'package:flutter/material.dart';
import 'package:m_k_chart/m_k_chart.dart';

/// 新组件验收页的轻量设置面板。Controller 是唯一配置源；这里只缓存上次配置以过滤行情通知。
final class V2SdkChartSettings extends StatefulWidget {
  const V2SdkChartSettings({
    required this.controller,
    required this.onOptionsChanged,
    super.key,
  });

  final KChartController controller;
  final VoidCallback onOptionsChanged;

  @override
  State<V2SdkChartSettings> createState() => _V2SdkChartSettingsState();
}

final class _V2SdkChartSettingsState extends State<V2SdkChartSettings> {
  late KChartOptions _options;

  @override
  void initState() {
    super.initState();
    _options = widget.controller.value.options;
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(V2SdkChartSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_onControllerChanged);
      _options = widget.controller.value.options;
      widget.controller.addListener(_onControllerChanged);
    }
  }

  void _onControllerChanged() {
    final next = widget.controller.value.options;
    if (next != _options) setState(() => _options = next);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final options = _options;
    return SafeArea(
      top: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Text('图表设置',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  tooltip: '关闭设置',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
              child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('主图样式'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final mode in ChartMainMode.values)
                      ChoiceChip(
                        key: ValueKey('sdk-mode-${mode.name}'),
                        label: Text(_modeLabel(mode)),
                        selected: options.mainMode == mode,
                        onSelected: (_) => _update(
                          options.copyWith(mainMode: mode),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('主图指标（可多选）'),
                const SizedBox(height: 8),
                _indicatorChoices(options, main: true),
                _parameterEditors(options, main: true),
                if (options.mainMode == ChartMainMode.line ||
                    options.mainMode == ChartMainMode.area)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('主图指标在折线和面积模式下暂不绘制，切回蜡烛图后恢复。'),
                  ),
                const SizedBox(height: 16),
                const Text('副图指标（每项独立面板）'),
                const SizedBox(height: 8),
                _indicatorChoices(options, main: false),
                _parameterEditors(options, main: false),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _indicatorChoices(KChartOptions options, {required bool main}) => Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final preset in _IndicatorPreset.values.where(
            (preset) => preset.main == main,
          ))
            FilterChip(
              key: ValueKey('sdk-indicator-${preset.name}'),
              label: Text(preset.label),
              selected: options.indicators.any(
                (binding) => binding.config.instanceId == preset.instanceId,
              ),
              onSelected: (enabled) => _toggleIndicator(
                options,
                preset,
                enabled: enabled,
              ),
            ),
          for (final entry in widget.controller.indicatorCatalog.where(
            (entry) =>
                (entry.placement == IndicatorPlacement.mainChart) == main &&
                !_IndicatorPreset.values.any(
                  (preset) => preset.definitionId == entry.definitionId,
                ),
          ))
            FilterChip(
              key: ValueKey('sdk-indicator-custom-${entry.definitionId}'),
              label: Text(entry.displayName),
              selected: options.indicators.any(
                (binding) =>
                    binding.config.instanceId == 'custom:${entry.definitionId}',
              ),
              onSelected: (enabled) => _toggleBinding(
                options,
                instanceId: 'custom:${entry.definitionId}',
                definitionId: entry.definitionId,
                panelId: entry.placement == IndicatorPlacement.mainChart
                    ? 'main'
                    : 'secondary-custom-${entry.definitionId}',
                main: entry.placement == IndicatorPlacement.mainChart,
                enabled: enabled,
              ),
            ),
        ],
      );

  String _labelFor(String definitionId) {
    for (final preset in _IndicatorPreset.values) {
      if (preset.definitionId == definitionId) return preset.label;
    }
    for (final entry in widget.controller.indicatorCatalog) {
      if (entry.definitionId == definitionId) return entry.displayName;
    }
    return definitionId;
  }

  Widget _parameterEditors(KChartOptions options, {required bool main}) =>
      Column(
        children: [
          for (final binding in options.indicators.where(
            (binding) =>
                (binding.panelId == 'main') == main &&
                (_editableParameters(binding.config.definitionId).isNotEmpty ||
                    _seriesFor(binding.config.definitionId).length > 1),
          ))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('${_labelFor(binding.config.definitionId)} 参数'),
              subtitle: Text(
                [
                  if (_editableParameters(binding.config.definitionId)
                      .isNotEmpty)
                    _parameterSummary(binding.config),
                  if (_seriesFor(binding.config.definitionId).length > 1)
                    '显示 ${binding.visibleSeriesIds?.length ?? _seriesFor(binding.config.definitionId).length} 条曲线',
                ].join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_editableParameters(binding.config.definitionId)
                      .isNotEmpty)
                    TextButton(
                      key: ValueKey('sdk-edit-${binding.config.instanceId}'),
                      onPressed: () => _editParameters(binding),
                      child: const Text('参数'),
                    ),
                  if (_seriesFor(binding.config.definitionId).length > 1)
                    TextButton(
                      key: ValueKey('sdk-series-${binding.config.instanceId}'),
                      onPressed: () => _editVisibleSeries(binding),
                      child: const Text('曲线'),
                    ),
                ],
              ),
            ),
        ],
      );

  List<IndicatorParameterSpec> _editableParameters(String definitionId) =>
      widget.controller
          .indicatorParametersFor(definitionId)
          .where((spec) => spec.visibleInSettings)
          .toList(growable: false);

  List<IndicatorSeriesDescriptor> _seriesFor(String definitionId) {
    for (final entry in widget.controller.indicatorCatalog) {
      if (entry.definitionId == definitionId) return entry.series;
    }
    return const [];
  }

  Future<void> _editVisibleSeries(KChartIndicatorBinding binding) async {
    final series = _seriesFor(binding.config.definitionId);
    if (series.length < 2) return;
    final selected = <String>{
      ...?binding.visibleSeriesIds,
      if (binding.visibleSeriesIds == null) ...series.map((item) => item.id),
    };
    final values = await showDialog<Set<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, rebuild) => AlertDialog(
          title: Text('${_labelFor(binding.config.definitionId)} 曲线'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final item in series)
                CheckboxListTile(
                  key: ValueKey('sdk-series-option-${item.id}'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.label),
                  value: selected.contains(item.id),
                  onChanged: (enabled) => rebuild(() {
                    if (enabled == true) {
                      selected.add(item.id);
                    } else if (selected.length > 1) {
                      selected.remove(item.id);
                    }
                  }),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              key: const ValueKey('sdk-series-save'),
              onPressed: () => Navigator.pop(context, selected),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || values == null) return;
    final current = widget.controller.value.options;
    if (!current.indicators.any((item) =>
        item.config.instanceId == binding.config.instanceId &&
        item.config.definitionId == binding.config.definitionId)) {
      return;
    }
    _update(current.copyWith(indicators: [
      for (final item in current.indicators)
        if (item.config.instanceId == binding.config.instanceId &&
            item.config.definitionId == binding.config.definitionId)
          item.copyWith(
            visibleSeriesIds: values,
            resetVisibleSeriesIds: values.length == series.length,
          )
        else
          item,
    ]));
  }

  String _parameterSummary(IndicatorConfig config) => _editableParameters(
          config.definitionId)
      .map((spec) =>
          '${spec.label} ${config.parameter(spec.key) ?? spec.defaultValue}')
      .join(' · ');

  Future<void> _editParameters(KChartIndicatorBinding binding) async {
    final specs = _editableParameters(binding.config.definitionId);
    if (specs.isEmpty) return;
    final values = await showDialog<Map<String, num>>(
      context: context,
      builder: (context) => _IndicatorParameterDialog(
        title: '${_labelFor(binding.config.definitionId)} 参数',
        config: binding.config,
        specs: specs,
      ),
    );
    if (!mounted || values == null) return;
    // 对话框打开期间宿主可能修改了配置，以最新 options 为准，避免覆盖其他指标。
    final current = widget.controller.value.options;
    if (!current.indicators.any(
      (item) =>
          item.config.instanceId == binding.config.instanceId &&
          item.config.definitionId == binding.config.definitionId,
    )) {
      return;
    }
    final updated = [
      for (final item in current.indicators)
        if (item.config.instanceId == binding.config.instanceId &&
            item.config.definitionId == binding.config.definitionId)
          item.copyWith(
            config: IndicatorConfig(
              instanceId: item.config.instanceId,
              definitionId: item.config.definitionId,
              parameters: {...item.config.parameters, ...values},
              seriesStyleKeys: item.config.seriesStyleKeys,
            ),
          )
        else
          item,
    ];
    _update(current.copyWith(indicators: updated));
  }

  void _toggleIndicator(
    KChartOptions options,
    _IndicatorPreset preset, {
    required bool enabled,
  }) =>
      _toggleBinding(
        options,
        instanceId: preset.instanceId,
        definitionId: preset.definitionId,
        panelId: preset.panelId,
        main: preset.main,
        enabled: enabled,
        parameters: preset == _IndicatorPreset.ema
            ? const {'period1': 7, 'period2': 25, 'period3': 99}
            : const {},
      );

  void _toggleBinding(
    KChartOptions options, {
    required String instanceId,
    required String definitionId,
    required String panelId,
    required bool main,
    required bool enabled,
    Map<String, num> parameters = const {},
  }) {
    final indicators = options.indicators
        .where((binding) => binding.config.instanceId != instanceId)
        .toList();
    final panels =
        options.secondaryPanels.where((panel) => panel.id != panelId).toList();
    if (enabled) {
      if (!main) {
        panels.add(KChartSecondaryPanelOptions(
          id: panelId,
          layout: KChartPanelOptions(minHeight: 90, weight: 1),
        ));
      }
      indicators.add(KChartIndicatorBinding(
        panelId: panelId,
        config: IndicatorConfig(
          instanceId: instanceId,
          definitionId: definitionId,
          parameters: parameters,
        ),
      ));
    }
    _update(options.copyWith(
      secondaryPanels: panels,
      indicators: indicators,
    ));
  }

  void _update(KChartOptions options) {
    widget.controller.setOptions(options);
    widget.onOptionsChanged(); // 只让验收页重算所需高度，图表状态由 Controller 通知。
  }
}

/// 表单只编辑定义声明的参数；提交时用计算层同一份约束校验。
final class _IndicatorParameterDialog extends StatefulWidget {
  const _IndicatorParameterDialog({
    required this.title,
    required this.config,
    required this.specs,
  });

  final String title;
  final IndicatorConfig config;
  final List<IndicatorParameterSpec> specs;

  @override
  State<_IndicatorParameterDialog> createState() =>
      _IndicatorParameterDialogState();
}

final class _IndicatorParameterDialogState
    extends State<_IndicatorParameterDialog> {
  final _formKey = GlobalKey<FormState>();
  late final List<TextEditingController> _fields;
  String? _groupError;

  @override
  void initState() {
    super.initState();
    _fields = [
      for (final spec in widget.specs)
        TextEditingController(
          text: '${widget.config.parameter(spec.key) ?? spec.defaultValue}',
        ),
    ];
  }

  @override
  void dispose() {
    for (final field in _fields) {
      field.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final values = <String, num>{};
    for (var index = 0; index < widget.specs.length; index++) {
      values[widget.specs[index].key] =
          widget.specs[index].parse(_fields[index].text);
    }
    try {
      IndicatorParameterSpec.validateSet(
        widget.specs,
        IndicatorConfig(
          instanceId: widget.config.instanceId,
          definitionId: widget.config.definitionId,
          parameters: {...widget.config.parameters, ...values},
        ),
      );
    } on ArgumentError catch (error) {
      setState(() => _groupError = error.message?.toString());
      return;
    }
    Navigator.of(context).pop(values);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: SizedBox(
          width: 300,
          child: Form(
            key: _formKey,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.specs.length + (_groupError == null ? 0 : 1),
              itemBuilder: (context, index) {
                if (index == widget.specs.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _groupError!,
                      key: const ValueKey('sdk-param-group-error'),
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  );
                }
                final spec = widget.specs[index];
                return TextFormField(
                  key: ValueKey('sdk-param-${spec.key}'),
                  controller: _fields[index],
                  decoration: InputDecoration(labelText: spec.label),
                  onChanged: (_) {
                    if (_groupError != null) setState(() => _groupError = null);
                  },
                  keyboardType: TextInputType.numberWithOptions(
                    decimal: spec.kind == IndicatorParameterKind.positiveNumber,
                  ),
                  validator: (text) {
                    try {
                      spec.parse(text ?? '');
                      return null;
                    } on FormatException {
                      return spec.validationMessage;
                    } on ArgumentError {
                      return spec.validationMessage;
                    }
                  },
                );
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const ValueKey('sdk-param-save'),
            onPressed: _submit,
            child: const Text('保存'),
          ),
        ],
      );
}

enum _IndicatorPreset {
  ma('MA', 'legacy.ma', true),
  ema('EMA', 'legacy.ema', true),
  boll('BOLL', 'legacy.boll', true),
  sar('SAR', 'legacy.sar', true),
  avl('AVL', 'builtin.avl', true),
  superTrend('SUPER', 'builtin.super', true),
  vwap('VWAP', 'builtin.vwap', true),
  vol('VOL', 'legacy.vol', false),
  macd('MACD', 'legacy.macd', false),
  rsi('RSI', 'legacy.rsi', false),
  kdj('KDJ', 'legacy.kdj', false),
  wr('WR', 'legacy.wr', false),
  obv('OBV', 'legacy.obv', false),
  atr('ATR', 'builtin.atr', false),
  cci('CCI', 'builtin.cci', false),
  dmi('DMI', 'builtin.dmi', false),
  roc('ROC', 'builtin.roc', false),
  stochRsi('STOCH RSI', 'builtin.stochRsi', false);

  const _IndicatorPreset(this.label, this.definitionId, this.main);

  final String label;
  final String definitionId;
  final bool main;

  String get instanceId => this == _IndicatorPreset.superTrend ? 'super' : name;
  String get panelId => main ? 'main' : 'secondary-$name';
}

String _modeLabel(ChartMainMode mode) => switch (mode) {
      ChartMainMode.candlestick => '蜡烛',
      ChartMainMode.hollowCandlestick => '空心蜡烛',
      ChartMainMode.ohlc => 'OHLC',
      ChartMainMode.heikinAshi => '平均K线',
      ChartMainMode.line => '折线',
      ChartMainMode.area => '面积',
    };
