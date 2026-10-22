import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// 设置弹窗属于示例实现，不是 SDK 正式公开入口。
// ignore: avoid_relative_lib_imports
import '../../example/lib/settings/v2_demo_settings_sheet.dart';

void main() {
  testWidgets('设置弹窗保持标题、滚动容器、局部刷新和关闭动作', (tester) async {
    var value = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showV2DemoSettingsSheet(
                context: context,
                title: '图表设置',
                childrenBuilder: (setSheetState) => [
                  TextButton(
                    onPressed: () => setSheetState(() => value++),
                    child: Text('数值 $value'),
                  ),
                ],
              ),
              child: const Text('打开设置'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开设置'));
    await tester.pumpAndSettle();
    expect(find.text('图表设置'), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-sheet-scroll')), findsOneWidget);
    expect(find.text('数值 0'), findsOneWidget);

    await tester.tap(find.text('数值 0'));
    await tester.pump();
    expect(find.text('数值 1'), findsOneWidget);

    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings-sheet-scroll')), findsNothing);
    expect(find.text('打开设置'), findsOneWidget);
  });
}
