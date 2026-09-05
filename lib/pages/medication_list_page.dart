// 药品盘点列表页 —— 对应小程序 pages/med-list/med-list

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/med_list.dart';
import '../models/medicine.dart';
import '../providers.dart';
import '../services/medicine_storage.dart';
import '../services/notification_service.dart';
import '../theme.dart';
import 'about_page.dart';
import 'add_medicine_page.dart';
import 'medicine_detail_page.dart';
import 'statistics_page.dart';
import 'type_manage_page.dart';

class MedicationListPage extends ConsumerStatefulWidget {
  const MedicationListPage({super.key});

  @override
  ConsumerState<MedicationListPage> createState() => _MedicationListPageState();
}

class _MedicationListPageState extends ConsumerState<MedicationListPage> {
  MedicineStorage get _storage => ref.read(medicineRepositoryProvider);

  List<Medicine> _all = [];
  List<MedListItem> _list = [];
  bool _noticeHas = false;
  bool _loading = true;

  final TextEditingController _searchController = TextEditingController();
  String _keyword = '';
  int _tabIndex = 0;
  List<String> _locationTabs = ['全部'];
  bool _noticeFilter = false;

  // 筛选状态
  String? _stageFilter; // 到期阶段，null=全部
  bool _lowStockFilter = false; // 仅看库存不足
  String? _typeFilter; // 药品类型，null=全部

  // 左滑状态
  String? _swipeId;
  double _swipeOffset = 0;
  bool _swipeMoving = false;

  @override
  void initState() {
    super.initState();
    _locationTabs = ['全部', ...AddMedicineLogic.getLocations()];
    _refresh();
  }

