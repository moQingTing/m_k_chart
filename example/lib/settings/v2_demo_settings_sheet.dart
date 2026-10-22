import 'package:flutter/material.dart';

/// 打开旧组装式 Demo 共用的设置面板外壳。
///
/// 页面只提供标题和设置项；此处负责弹窗尺寸、滚动与关闭动作。
/// [childrenBuilder] 接收弹窗自己的 [StateSetter]，让参数修改只刷新设置内容。
void showV2DemoSettingsSheet({
  required BuildContext context,
  required String title,
  required List<Widget> Function(StateSetter setSheetState) childrenBuilder,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: const Color(0xfff8fafc),
    builder: (context) => SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.9,
        child: StatefulBuilder(
          builder: (context, setSheetState) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xff0f172a),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  key: const ValueKey('settings-sheet-scroll'),
                  padding: const EdgeInsets.all(16),
                  children: childrenBuilder(setSheetState),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
