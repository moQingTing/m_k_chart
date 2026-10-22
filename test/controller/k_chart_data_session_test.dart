import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/controller/k_chart_data_session.dart';
import 'package:m_k_chart/src/model/model.dart';

void main() {
  final btc = KlineSeries(symbol: 'BTCUSDT', interval: KlineInterval.oneMinute);
  final eth = KlineSeries(symbol: 'ETHUSDT', interval: KlineInterval.oneMinute);

  test('same series refresh and A-B-A both invalidate old tokens', () {
    final gate = KChartSessionGate(btc);
    final initial = gate.current;
    expect(gate.accepts(initial), isTrue);
    final refresh = gate.begin(btc);
    expect(gate.accepts(initial), isFalse);
    expect(refresh.generation, 1);
    final away = gate.begin(eth);
    final back = gate.begin(btc);
    expect(back.generation, 3);
    expect(back.series, btc);
    expect(gate.accepts(refresh), isFalse);
    expect(gate.accepts(away), isFalse);
    expect(gate.accepts(back), isTrue);
  });

  test(
      'matching numeric generations from different charts are not interchangeable',
      () {
    final first = KChartSessionGate(btc);
    final second = KChartSessionGate(btc);
    expect(first.current.generation, second.current.generation);
    expect(first.accepts(second.current), isFalse);
    expect(second.accepts(first.current), isFalse);
  });

  test('late asynchronous result cannot apply after switching series',
      () async {
    final gate = KChartSessionGate(btc);
    final request = gate.current;
    final response = Completer<int>();
    int? applied;
    final done = response.future.then((value) {
      if (gate.accepts(request)) applied = value;
    });
    gate.begin(eth);
    response.complete(42);
    await done;
    expect(applied, isNull);
  });

  test('dispose invalidates all in-flight tokens and is idempotent', () {
    final gate = KChartSessionGate(btc);
    final request = gate.current;
    gate.dispose();
    gate.dispose();
    expect(gate.accepts(request), isFalse);
    expect(gate.current, same(request));
    expect(() => gate.begin(btc), throwsStateError);
  });

  test(
      'one controller attachment is allowed, rebuilding the same owner is safe',
      () {
    final guard = KChartAttachmentGuard();
    final first = Object();
    final second = Object();
    guard.attach(first);
    guard.attach(first);
    expect(() => guard.attach(second), throwsStateError);
    expect(guard.isAttached, isTrue);
    guard.detach(first);
    guard.attach(second);
    // 旧 Widget 的清理不能释放当前新 Widget 的资源。
    guard.detach(first);
    expect(guard.isAttached, isTrue);
    guard.detach(second);
    expect(guard.isAttached, isFalse);
  });

  test('attachment guards isolate charts and reject attach after disposal', () {
    final first = KChartAttachmentGuard();
    final second = KChartAttachmentGuard();
    final owner = Object();
    first.attach(owner);
    second.attach(Object());
    first.dispose();
    first.dispose();
    first.detach(owner);
    expect(first.isAttached, isFalse);
    expect(second.isAttached, isTrue);
    expect(() => first.attach(owner), throwsStateError);
  });
}
