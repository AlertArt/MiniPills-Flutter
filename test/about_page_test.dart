// 关于页 widget 测试：渲染、动态版本号、卸载警示
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:minipills_flutter/pages/about_page.dart';
import 'package:minipills_flutter/theme.dart';

void main() {
  testWidgets('关于页渲染标题/警示，并显示动态版本号', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'MiniPills',
      packageName: 'com.example.minipills',
      version: '9.9.9',
      buildNumber: '99',
      buildSignature: '',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const AboutPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('关于'), findsOneWidget);
    expect(find.text('MiniPills'), findsOneWidget);
    // 动态读取到的版本号（非硬编码）
    expect(find.text('版本 9.9.9'), findsOneWidget);
    // 卸载数据丢失警示存在
    expect(find.textContaining('卸载会丢失数据'), findsOneWidget);
    expect(find.textContaining('备份'), findsWidgets);
  });
}