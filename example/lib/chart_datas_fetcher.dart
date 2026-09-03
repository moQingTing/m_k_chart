//
//  ChartDatasFetcher.dart
//  Example
//
//  Created based on ChartDatasFetcher.swift and KlineChartData.swift
//

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:m_k_chart/m_k_chart.dart';

/// K线数据获取器
/// 用于从 OKX API 获取 K 线数据
class ChartDatasFetcher {
  /// 接口地址
  String apiURL = "https://www.okx.com/api/v5";

  /// 私有构造函数
  ChartDatasFetcher._();

  /// 全局唯一实例
  static final ChartDatasFetcher shared = ChartDatasFetcher._();

  /// 获取服务API的K线数据
  ///
  /// - [symbol] 交易对符号，例如 "BTC-USDT"
  /// - [timeType] 时间周期，例如 "1m", "5m", "15m", "1H", "4H", "1D" 等
  /// - [size] 数据条数
  /// - [callback] 回调函数，参数为 (是否成功, K线数据列表)
  /// - [timeout] 请求超时时间，默认 30 秒
  Future<void> getRemoteChartData(
    String symbol,
    String timeType,
    int size,
    Function(bool success, List<KLineEntity> data) callback, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      // 构建请求 URL
      final url = Uri.parse(
        '$apiURL/market/candles?instId=$symbol&bar=$timeType&limit=$size',
      );

      print('📡 请求 URL: $url');

      // 发送 HTTP GET 请求，添加超时设置
      final response = await http
          .get(url)
          .timeout(timeout, onTimeout: () {
        throw Exception('请求超时，请检查网络连接');
      });

      print('📥 响应状态码: ${response.statusCode}');

      if (response.statusCode == 200) {
        // 解析 JSON 数据
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        print('📦 响应数据: ${jsonData.toString().substring(0, jsonData.toString().length > 200 ? 200 : jsonData.toString().length)}...');

        // 检查响应是否成功
        if (jsonData['code'] == '0' || jsonData['code'] == 0) {
          // 获取 data 数组
          final dataArray = jsonData['data'] as List<dynamic>?;

          if (dataArray != null && dataArray.isNotEmpty) {
            print('✅ 获取到 ${dataArray.length} 条数据');
            var marketDatas = <KLineEntity>[];

            // 遍历数据数组，转换为 KLineEntity
            // 与 Swift 版本保持一致：遍历数组，创建 KlineChartData，然后转换
            for (final item in dataArray) {
              if (item is List) {
                final klineEntity = _parseKlineData(item);
                if (klineEntity != null) {
                  marketDatas.add(klineEntity);
                } else {
                  print('⚠️ 解析单条数据失败: $item');
                }
              } else {
                print('⚠️ 数据格式不正确，期望 List，实际: ${item.runtimeType}');
              }
            }

            if (marketDatas.isEmpty) {
              print('❌ 没有成功解析任何数据');
              callback(false, []);
              return;
            }

            // 反转数组（OKX API 返回的是从新到旧，需要反转）
            // 与 Swift 版本保持一致：marketDatas.reverse()
            marketDatas = marketDatas.reversed.toList();

            print('✅ 成功解析 ${marketDatas.length} 条 K 线数据');
            // 回调成功结果
            callback(true, marketDatas);
            return;
          } else {
            print('⚠️ 数据数组为空或 null');
          }
        } else {
          // API 返回错误
          final errorMsg = jsonData['msg'] ?? '未知错误';
          final errorCode = jsonData['code'] ?? '未知';
          print('❌ API 错误: code=$errorCode, msg=$errorMsg');
        }
      } else {
        // HTTP 请求失败
        print('❌ HTTP 错误: ${response.statusCode}');
        print('响应内容: ${response.body}');
      }
    } on http.ClientException catch (e) {
      // 网络连接错误
      print('❌ 网络连接错误: $e');
      print('请检查：');
      print('  1. 设备是否连接到网络');
      print('  2. 是否允许应用访问网络（iOS: Info.plist, Android: AndroidManifest.xml）');
    } on FormatException catch (e) {
      // JSON 解析错误
      print('❌ JSON 解析错误: $e');
    } on Exception catch (e) {
      // 其他异常（包括超时）
      print('❌ 异常: $e');
    } catch (e, stackTrace) {
      // 未知异常
      print('❌ 未知错误: $e');
      print('堆栈跟踪: $stackTrace');
    }