  Future<void> _refresh() async {
    // 从数据库加载并同步到全局 providers（含自定义位置）
    List<Medicine> all;
    try {
      all = await _storage.loadAll();
    } catch (_) {
      all = ref.read(medicinesProvider);
    }
    if (!mounted) return;
    setState(() {
      _all = all;
      _loading = false;
      _applyFilter();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final notice = buildExpireNotice(_all);
    final list = buildMedList(
      _all,
      storageLocation: _tabIndex == 0 ? null : _locationTabs[_tabIndex],
      keyword: _keyword.isEmpty ? null : _keyword,
      urgent: _noticeFilter ? true : null,
      stage: _stageFilter,
      lowStock: _lowStockFilter ? true : null,
      medType: _typeFilter,
    );
    setState(() {
      _noticeHas = notice.hasNotice;
      _list = list;
      _swipeId = null;
      _swipeOffset = 0;
      _swipeMoving = false;
    });
  }

  void _toggleNotice() {
    if (!_noticeHas) return;
    setState(() => _noticeFilter = !_noticeFilter);
    _applyFilter();
  }

  void _onTabTap(int index) {
    setState(() => _tabIndex = index);
    _applyFilter();
  }

  void _onSearch(String value) {
    setState(() => _keyword = value);
    _applyFilter();
  }

  void _onClearSearch() {
    _searchController.clear();
    setState(() => _keyword = '');
    _applyFilter();
  }

  void _onItemTap(Medicine m) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MedicineDetailPage(medicine: m)),
    ).then((_) => _refresh());
  }

  void _onGoAdd() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AddMedicinePage()))
        .then((_) => _refresh());
  }

  void _onCardLongPress(Medicine m) {
    final id = m.id;
    final name = m.name.isEmpty ? '该药品' : m.name;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetItem(
              icon: '🗑',
              text: '删除药品',
              color: AppColors.brandDanger,
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(id, name);
              },
            ),
            _sheetItem(
              icon: '🧹',
              text: '一键清除过期药品',
              color: AppColors.brandBlue,
              onTap: () {
                Navigator.pop(ctx);
                _confirmClearExpired();
              },
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: AppColors.brandBorder),
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: const SizedBox(
                height: 52,
                child: Center(
                  child: Text('取消',
                      style: TextStyle(fontSize: 16, color: AppColors.brandTextSub)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetItem({
    required String icon,
    required String text,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 52,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 17)),
            const SizedBox(width: 8),
            Text(text, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: color)),
          ],
        ),
      ),
    );
  }

  // ===== 左滑删除 / 编辑 =====
  void _onSwipeEdit(Medicine m) {
    setState(() {
      _swipeId = null;
      _swipeOffset = 0;
      _swipeMoving = false;
    });
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MedicineDetailPage(medicine: m, editing: true)),
    ).then((_) => _refresh());
  }

  void _onSwipeDelete(Medicine m) {
    setState(() {
      _swipeId = null;
      _swipeOffset = 0;
      _swipeMoving = false;
    });
    _confirmDelete(m.id, m.name.isEmpty ? '该药品' : m.name);
  }

  // ===== 左滑手势 =====
  String? _dragId;

  void _onDragStart(String id) {
    // 若其它卡片已展开，先收起
    if (_swipeId != null && _swipeId != id) {
      setState(() {
        _swipeId = null;
        _swipeOffset = 0;
        _swipeMoving = false;
      });
    }
    _dragId = id;
  }

  void _onDragUpdate(double dx) {
    if (_dragId == null) return;
    setState(() {
      _swipeId = _dragId;
      var offset = (_swipeOffset + dx).clamp(-160.0, 0.0);
      _swipeOffset = offset;
      _swipeMoving = true;
    });
  }

  void _onDragEnd() {
    if (_dragId == null) return;
    _dragId = null;
    final finalOffset = _swipeOffset < -80 ? -160.0 : 0.0;
    setState(() {
      _swipeOffset = finalOffset;
      _swipeMoving = false;
    });
    if (finalOffset == 0) {
      Future.delayed(const Duration(milliseconds: 260), () {
        if (mounted && _swipeOffset == 0) {
          setState(() => _swipeId = null);
        }
      });
    }
  }

  Future<void> _confirmDelete(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除"$name"吗？'),
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
    await _storage.delete(id);
    if (!mounted) return;
    _refresh();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已删除')),
    );
  }

  Future<void> _confirmClearExpired() async {
    final expiredCount = countExpired(_all);
    if (expiredCount == 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('没有过期药品')));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('一键清除过期'),
        content: Text('共有 $expiredCount 种过期药品，确定全部清除？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清除', style: TextStyle(color: AppColors.brandDanger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final newList = clearExpiredMedicines(_all);
    await _storage.saveAll(newList);
    if (!mounted) return;
    _refresh();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('已清除 $expiredCount 种')));
  }

  void _onBackupMenuTap() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetItem(
              icon: '⬆️',
              text: '备份',
              color: AppColors.brandBlue,
              onTap: () {
                Navigator.pop(ctx);
                _exportBackup();
              },
            ),
            _sheetItem(
              icon: '⬇️',
              text: '恢复',
              color: AppColors.brandMint,
              onTap: () {
                Navigator.pop(ctx);
                _importBackup();
              },
            ),
            _sheetItem(
              icon: '🔗',
              text: '药品查询 API 设置',
              color: AppColors.brandTextSub,
              onTap: () {
                Navigator.pop(ctx);
                _showLookupSettings();
              },
            ),
            _sheetItem(
              icon: '⏰',
              text: '到期提醒设置',
              color: AppColors.brandTextSub,
              onTap: () {
                Navigator.pop(ctx);
                _showReminderSettings();
              },
            ),
            _sheetItem(
              icon: '🏷',
              text: '类型管理',
              color: AppColors.brandTextSub,
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const TypeManagePage()));
              },
            ),
            _sheetItem(
              icon: '📊',
              text: '统计概览',
              color: AppColors.brandTextSub,
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const StatisticsPage()));
              },
            ),
            _sheetItem(
              icon: 'ℹ️',
              text: '关于',
              color: AppColors.brandTextSub,
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AboutPage()));
              },
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: AppColors.brandBorder),
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: const SizedBox(
                height: 52,
                child: Center(
                  child: Text('取消',
                      style: TextStyle(fontSize: 16, color: AppColors.brandTextSub)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportBackup() async {
    final messenger = ScaffoldMessenger.of(context);
    final String json;
    try {
      json = await _storage.exportBackup();
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('导出失败')));
      return;
    }
    try {
      final uri = await FilePicker.saveFile(
        dialogTitle: '保存备份',
        fileName: 'minipills_backup_${DateTime.now().millisecondsSinceEpoch}.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: utf8.encode(json),
      );
      if (uri == null) return;
      messenger.showSnackBar(SnackBar(content: Text('备份已保存到 ${uri.toFilePath()}')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('导出失败')));
    }
  }

  Future<void> _importBackup() async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result.isEmpty) return;
    final path = result.first.path;
    if (path == null) return;

    final String content;
    try {
      content = File(path).readAsStringSync();
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('读取备份文件失败')));
      return;
    }
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认导入'),
        content: const Text('导入将替换当前全部药品与存放位置，确定继续？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('导入', style: TextStyle(color: AppColors.brandDanger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final counts = await _storage.importBackup(content);
      if (!mounted) return;
      // 同步共享 providers 与位置标签页，使新增/变更立即可见
      await refreshLocations(ref);
      if (!mounted) return;
      setState(() {
        _locationTabs = ['全部', ...ref.read(locationsProvider)];
      });
      await refreshMedicines(ref);
      if (!mounted) return;
      _refresh();
      messenger.showSnackBar(
        SnackBar(content: Text('导入成功：药品 ${counts.medicines}，位置 ${counts.locations}，类型 ${counts.types}')),
      );
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('导入失败：备份文件无效')));
    }
  }

  // ===== 药品查询 API 设置（扫码联网追溯的数据源） =====
  Future<void> _showLookupSettings() async {
    final lookup = ref.read(barcodeLookupProvider);
    final settings = await lookup.loadSettings();
    if (!mounted) return;
    final urlCtl = TextEditingController(text: settings.url);
    final keyCtl = TextEditingController(text: settings.key);
    final messenger = ScaffoldMessenger.of(context);
    final configured = lookup.isConfigured(settings);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('药品查询 API 设置'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                configured
                      ? '当前已配置，扫码联网追溯可用（免费接口每日次数有限）。'
                      : '当前未配置有效查询接口，扫码联网追溯不可用；请填写真实接口。',
                style: TextStyle(
                  fontSize: 13,
                  color: configured ? AppColors.brandMint : AppColors.brandDanger,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlCtl,
                decoration: const InputDecoration(
                  labelText: '查询接口 URL',
                  hintText: 'https://.../api/barcode-lookup',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: keyCtl,
                decoration: const InputDecoration(
                  labelText: 'API Key（可选）',
                  hintText: '无则留空',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await lookup.saveSettings(url: urlCtl.text, key: keyCtl.text);
              messenger.showSnackBar(const SnackBar(content: Text('已保存药品查询 API 设置')));
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  // ===== 到期提醒天数设置 =====
  Future<void> _showReminderSettings() async {
    final messenger = ScaffoldMessenger.of(context);
    final current = await NotificationService.instance.loadReminderDays();
    if (!mounted) return;
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: Text('到期提前提醒天数',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('选择「0」= 仅到期当天提醒',
                  style: TextStyle(fontSize: 12, color: Color(0xFF8A9BAD))),
            ),
            for (final days in const [0, 3, 7, 14, 30])
              ListTile(
                title: Text(days == 0 ? '仅到期当天（0 天）' : '$days 天',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: current == days ? FontWeight.w700 : FontWeight.w400,
                      color: current == days ? AppColors.brandBlue : AppColors.brandText,
                    )),
                onTap: () => Navigator.pop(ctx, days),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    await NotificationService.instance.saveReminderDays(selected);
    // 立即按新设置重建通知
    await _storage.rescheduleNotifications();
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text('已设置：到期提前 ${selected == 0 ? '当天' : '$selected 天'}提醒')),
    );
  }

  // ===== 高级筛选 =====
  int get _activeFilterCount =>
      (_stageFilter != null ? 1 : 0) + (_lowStockFilter ? 1 : 0) + (_typeFilter != null ? 1 : 0);

  void _toggleStage(String? stage) {
    setState(() => _stageFilter = _stageFilter == stage ? null : stage);
    _applyFilter();
  }

  void _toggleLowStock() {
    setState(() => _lowStockFilter = !_lowStockFilter);
    _applyFilter();
  }

  void _toggleType(String? type) {
    setState(() => _typeFilter = _typeFilter == type ? null : type);
    _applyFilter();
  }

  void _clearFilters() {
    setState(() {
      _stageFilter = null;
      _lowStockFilter = false;
      _typeFilter = null;
    });
    _applyFilter();
  }

  Future<void> _showFilterSheet() async {
    List<String> types;
    try {
      final custom = await _storage.loadCustomTypes();
      types = AddMedicineLogic.getTypes(custom: custom);
    } catch (_) {
      types = AddMedicineLogic.getTypes();
    }
    if (!mounted) return;
    // 到期阶段选项（全部 + 各临期阶段）
    const stageOptions = [
      (key: 'expired', label: '已过期'),
      (key: '3days', label: '3天内'),
      (key: '1week', label: '一周内'),
      (key: '15days', label: '半月内'),
      (key: '1month', label: '一月内'),
      (key: '3months', label: '3月内'),
      (key: 'normal', label: '正常'),
    ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          Widget stageChip(String key, String label) {
            final selected = _stageFilter == key;
            return ChoiceChip(
              label: Text(label),
              selected: selected,
              onSelected: (_) {
                setSheetState(() => _toggleStage(selected ? null : key));
              },
            );
          }

          Widget typeChip(String type) {
            final selected = _typeFilter == type;
            return ChoiceChip(
              label: Text(type),
              selected: selected,
              onSelected: (_) {
                setSheetState(() => _toggleType(selected ? null : type));
              },
            );
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('筛选',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      ),
                      if (_activeFilterCount > 0)
                        TextButton(
                          onPressed: () {
                            setSheetState(_clearFilters);
                          },
                          child: const Text('重置'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('到期阶段',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('全部'),
                        selected: _stageFilter == null,
                        onSelected: (_) => setSheetState(() => _toggleStage(null)),
                      ),
                      for (final opt in stageOptions)
                        stageChip(opt.key, opt.label),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('库存',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                  ChoiceChip(
                    label: Text('仅看库存不足（<$lowStockThreshold）'),
                    selected: _lowStockFilter,
                    onSelected: (_) => setSheetState(_toggleLowStock),
                  ),
                  const SizedBox(height: 16),
                  if (types.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text('药品类型',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('全部'),
                          selected: _typeFilter == null,
                          onSelected: (_) => setSheetState(() => _toggleType(null)),
                        ),
                        for (final t in types) typeChip(t),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            _buildTabs(),
            if (_activeFilterCount > 0) _buildFilterBar(),
            if (_noticeHas) _buildNoticeBar(),
            Expanded(child: _buildContent()),
            _buildAddBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Text('🔍', style: TextStyle(fontSize: 18)),
            ),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: _onSearch,
                onSubmitted: (_) => _applyFilter(),
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: '搜索药品名称',
                  border: InputBorder.none,
                ),
                style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
              ),
            ),
            if (_keyword.isNotEmpty)
              Tooltip(
                message: '清除搜索',
                child: GestureDetector(
                  onTap: _onClearSearch,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text('✕',
                        style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ),
                ),
              ),
            const SizedBox(width: 4),
            Tooltip(
              message: '筛选',
              child: GestureDetector(
                onTap: _showFilterSheet,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        Icons.tune,
                        size: 22,
                        color: _activeFilterCount > 0
                            ? AppColors.brandBlue
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      if (_activeFilterCount > 0)
                        Positioned(
                          right: -6,
                          top: -6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.brandDanger,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Text(
                              '$_activeFilterCount',
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Tooltip(
              message: '菜单',
              child: GestureDetector(
                onTap: _onBackupMenuTap,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('☰',
                      style: TextStyle(fontSize: 20, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    final surface = Theme.of(context).colorScheme.surface;
    final subColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          for (var i = 0; i < _locationTabs.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: () => _onTabTap(i),
                child: Container(
                  height: 34,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: _tabIndex == i ? AppColors.brandBlue : surface,
                    borderRadius: BorderRadius.circular(19),
                    boxShadow: _tabIndex == i
                        ? [
                            BoxShadow(
                              color: AppColors.brandBlue.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : const [
                            BoxShadow(
                                color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 1)),
                          ],
                  ),
                  child: Text(
                    _locationTabs[i],
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: _tabIndex == i ? Colors.white : subColor,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final parts = <String>[
      if (_stageFilter != null) stageText[_stageFilter] ?? '',
      if (_lowStockFilter) '库存不足',
      ?_typeFilter,
    ];
    final text = parts.where((p) => p.isNotEmpty).join(' · ');
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: _showFilterSheet,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: context.appBlueBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: primary.withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            Icon(Icons.filter_alt, size: 16, color: primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '已筛选：$text',
                style: TextStyle(fontSize: 13, color: primary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Text('✕ 清除', style: TextStyle(fontSize: 13, color: primary)),
          ],
        ),
      ),
    );
  }

  Widget _buildNoticeBar() {
    final scheme = Theme.of(context).colorScheme;
    final primary = scheme.primary;
    final secondary = scheme.secondary;
    return GestureDetector(
      onTap: _toggleNotice,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _noticeFilter ? context.appBlueBg : context.appMintBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _noticeFilter
                ? primary.withValues(alpha: 0.4)
                : secondary.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Text(
              _noticeFilter ? '✓' : '⚠️',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                (_noticeFilter ? '已筛选：' : '') + _noticeText(),
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: _noticeFilter ? primary : AppColors.brandMint,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _noticeFilter ? '✕ 清除' : '›',
              style: TextStyle(
                fontSize: 13,
                color: _noticeFilter ? primary : AppColors.brandMint,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _noticeText() {
    final notice = buildExpireNotice(_all);
    return notice.text;
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.brandBlue));
    }
    if (_list.isEmpty) {
      return const _EmptyState();
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: _list.length,
      itemBuilder: (context, i) => _buildCard(_list[i]),
    );
  }

  Widget _buildCard(MedListItem item) {
    final m = item.medicine;
    final isSwiping = _swipeId == m.id;
    return GestureDetector(
      onTap: () => _onItemTap(m),
      onLongPress: () => _onCardLongPress(m),
      onHorizontalDragStart: (_) => _onDragStart(m.id),
      onHorizontalDragUpdate: (d) => _onDragUpdate(d.delta.dx),
      onHorizontalDragEnd: (_) => _onDragEnd(),
      onHorizontalDragCancel: _onDragEnd,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Stack(
            children: [
              // 左滑露出的操作
              Positioned.fill(
                child: Row(
                  children: [
                    Expanded(child: Container(color: Colors.transparent)),
                    GestureDetector(
                      onTap: () => _onSwipeEdit(m),
                      child: Container(
                        width: 80,
                        color: AppColors.brandBlueBg,
                        alignment: Alignment.center,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('✏️', style: TextStyle(fontSize: 20)),
                            SizedBox(height: 2),
                            Text('编辑',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.brandBlue)),
                          ],
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _onSwipeDelete(m),
                      child: Container(
                        width: 80,
                        color: const Color(0xFFFDECEC),
                        alignment: Alignment.center,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('🗑', style: TextStyle(fontSize: 20)),
                            SizedBox(height: 2),
                            Text('删除',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.brandDanger)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: _swipeMoving ? Duration.zero : const Duration(milliseconds: 250),
                transform: Matrix4.translationValues(isSwiping ? _swipeOffset : 0, 0, 0),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2)),
                  ],
                ),
                child: _buildCardBody(m),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardBody(Medicine m) {
    final sc = stageColor(_stageOf(m));
    final statusText = _statusText(m);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 16),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: sc.background,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(14),
                ),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: sc.foreground,
                ),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildThumb(m),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildRow('库存：', '${m.stock}${m.unit ?? ''}'),
                    _buildRow('位置：', m.location ?? '未设置', valueColor: AppColors.brandMint),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThumb(Medicine m) {
    if (m.image == null || m.image!.isEmpty) return const SizedBox(width: 0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: _buildImage(m.image!, width: 64, height: 64),
    );
  }

  Widget _buildImage(String path, {required double width, required double height}) {
    if (path.startsWith('assets/')) {
      return Image.asset(path,
          width: width, height: height, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink());
    }
    return Image.file(
      File(path),
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(label,
                style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                color: valueColor ?? Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _stageOf(Medicine m) => computeStatus(m.expireDate, null).stage;
  String _statusText(Medicine m) {
    final info = computeStatus(m.expireDate, null);
    if (info.stage == 'expired') return '已过期';
    if (info.stage == 'normal') return '正常';
    return '还剩${info.daysLeft}天';
  }

  Widget _buildAddBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [AppColors.brandBlue, AppColors.brandMint],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x594A9FE8), blurRadius: 12, offset: Offset(0, 4)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: _onGoAdd,
            child: const Center(
              child: Text(
                '＋ 添加药品',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final sub = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📦', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text('暂无药品数据', style: TextStyle(fontSize: 16, color: sub)),
        ],
      ),
    );
  }
}
