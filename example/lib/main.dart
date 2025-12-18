import 'dart:async';
import 'package:flutter/material.dart';
import 'package:m_k_chart/m_k_chart.dart';
import 'chart_datas_fetcher.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'm_k_chart Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const ExamplePage(),
    );
  }
}

class ExamplePage extends StatefulWidget {
  const ExamplePage({super.key});

  @override
  State<ExamplePage> createState() => _ExamplePageState();
}

class _ExamplePageState extends State<ExamplePage> {
  // K 线数据
  List<KLineEntity> _klineData = [];
  
  // 加载状态
  bool _isLoading = true;
  String? _errorMessage;

  // 定时器
  Timer? _timer;

  // 当前选择的市场
  String _currentSymbol = 'BTC';

  // 支持的市场列表
  final List<String> _symbols = ['BTC', 'ETH', 'LTC', 'DOGE', 'UNI', 'XRP'];

  // 市场全称映射
  final Map<String, String> _symbolNames = {
    'BTC': 'Bitcoin',
    'ETH': 'Ethereum',
    'LTC': 'Litecoin',
    'DOGE': 'Dogecoin',
    'UNI': 'Uniswap',
    'XRP': 'Ripple',
  };

  // 当前选择的时间周期
  String _currentTimeType = '1m';

  // 支持的时间周期列表
  final List<String> _timeTypes = ['1m', '5m', '15m', '1H', '4H', '1D'];

  // 当前选择的主图指标
  MainState _currentMainState = MainState.ma;

  // 支持的主图指标列表
  final List<MainState> _mainStates = [
    MainState.none,
    MainState.ma,
    MainState.boll,
    MainState.ema,
    MainState.sar,
  ];

  // 主图指标名称映射
  final Map<MainState, String> _mainStateNames = {
    MainState.none: '无',
    MainState.ma: 'MA',
    MainState.boll: 'BOLL',
    MainState.ema: 'EMA',
    MainState.sar: 'SAR',
  };

  // 当前选择的幅图指标（支持多选）
  final Set<SecondaryState> _selectedSecondaryStates = {SecondaryState.macd};

  // 支持的幅图指标列表（共6个）
  final List<SecondaryState> _secondaryStates = [
    SecondaryState.macd,
    SecondaryState.kdj,
    SecondaryState.rsi,
    SecondaryState.wr,
    SecondaryState.vol,
    SecondaryState.obv,
  ];

  // 幅图指标名称映射
  final Map<SecondaryState, String> _secondaryStateNames = {
    SecondaryState.macd: 'MACD',
    SecondaryState.kdj: 'KDJ',
    SecondaryState.rsi: 'RSI',
    SecondaryState.wr: 'WR',
    SecondaryState.vol: 'VOL',
    SecondaryState.obv: 'OBV',
  };

  @override
  void initState() {
    super.initState();
    // 页面加载时自动获取数据
    _fetchChartData();
    // 启动定时器，每10秒自动刷新数据
    _startTimer();
  }

  @override
  void dispose() {
    // 取消定时器，避免内存泄漏
    _timer?.cancel();
    super.dispose();
  }

