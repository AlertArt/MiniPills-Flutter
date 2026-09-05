// 自定义药品类型管理页 —— 查看、重命名、删除自定义类型
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/medicine.dart';
import '../providers.dart';
import '../services/medicine_storage.dart';
import '../theme.dart';

class TypeManagePage extends ConsumerStatefulWidget {
  const TypeManagePage({super.key});

  @override
  ConsumerState<TypeManagePage> createState() => _TypeManagePageState();
}

class _TypeManagePageState extends ConsumerState<TypeManagePage> {
  MedicineStorage get _storage => ref.read(medicineRepositoryProvider);

  List<CustomType> _types = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final types = await _storage.loadCustomTypes();
      if (!mounted) return;
      setState(() {
        _types = types;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _rename(CustomType ct) async {
    final ctl = TextEditingController(text: ct.name);
    final messenger = ScaffoldMessenger.of(context);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名类型'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          decoration: const InputDecoration(labelText: '类型名称', hintText: '输入新名称'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              final v = ctl.text.trim();
              if (v.isEmpty) {
                messenger.showSnackBar(const SnackBar(content: Text('名称不能为空')));
                return;
              }
              Navigator.pop(ctx, v);
            },
            child: const Text('保存', style: TextStyle(color: AppColors.brandBlue)),
          ),
        ],
      ),
    );
    if (newName == null || newName == ct.name) return;
    try {
      await _storage.renameCustomType(ct.name, newName);
      await _load();
      messenger.showSnackBar(const SnackBar(content: Text('已重命名')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('重命名失败')));
    }
  }

  Future<void> _delete(CustomType ct) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除类型'),
        content: Text(
          '确定删除「${ct.name}」？\n\n若已有药品使用该类型，其类型将被清空（设为未设置）。',
          style: const TextStyle(height: 1.6),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: AppColors.brandDanger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _storage.deleteCustomType(ct.name);
      await _load();
      messenger.showSnackBar(const SnackBar(content: Text('已删除')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('删除失败')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('类型管理'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.brandText,
        elevation: 0,
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brandBlue))
          : _types.isEmpty
              ? const Center(
                  child: Text('暂无自定义类型\n\n可在添加药品时选择「自定义类型…」创建',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Color(0xFF8A9BAD), height: 1.8)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _types.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final ct = _types[i];
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(ct.name,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.brandText)),
                                const SizedBox(height: 2),
                                Text('单位：${ct.units.join('、')}',
                                    style: const TextStyle(
                                        fontSize: 13, color: Color(0xFF8A9BAD))),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF8A9BAD)),
                            tooltip: '重命名',
                            onPressed: () => _rename(ct),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.brandDanger),
                            tooltip: '删除',
                            onPressed: () => _delete(ct),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
