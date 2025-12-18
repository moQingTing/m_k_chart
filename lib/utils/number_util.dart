class NumberUtil {
  static String volFormat(double n) {
    if (n > 10000 && n < 999999) {
      double d = n / 1000;
      return '${d.toStringAsFixed(2)}K';
    } else if (n > 1000000) {
      double d = n / 1000000;
      return '${d.toStringAsFixed(2)}M';
    }
    return n.toStringAsFixed(2);
  }

  //保留多少位小数
  static int _fractionDigits = 2;

  static set fractionDigits(int value) {
    if (value != _fractionDigits) _fractionDigits = value;
  }

  static String format(double price) {
    return formatNum(price,_fractionDigits);
  }

  ///取小数点后几位
// @param num 数值
// @param location 几位
  static String formatNum(double num, int location) {
    if ((num.toString().length - num.toString().lastIndexOf('.') - 1) <
        location) {
      //小数点后有几位小数
      return num.toStringAsFixed(location)
          .substring(0, num.toString().lastIndexOf('.') + location + 1)
          .toString();
    } else {
      return num.toString()
          .substring(0, num.toString().lastIndexOf('.') + location + 1)
          .toString();
    }
  }

}
