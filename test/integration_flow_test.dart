// 集成测试：storage(SQLite) + 页面 UI 的完整链路
// 使用 tester.runAsync() 推进真实异步（SQLite），配合手动 pump 避免无限动画。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:minipills_flutter/models/medicine.dart';
import 'package:minipills_flutter/pages/medication_list_page.dart';
import 'package:minipills_flutter/services/database_helper.dart';
import 'package:minipills_flutter/services/medicine_storage.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await DatabaseHelper.instance.reset();
    DatabaseHelper.instance.useDatabasePath(inMemoryDatabasePath);
  });

  tearDown(() async {
    await DatabaseHelper.instance.reset();
  });

  Medicine makeMedicine(String id, {required String name, String? expireDate}) {
    return Medicine(
      id: id,
      name: name,
      expireDate: expireDate ?? '2026-12-31',
      stock: 3,
      unit: '片',
      location: '药箱（客厅）',
    );
  }

  /// 预置数据到真实 SQLite（真实异步）
  Future<void> seed(WidgetTester tester, List<Medicine> items) async {
    await tester.runAsync(() async {
      final storage = MedicineStorage();
      for (final m in items) {
        await storage.add(m);
      }
    });
  }

  /// 等待页面加载完成（手动 pump，避免 settle 被无限 spinner 卡住）
  Future<void> pumpUntilLoaded(WidgetTester tester) async {
    // 让页面 initState 中的 loadAll 真实异步完成，再刷新帧
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump();
      // 若加载完成（无 spinner），即可停止
      if (tester.any(find.byType(CircularProgressIndicator)) == false) {
        break;
      }
    }
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('预置数据到 SQLite，列表页渲染出药品卡片', (tester) async {
    await seed(tester, [
      makeMedicine('a1', name: '布洛芬', expireDate: '2026-12-31'),
      makeMedicine('a2', name: '维生素C', expireDate: '2027-01-15'),
    ]);

    await tester.pumpWidget(const MaterialApp(home: MedicationListPage()));
    await pumpUntilLoaded(tester);

    expect(find.text('布洛芬'), findsOneWidget);
    expect(find.text('维生素C'), findsOneWidget);
    expect(find.text('库存：'), findsNWidgets(2));
    expect(find.text('3片'), findsNWidgets(2));
    expect(find.text('位置：'), findsNWidgets(2));
    // 药箱（客厅）出现在位置 tab + 两张卡片值 = 3
    expect(find.text('药箱（客厅）'), findsNWidgets(3));
  });

  testWidgets('列表页搜索过滤本地数据', (tester) async {
    await seed(tester, [
      makeMedicine('a1', name: '布洛芬'),
      makeMedicine('a2', name: '维生素C'),
    ]);

    await tester.pumpWidget(const MaterialApp(home: MedicationListPage()));
    await pumpUntilLoaded(tester);

    await tester.enterText(find.byType(TextField), '维生素');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('维生素C'), findsOneWidget);
    expect(find.text('布洛芬'), findsNothing);
  });

  testWidgets('通过 UI 长按删除药品，并从数据库移除', (tester) async {
    await seed(tester, [
      makeMedicine('a1', name: '布洛芬'),
      makeMedicine('a2', name: '维生素C'),
    ]);

    await tester.pumpWidget(const MaterialApp(home: MedicationListPage()));
    await pumpUntilLoaded(tester);

    expect(find.text('布洛芬'), findsOneWidget);

    await tester.longPress(find.text('布洛芬'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('删除药品'), findsOneWidget);

    await tester.tap(find.text('删除药品'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('确认删除'), findsOneWidget);

    await tester.tap(find.text('删除').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 轮询等待删除的 SQLite 写 + 列表刷新（loadAll）真实异步完成
    var deleted = false;
    for (var i = 0; i < 20 && !deleted; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      deleted = tester.any(find.text('布洛芬')) == false;
    }

    expect(find.text('布洛芬'), findsNothing);
    expect(find.text('维生素C'), findsOneWidget);

    // 真实异步读取数据库验证
    await tester.runAsync(() async {
      final all = await MedicineStorage().loadAll();
      expect(all.map((m) => m.name).toList(), ['维生素C']);
    });
  });
}
