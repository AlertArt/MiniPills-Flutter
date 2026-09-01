// 冒烟测试：应用可构建并渲染药品盘点列表页

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:minipills_flutter/main.dart';

void main() {
  testWidgets('App builds and shows MedicationListPage', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MiniPillsApp()));
    await tester.pump();

    // 页面应有搜索框提示 + 底部添加按钮
    expect(find.text('搜索药品名称'), findsOneWidget);
    expect(find.text('＋ 添加药品'), findsOneWidget);
  });
}
