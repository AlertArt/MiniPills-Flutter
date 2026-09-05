// 关于页面 —— App 信息与数据安全提示
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../theme.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  static const String appName = 'MiniPills';

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _version = info.version);
  }

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final sub = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Icon(Icons.medication,
                    size: 48, color: AppColors.brandBlue),
                const SizedBox(height: 12),
                const Text(AboutPage.appName,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('版本 ${_version.isEmpty ? '…' : _version}',
                    style: TextStyle(fontSize: 14, color: sub)),
                const SizedBox(height: 6),
                Text('家庭药品管理 · 扫码追溯 · 到期提醒',
                    style: TextStyle(fontSize: 13, color: sub)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surface,
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