  /// 启动定时器
  void _startTimer() {
    _timer?.cancel(); // 如果已有定时器，先取消
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      // 每10秒自动获取一次数据
      // showLoading: false 避免定时刷新时显示加载动画，保持界面流畅
      if (mounted) {
        _fetchChartData(showLoading: false);
      } else {
        // 如果组件已销毁，取消定时器
        timer.cancel();
      }
    });
  }

  /// 停止定时器
  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  /// 获取 K 线数据
  /// [showLoading] 是否显示加载状态，定时刷新时设为 false 避免闪烁
  Future<void> _fetchChartData({bool showLoading = true}) async {
    // 如果已经在加载中，避免重复请求
    if (_isLoading && showLoading) {
      return;
    }

    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    // 使用单例获取数据
    // symbol: 使用当前选择的市场，格式为 {SYMBOL}-USDT
    // timeType: 使用当前选择的时间周期
    // size: 100 (获取100条数据)
    final symbol = '$_currentSymbol-USDT';
    await ChartDatasFetcher.shared.getRemoteChartData(
      symbol,
      _currentTimeType,
      100,
      (success, data) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            if (success && data.isNotEmpty) {
              _klineData = data;
              _errorMessage = null;
            } else {
              _errorMessage = '获取数据失败，请检查网络连接';
              // 如果数据获取失败，不清空已有数据，保持显示
              // _klineData = [];
            }
          });
        }
      },
    );
  }

  /// 切换市场
  void _changeSymbol(String symbol) {
    if (_currentSymbol != symbol) {
      setState(() {
        _currentSymbol = symbol;
      });
      // 切换市场后重新获取数据
      _fetchChartData();
    }
  }

  /// 切换时间周期
  void _changeTimeType(String timeType) {
    if (_currentTimeType != timeType) {
      setState(() {
        _currentTimeType = timeType;
      });
      // 切换时间周期后重新获取数据
      _fetchChartData();
    }
  }

  /// 切换主图指标
  void _changeMainState(MainState mainState) {
    if (_currentMainState != mainState) {
      setState(() {
        _currentMainState = mainState;
      });
    }
  }

  /// 切换幅图指标（支持多选）
  void _toggleSecondaryState(SecondaryState secondaryState) {
    setState(() {
      if (_selectedSecondaryStates.contains(secondaryState)) {
        _selectedSecondaryStates.remove(secondaryState);
      } else {
        _selectedSecondaryStates.add(secondaryState);
      }
    });
  }

  /// 构建 K 线图表组件
  /// 确保数据不为空且足够时才渲染图表
  Widget _buildKChartWidget() {
    // 显示加载中状态
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
            ),
            const SizedBox(height: 20),
            Text(
              '正在加载 K 线数据...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    // 显示错误信息
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[300],
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.red[700],
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _fetchChartData,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('重试'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 严格检查：数据必须不为空且至少有 5 条数据
    if (_klineData.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.info_outline,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                '暂无 K 线数据',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _fetchChartData,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('重新加载'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_klineData.length < 5) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 48,
                color: Colors.orange[300],
              ),
              const SizedBox(height: 16),
              Text(
                '数据不足',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '需要至少 5 条数据才能显示指标\n当前: ${_klineData.length} 条',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // 确保数据有效
    final validData = _klineData.where((e) => 
      e.open > 0 && e.close > 0 && e.high > 0 && e.low > 0 &&
      e.high >= e.low &&
      !e.open.isNaN && !e.close.isNaN && !e.high.isNaN && !e.low.isNaN
    ).toList();

    if (validData.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red[300],
              ),
              const SizedBox(height: 16),
              Text(
                '数据无效，无法显示图表',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.red[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (validData.length < 5) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 48,
                color: Colors.orange[300],
              ),
              const SizedBox(height: 16),
              Text(
                '有效数据不足',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '需要至少 5 条有效数据\n当前: ${validData.length} 条',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // 定义图表样式和颜色
    final chartStyle = ChartStyle(
      priceFormatter: (price, defaultStyle) {
        return TextSpan(
          text: price.toStringAsFixed(2),
          style: defaultStyle,
        );
      },
      volumeFormatter: (volume, defaultStyle) {
        return TextSpan(
          text: volume.toStringAsFixed(0),
          style: defaultStyle,
        );
      },
      dateFormatter: (date) {
        // date 是时间戳（毫秒）也可能是秒
        // 如果 date 是秒，则转换为毫秒
        if (date.toString().length == 10) {
          date = date * 1000;
        }
        // 转为 yyyy-MM-dd HH:mm
        return _formatDate(DateTime.fromMillisecondsSinceEpoch(date), format: 'yyyy-MM-dd HH:mm');
      },
    )..obvPeriod = 30; // 设置 OBV 移动平均线周期为 30

    final chartColors = ChartColors(
      isDarkMode: false,
      upColor: Colors.green,
      downColor: Colors.red,
    );

    // 如果使用 MA，需要先计算 MA 值
    // DataUtil.calculate 会初始化 MA5Price、MA10Price 等字段
    if (validData.length >= 5) {
      try {
        // 使用 DataUtil.calculate 计算所有指标（MA、BOLL、MACD、SAR 等）
        // 这必须在传递给图表之前调用，否则 MA5Price 等字段不会被初始化
        // 传入 OBV 周期参数、EMA 配置和 ChartStyle（用于 SAR 计算）
        DataUtil.calculate(
          validData,
          obvPeriod: chartStyle.obvPeriod,
          emaConfigs: chartStyle.emaConfigs,
          chartStyle: chartStyle,
        );
      } catch (e) {
        print('⚠️ 计算指标失败: $e');
        // 如果计算失败，使用 none 模式避免访问未初始化的字段
        return KChartWidget(
          validData,
          mainState: MainState.none,
          secondaryStates: [],
          isLine: false,
          chartStyle: chartStyle,
          chartColors: chartColors,
        );
      }
    }

    // 使用有效数据渲染图表
    // 根据数据量决定是否使用指标（至少需要 5 条数据计算 MA5）
    final mainState = validData.length >= 5 ? _currentMainState : MainState.none;
    final secondaryStates = validData.length >= 12 
        ? _selectedSecondaryStates.toList()
        : <SecondaryState>[]; // MACD 等指标通常需要更多数据

    return KChartWidget(
      validData,
      mainState: mainState,
      secondaryStates: secondaryStates,
      isLine: false,
      chartStyle: chartStyle,
      chartColors: chartColors,
      infoWindowBuilder: _buildCustomInfoWindow,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.candlestick_chart, size: 24),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$_currentSymbol-USDT',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _symbolNames[_currentSymbol] ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ],
        ),
        elevation: 0,
        actions: [
          // 定时器开关按钮
          Tooltip(
            message: _timer?.isActive == true ? '暂停自动刷新' : '开始自动刷新',
            child: IconButton(
              icon: Icon(
                _timer?.isActive == true ? Icons.pause_circle_outline : Icons.play_circle_outline,
                size: 24,
              ),
              onPressed: () {
                if (_timer?.isActive == true) {
                  _stopTimer();
                } else {
                  _startTimer();
                }
                setState(() {}); // 更新图标状态
              },
            ),
          ),
          // 手动刷新按钮
          Tooltip(
            message: '手动刷新数据',
            child: IconButton(
              icon: const Icon(Icons.refresh, size: 24),
              onPressed: _isLoading ? null : () => _fetchChartData(showLoading: false),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 市场选择器
            Card(
              margin: const EdgeInsets.all(16),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.currency_exchange, size: 20, color: Theme.of(context).primaryColor),
                        const SizedBox(width: 8),
                        const Text(
                          '交易市场',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _symbols.map((symbol) {
                        return ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                symbol,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: _currentSymbol == symbol ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                              if (_currentSymbol == symbol) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.check_circle,
                                  size: 14,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ],
                            ],
                          ),
                          selected: _currentSymbol == symbol,
                          onSelected: (selected) {
                            if (selected) {
                              _changeSymbol(symbol);
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            // 时间周期选择器 - 使用卡片容器
            Card(
              margin: const EdgeInsets.all(16),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 20, color: Theme.of(context).primaryColor),
                        const SizedBox(width: 8),
                        const Text(
                          '时间周期',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _timeTypes.map((timeType) {
                        return ChoiceChip(
                          label: Text(
                            timeType,
                            style: const TextStyle(fontSize: 13),
                          ),
                          selected: _currentTimeType == timeType,
                          onSelected: (selected) {
                            if (selected) {
                              _changeTimeType(timeType);
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            // K 线图示例 - 使用卡片容器
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.show_chart, size: 20, color: Theme.of(context).primaryColor),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$_currentSymbol-USDT',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                    Text(
                                      _symbolNames[_currentSymbol] ?? '',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _currentTimeType,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRect(
                      clipBehavior: Clip.hardEdge,
                      child: SizedBox(
                        height: 400,
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 4,
                            right: 4,
                            top: 4,
                            bottom: 20, // 增加底部padding，确保时间文本有足够空间
                          ),
                          child: _buildKChartWidget(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 主图指标选择器 - 使用卡片容器
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.trending_up, size: 20, color: Theme.of(context).primaryColor),
                        const SizedBox(width: 8),
                        const Text(
                          '主图指标',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _mainStates.map((mainState) {
                        return ChoiceChip(
                          label: Text(
                            _mainStateNames[mainState] ?? '未知',
                            style: const TextStyle(fontSize: 13),
                          ),
                          selected: _currentMainState == mainState,
                          onSelected: (selected) {
                            if (selected) {
                              _changeMainState(mainState);
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            // 幅图指标选择器（多选）- 使用卡片容器
            Card(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.bar_chart, size: 20, color: Theme.of(context).primaryColor),
                        const SizedBox(width: 8),
                        const Text(
                          '幅图指标',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            '可多选',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _secondaryStates.map((secondaryState) {
                        final isSelected = _selectedSecondaryStates.contains(secondaryState);
                        return FilterChip(
                          label: Text(
                            _secondaryStateNames[secondaryState] ?? '未知',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            _toggleSecondaryState(secondaryState);
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }



   /// format date by DateTime.
  /// format 转换格式(已提供常用格式 DateFormats，可以自定义格式：'yyyy/MM/dd HH:mm:ss')
  /// 格式要求
  /// year -> yyyy/yy   month -> MM/M    day -> dd/d
  /// hour -> HH/H      minute -> mm/m   second -> ss/s
  String _formatDate(DateTime? dateTime, {String? format}) {
    if (dateTime == null) return '';
    format = format ?? 'yyyy-MM-dd HH:mm';
    if (format.contains('yy')) {
      final year = dateTime.year.toString();
      if (format.contains('yyyy')) {
        format = format.replaceAll('yyyy', year);
      } else {
        format = format.replaceAll(
            'yy', year.substring(year.length - 2, year.length));
      }
    }

    format = _comFormat(dateTime.month, format, 'M', 'MM');
    format = _comFormat(dateTime.day, format, 'd', 'dd');
    format = _comFormat(dateTime.hour, format, 'H', 'HH');
    format = _comFormat(dateTime.minute, format, 'm', 'mm');
    format = _comFormat(dateTime.second, format, 's', 'ss');
    format = _comFormat(dateTime.millisecond, format, 'S', 'SSS');

    return format;
  }

  /// com format.
  String _comFormat(
      int value, String format, String single, String full) {
    if (format.contains(single)) {
      if (format.contains(full)) {
        format =
            format.replaceAll(full, value < 10 ? '0$value' : value.toString());
      } else {
        format = format.replaceAll(single, value.toString());
      }
    }
    return format;
  }

  /// 自定义信息窗口构建器
  Widget _buildCustomInfoWindow(
    BuildContext context,
    InfoWindowEntity entity,
    ChartStyle chartStyle,
    ChartColors chartColors,
  ) {
    final kLineEntity = entity.kLineEntity;
    final upDown = kLineEntity.close - kLineEntity.open;
    final upDownPercent = upDown / kLineEntity.open * 100;
    final isUp = upDown >= 0;

    // 格式化时间
    final dateStr = DataUtil.getDate(kLineEntity.id, chartStyle.dateFormatter);

    // 格式化价格
    final openStr = chartStyle.priceFormatter != null
        ? chartStyle.priceFormatter!(kLineEntity.open, const TextStyle()).text ?? ''
        : kLineEntity.open.toStringAsFixed(2);
    final highStr = chartStyle.priceFormatter != null
        ? chartStyle.priceFormatter!(kLineEntity.high, const TextStyle()).text ?? ''
        : kLineEntity.high.toStringAsFixed(2);
    final lowStr = chartStyle.priceFormatter != null
        ? chartStyle.priceFormatter!(kLineEntity.low, const TextStyle()).text ?? ''
        : kLineEntity.low.toStringAsFixed(2);
    final closeStr = chartStyle.priceFormatter != null
        ? chartStyle.priceFormatter!(kLineEntity.close, const TextStyle()).text ?? ''
        : kLineEntity.close.toStringAsFixed(2);

    // 格式化成交量
    final volStr = chartStyle.volumeFormatter != null
        ? chartStyle.volumeFormatter!(kLineEntity.vol, const TextStyle()).text ?? ''
        : kLineEntity.vol.toStringAsFixed(0);

    return Align(
      alignment: entity.isLeft ? Alignment.topLeft : Alignment.topRight,
      child: Container(
        margin: const EdgeInsets.only(left: 10, right: 10, top: 25),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: Colors.grey.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 时间标题
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            // 价格信息
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 收盘价（突出显示）
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '收盘',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        closeStr,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isUp ? chartColors.upColor : chartColors.downColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 涨跌幅
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '涨跌',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            '${isUp ? '+' : ''}${upDownPercent.toStringAsFixed(2)}%',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isUp ? chartColors.upColor : chartColors.downColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isUp ? chartColors.upColor : chartColors.downColor).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${isUp ? '+' : ''}${upDown.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isUp ? chartColors.upColor : chartColors.downColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  // OHLC 数据
                  _buildInfoRow('开盘', openStr, Colors.grey[700]!),
                  const SizedBox(height: 6),
                  _buildInfoRow('最高', highStr, chartColors.upColor),
                  const SizedBox(height: 6),
                  _buildInfoRow('最低', lowStr, chartColors.downColor),
                  const Divider(height: 16),
                  // 成交量
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.bar_chart,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '成交量',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      Text(
                        volStr,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建信息行
  Widget _buildInfoRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}



