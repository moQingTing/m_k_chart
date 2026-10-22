import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// 编辑器属于示例实现，不是 SDK 正式公开入口。
// ignore: avoid_relative_lib_imports
import '../../example/lib/settings/v2_indicator_parameter_editor.dart';

void main() {
  test('参数格式与中文字段名称保持旧 Demo 约定', () {
    expect(formatV2IndicatorParameter(5), '5');
    expect(formatV2IndicatorParameter(2.5), '2.5');
    expect(v2IndicatorParameterLabel('period1'), '周期 1');
    expect(v2IndicatorParameterLabel('multiplier'), '倍数');
    expect(v2IndicatorParameterLabel('customKey'), 'customKey');
  });

  testWidgets('提交后重算显示值，恢复默认同步更新输入框', (tester) async {
    var values = <String, num>{'period1': 5};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => V2IndicatorParameterEditor(
              indicatorId: 'ma',
              label: 'MA',
              values: values,
              summary: '周期 1 ${values['period1']}',
              onSubmitted: (key, raw) => setState(() {
                values = {key: num.parse(raw)};
              }),
              onReset: () => setState(() {
                values = {'period1': 5};
              }),
            ),
          ),
        ),
      ),
    );

    final field = find.byKey(const ValueKey('indicator-param-ma-period1'));
    String inputText() => tester
        .widget<EditableText>(
          find.descendant(of: field, matching: find.byType(EditableText)),
        )
        .controller
        .text;
    expect(inputText(), '5');
    expect(find.text('周期 1 5'), findsOneWidget);

    await tester.enterText(field, '7');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(inputText(), '7');
    expect(find.text('周期 1 7'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('indicator-param-reset-ma')));
    await tester.pump();
    expect(inputText(), '5');
    expect(find.text('周期 1 5'), findsOneWidget);
  });

  testWidgets('无参数指标展示说明且不出现输入框', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: V2IndicatorParameterEditor(
            indicatorId: 'vwap',
            label: 'VWAP',
            values: const {},
            summary: '无参数',
            onSubmitted: (key, raw) {},
            onReset: () {},
          ),
        ),
      ),
    );
    expect(find.text('该指标按全部可见 K 线计算，没有周期或常数可设置。'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
  });
}
