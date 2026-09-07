enum ChartMainMode {
  candlestick,
  hollowCandlestick,
  ohlc,
  heikinAshi,
  line,
  area,
}

extension ChartMainModeSemantics on ChartMainMode {
  bool get isCandleMode => switch (this) {
        ChartMainMode.candlestick ||
        ChartMainMode.hollowCandlestick ||
        ChartMainMode.ohlc ||
        ChartMainMode.heikinAshi =>
          true,
        ChartMainMode.line || ChartMainMode.area => false,
      };

  bool get usesHeikinAshi => this == ChartMainMode.heikinAshi;

  bool get showsMainIndicators => isCandleMode;
}
