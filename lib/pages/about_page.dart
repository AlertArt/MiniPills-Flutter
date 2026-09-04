// 关于页面 —— App 信息与数据安全提示
import 'package:flutter/material.dart';

import '../theme.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  /// 与 pubspec.yaml 中的 version 保持一致
  static const String appVersion = '1.0.4';
  static const String appName = 'MiniPills';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('关于'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.brandText,
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Icon(Icons.medication,
                    size: 48, color: AppColors.brandBlue),
                const SizedBox(height: 12),
                const Text(appName,
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.brandText)),
                const SizedBox(height: 4),
                Text('版本 $appVersion',
                    style: const TextStyle(fontSize: 14, color: Color(0xFF8A9BAD))),
                const SizedBox(height: 6),
                const Text('家庭药品管理 · 扫码追溯 · 到期提醒',
                    style: TextStyle(fontSize: 13, color: Color(0xFF8A9BAD))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.brandDanger.withValues(alpha: 0.4)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 22, color: AppColors.brandDanger),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '⚠️ 卸载会丢失数据，请及时备份！\n\n药品数据保存在本机应用内。卸载 App、清除应用数据或清理系统缓存时，所有记录会一并删除。\n\n建议在「更多（☰）→ 备份」中导出备份文件，重装后可再「恢复」。',
                    style: TextStyle(
                        fontSize: 14, height: 1.6, color: Color(0xFF8A3D3D)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