    // 回调失败结果
    callback(false, []);
  }

  /// 解析单条 K 线数据
  /// OKX API 返回的数据格式: [timestamp, open, high, low, close, volume, amount, confirm]
  /// 根据 KlineChartData.swift 的实现，至少需要 8 个元素
  /// timestamp 可能是 String 或 Int
  /// 价格和成交量可能是 String 或 Double
  KLineEntity? _parseKlineData(List<dynamic> dataArray) {
    try {
      // 根据 Swift 版本，至少需要 8 个元素
      if (dataArray.length < 8) {
        print('⚠️ 数据长度不足，期望至少 8 个元素，实际: ${dataArray.length}');
        return null;
      }

      // 解析时间戳 - 与 Swift 版本保持一致
      int timestamp = 0;
      final timestampValue = dataArray[0];
      if (timestampValue is String) {
        // 字符串格式的时间戳
        timestamp = int.tryParse(timestampValue) ?? 0;
      } else if (timestampValue is int) {
        // 整数格式的时间戳
        timestamp = timestampValue;
      } else {
        // 尝试转换为字符串再解析
        timestamp = int.tryParse(timestampValue.toString()) ?? 0;
      }

      if (timestamp == 0) {
        print('⚠️ 时间戳解析失败: $timestampValue');
        return null;
      }

      // 解析价格和成交量 - 与 Swift 版本保持一致
      // 安全地转换数据，支持 String 和 Double 类型
      double open = _safeParseDouble(dataArray[1]);
      double high = _safeParseDouble(dataArray[2]);
      double low = _safeParseDouble(dataArray[3]);
      double close = _safeParseDouble(dataArray[4]);
      double volume = _safeParseDouble(dataArray[5]);
      double amount = _safeParseDouble(dataArray[6]);
      // confirm 字段（第8个元素）通常不需要

      // 验证数据有效性
      if (open <= 0 || close <= 0 || high <= 0 || low <= 0 || volume < 0) {
        print('⚠️ 数据异常: 存在无效值 (open=$open, close=$close, high=$high, low=$low, volume=$volume)');
        return null;
      }

      // 检查是否为 NaN 或 Infinity
      if (open.isNaN || open.isInfinite ||
          close.isNaN || close.isInfinite ||
          high.isNaN || high.isInfinite ||
          low.isNaN || low.isInfinite ||
          volume.isNaN || volume.isInfinite ||
          amount.isNaN || amount.isInfinite) {
        print('⚠️ 数据异常: 存在 NaN 或 Infinity 值');
        return null;
      }

      // 确保 high >= max(open, close) 和 low <= min(open, close)
      // 这是 K 线数据的基本规则
      final maxPrice = open > close ? open : close;
      final minPrice = open < close ? open : close;
      var finalHigh = high;
      var finalLow = low;

      if (high < maxPrice || low > minPrice) {
        print('⚠️ 数据异常: high/low 范围不正确，自动修正');
        // 自动修正：确保 high >= max(open, close) 和 low <= min(open, close)
        finalHigh = high < maxPrice ? maxPrice : high;
        finalLow = low > minPrice ? minPrice : low;

        if (finalHigh < finalLow) {
          print('⚠️ 修正后仍然无效，跳过此条数据');
          return null;
        }
      }

      // 创建 KLineEntity - 与 Swift 版本的 toCompleteKLineEntity() 对应
      final entity = KLineEntity();
      entity.id = timestamp;
      entity.open = open;
      entity.close = close;
      entity.high = finalHigh;
      entity.low = finalLow;
      entity.vol = volume;
      entity.amount = amount;
      entity.count = volume.toInt(); // 使用成交量作为交易笔数，与 Swift 版本一致

      // 最终验证
      if (entity.high < entity.low ||
          entity.open <= 0 || entity.close <= 0 ||
          entity.high <= 0 || entity.low <= 0) {
        print('⚠️ 最终验证失败，跳过此条数据');
        return null;
      }

      return entity;
    } catch (e, stackTrace) {
      print('❌ 解析 K 线数据错误: $e');
      print('数据: $dataArray');
      print('堆栈: $stackTrace');
      return null;
    }
  }

  /// 安全地解析 Double 值
  /// 支持 String 和 num 类型，与 Swift 版本保持一致
  double _safeParseDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    } else if (value is String) {
      return double.tryParse(value) ?? 0.0;
    } else {
      // 尝试转换为字符串再解析
      return double.tryParse(value.toString()) ?? 0.0;
    }
  }
}
