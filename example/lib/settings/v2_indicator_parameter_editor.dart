import 'package:flutter/material.dart';

/// 示例指标的数值参数表单；算法校验与重算由调用方负责。
///
/// 只接收展示数据和回调，不依赖 Demo 的指标对象或图表状态。
class V2IndicatorParameterEditor extends StatelessWidget {
  const V2IndicatorParameterEditor({
    super.key,
    required this.indicatorId,
    required this.label,
    required this.values,
    required this.summary,
    required this.onSubmitted,
    required this.onReset,
  });

  final String indicatorId;
  final String label;
  final Map<String, num> values;
  final String summary;
  final void Function(String key, String value) onSubmitted;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => Card(
        key: ValueKey('indicator-parameters-toggle-$indicatorId'),
        margin: EdgeInsets.zero,
        elevation: 0,
        color: const Color(0xfff8fafc),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xffe2e8f0)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xff0f172a),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                summary,
                style: const TextStyle(color: Color(0xff64748b), fontSize: 11),
              ),
              const SizedBox(height: 8),
              if (values.isEmpty)
                const Text(
                  '该指标按全部可见 K 线计算，没有周期或常数可设置。',
                  style: TextStyle(color: Color(0xff64748b), fontSize: 12),
                )
              else ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in values.entries)
                      SizedBox(
                        width: 102,
                        // TextFormField 的 initialValue 只在首次挂载时生效。
                        // 参数重置或外部更新后仅重建对应输入框，保持测试及宿主查询 key 不变。
                        child: KeyedSubtree(
                          key: ValueKey(
                            'indicator-value-$indicatorId-${entry.key}-${entry.value}',
                          ),
                          child: TextFormField(
                            key: ValueKey(
                              'indicator-param-$indicatorId-${entry.key}',
                            ),
                            initialValue: formatV2IndicatorParameter(
                              entry.value,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (value) =>
                                onSubmitted(entry.key, value),
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: v2IndicatorParameterLabel(entry.key),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    key: ValueKey('indicator-param-reset-$indicatorId'),
                    onPressed: onReset,
                    icon: const Icon(Icons.restart_alt, size: 16),
                    label: const Text('恢复默认'),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
}

/// 整数周期不加小数尾缀，倍数等非整数常量保留输入精度。
String formatV2IndicatorParameter(num value) =>
    value.toDouble() == value.toDouble().roundToDouble()
        ? value.toInt().toString()
        : value.toString();

/// 旧 Demo 的参数键对应的中文字段名；未声明的新键原样显示。
String v2IndicatorParameterLabel(String key) => switch (key) {
      'period1' => '周期 1',
      'period2' => '周期 2',
      'period3' => '周期 3',
      'period' => '周期',
      'fastPeriod' => '快速周期',
      'slowPeriod' => '慢速周期',
      'signalPeriod' => '信号周期',
      'kPeriod' || 'kSmoothing' => 'K 平滑',
      'dPeriod' || 'dSmoothing' => 'D 平滑',
      'rsiPeriod' => 'RSI 周期',
      'stochPeriod' => '随机周期',
      'adxPeriod' => 'ADX 周期',
      'multiplier' => '倍数',
      'constant' => '常数',
      'afStart' => '起始加速',
      'afIncrement' => '加速步长',
      'afMax' => '最大加速',
      _ => key,
    };
