import 'package:flutter_test/flutter_test.dart';

// 请求守卫仅用于旧 Demo 的示例行情生命周期。
// ignore: avoid_relative_lib_imports
import '../../example/lib/market/v2_demo_refresh_gate.dart';

void main() {
  test('同一加载代际仅允许一个刷新，完成后可以继续', () {
    final gate = V2DemoRefreshGate();
    final generation = gate.beginLoad();

    final ticket = gate.beginRefresh()!;
    expect(ticket.loadGeneration, generation);
    expect(gate.isCurrentRefresh(ticket), isTrue);
    expect(gate.beginRefresh(), isNull);
    gate.finishRefresh(ticket);
    expect(gate.beginRefresh(), isNotNull);
  });

  test('旧请求未完成也不阻塞新代际，旧完成不能释放新占位', () {
    final gate = V2DemoRefreshGate();
    final old = gate.beginLoad();
    final oldTicket = gate.beginRefresh()!;
    expect(oldTicket.loadGeneration, old);

    final current = gate.beginLoad();
    expect(gate.isCurrent(old), isFalse);
    expect(gate.isCurrent(current), isTrue);
    expect(gate.isCurrentRefresh(oldTicket), isFalse);
    final currentTicket = gate.beginRefresh()!;
    expect(currentTicket.loadGeneration, current);
    gate.finishRefresh(oldTicket);
    expect(gate.beginRefresh(), isNull);

    gate.finishRefresh(currentTicket);
    expect(gate.beginRefresh(), isNotNull);
  });

  test('隐藏页面使在途刷新失效，恢复后旧请求不能释放新请求', () {
    final gate = V2DemoRefreshGate();
    gate.beginLoad();
    final hiddenRequest = gate.beginRefresh()!;

    gate.pauseRefresh();
    expect(gate.isCurrentRefresh(hiddenRequest), isFalse);
    expect(gate.beginRefresh(), isNull);

    gate.resumeRefresh();
    final visibleRequest = gate.beginRefresh()!;
    expect(
      visibleRequest.visibilityGeneration,
      greaterThan(hiddenRequest.visibilityGeneration),
    );
    gate.finishRefresh(hiddenRequest);
    expect(gate.isCurrentRefresh(visibleRequest), isTrue);
    expect(gate.beginRefresh(), isNull);
  });

  test('离开页面可单独废弃完整窗口加载，返回后新加载取得新代际', () {
    final gate = V2DemoRefreshGate();
    final oldLoad = gate.beginLoad();
    gate.pauseRefresh();
    gate.invalidateLoad();

    expect(gate.isCurrent(oldLoad), isFalse);
    gate.resumeRefresh();
    final newLoad = gate.beginLoad();
    expect(newLoad, greaterThan(oldLoad));
    expect(gate.isCurrent(newLoad), isTrue);
  });
}
