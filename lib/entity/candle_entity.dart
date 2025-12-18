
mixin CandleEntity{

 late double open;
 late double high;
 late double low;
 late double close;
 late double MA5Price;
 late double MA10Price;
 late double MA20Price;
 late double MA30Price;
 late double MA60Price;
//  上轨线
 late double up;
//  中轨线
 late double mb;
//  下轨线
 late double dn;
// EMA值存储，key为周期（如5, 10, 30），value为对应的EMA值
 late Map<int, double> emaValues;
// SAR (Parabolic SAR) 抛物线转向指标
 late double sar;
// SAR趋势方向：true表示上升趋势，false表示下降趋势
 late bool sarTrend;
// SAR加速因子
 late double sarAF;
// SAR极值点（EP）
 late double sarEP;
}