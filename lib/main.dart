import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pages/medication_list_page.dart';
import 'services/medicine_storage.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 启动前做数据库完整性检查，损坏时自动从最近备份兜底恢复
  await MedicineStorage.runIntegrityCheckAndRepair();
  MedicineStorage.initNotifications();
  runApp(const ProviderScope(child: MiniPillsApp()));
}

class MiniPillsApp extends StatelessWidget {
  const MiniPillsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MiniPills',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      darkTheme: buildAppTheme(brightness: Brightness.dark),
      themeMode: ThemeMode.system,
      home: const MedicationListPage(),
    );
  }
}
