import 'package:flutter/material.dart';

import 'pages/medication_list_page.dart';
import 'theme.dart';

void main() {
  runApp(const MiniPillsApp());
}

class MiniPillsApp extends StatelessWidget {
  const MiniPillsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MiniPills',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const MedicationListPage(),
    );
  }
}
