/// 内部候选 UI 文案。默认中文，可由完整 Widget 包装转发宿主本地化文本。
/// 尚未从正式入口导出，不在绘制层硬编码业务提示。
final class KChartLabels {
  const KChartLabels({
    this.time = '时间',
    this.open = '开',
    this.high = '高',
    this.low = '低',
    this.close = '收',
    this.change = '涨跌',
    this.changePercent = '涨跌幅',
    this.amplitude = '振幅',
    this.volume = '量',
    this.amount = '额',
    this.selectedValue = '命中值',
    this.chart = 'K 线图',
    this.noData = '暂无行情数据',
    this.latest = '最新',
    this.selected = '已选中',
    this.zoomHint = '上调或下调可缩放图表；浏览历史时可点击返回最新 K 线',
    this.zoomedIn = '图表已放大',
    this.zoomedOut = '图表已缩小',
  });

  const KChartLabels.zhCN() : this();

  final String time;
  final String open;
  final String high;
  final String low;
  final String close;
  final String change;
  final String changePercent;
  final String amplitude;
  final String volume;
  final String amount;
  final String selectedValue;

  /// 读屏文案；视觉布局仍由绘制层负责，不把无障碍提示画进图表。
  final String chart;
  final String noData;
  final String latest;
  final String selected;
  final String zoomHint;
  final String zoomedIn;
  final String zoomedOut;
}
