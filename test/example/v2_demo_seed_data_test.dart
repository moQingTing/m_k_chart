import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/v2_example_support.dart';

// 离线种子仅供仓库示例使用，不是 SDK 正式公开入口。
// ignore: avoid_relative_lib_imports
import '../../example/lib/market/v2_demo_seed_data.dart';

void main() {
  test('同一周期种子确定、版本独立，最后一根保持未闭合', () {
    final first = createV2DemoSeedData(KlineInterval.oneMinute, revision: 2);
    final second = createV2DemoSeedData(KlineInterval.oneMinute, revision: 3);

    expect(first.data, hasLength(180));
    expect(first.version, KlineDataVersion(2));
    expect(second.version, KlineDataVersion(3));
    expect(first.data.first.openTime, second.data.first.openTime);
    expect(first.data.last.close, second.data.last.close);
    expect(
      first.data.last.openTime - first.data.first.openTime,
      179 * Duration.millisecondsPerMinute,
    );
    expect(first.data.first.isClosed, isTrue);
    expect(first.data.last.isClosed, isFalse);
    expect(
      first.data.last.closeTime - first.data.last.openTime,
      Duration.millisecondsPerMinute - 1,
    );
  });

  test('周期切换改变时间间距，月历周期明确拒绝', () {
    final daily = createV2DemoSeedData(KlineInterval.oneDay, revision: 0);
    expect(
      daily.data[1].openTime - daily.data.first.openTime,
      Duration.millisecondsPerDay,
    );
    expect(
      () => createV2DemoSeedData(
        KlineInterval.calendarMonth(code: '1M'),
        revision: 0,
      ),
      throwsArgumentError,
    );
  });

  test('行情适配器复制输入，已发布快照不会被原列表修改', () {
    final source = createV2DemoSeedData(KlineInterval.oneMinute, revision: 0);
    final mutable = List<Kline>.of(source.data.take(2));
    final snapshot = V2DemoKlineData.fromCandles(mutable, revision: 4);
    final first = snapshot.data.first;

    mutable.removeAt(0);
    expect(snapshot.data, hasLength(2));
    expect(snapshot.data.first, same(first));
    expect(snapshot.version, KlineDataVersion(4));
    expect(() => snapshot.data.add(first), throwsUnsupportedError);
  });
}
