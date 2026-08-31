// 药品盘点列表页 —— 对应小程序 pages/med-list/med-list

import 'dart:io';

import 'package:flutter/material.dart';

import '../models/med_list.dart';
import '../models/medicine.dart';
import '../services/medicine_storage.dart';
import '../theme.dart';
import 'add_medicine_page.dart';
import 'medicine_detail_page.dart';

class MedicationListPage extends StatefulWidget {
  const MedicationListPage({super.key});

  @override
  State<MedicationListPage> createState() => _MedicationListPageState();
}

class _MedicationListPageState extends State<MedicationListPage> {
  final MedicineStorage _storage = MedicineStorage();

  List<Medicine> _all = [];
  List<MedListItem> _list = [];
  bool _noticeHas = false;
  bool _loading = true;

  final TextEditingController _searchController = TextEditingController();
  String _keyword = '';
  int _tabIndex = 0;
  List<String> _locationTabs = ['全部'];
  bool _noticeFilter = false;

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
    final all = await _storage.loadAll();
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
      backgroundColor: Colors.white,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            _buildTabs(),
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
          color: Colors.white,
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
                style: const TextStyle(fontSize: 16, color: AppColors.brandText),
              ),
            ),
            if (_keyword.isNotEmpty)
              GestureDetector(
                onTap: _onClearSearch,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Text('✕', style: TextStyle(fontSize: 16, color: Color(0xFF999999))),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
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
                    color: _tabIndex == i ? AppColors.brandBlue : Colors.white,
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
                      color: _tabIndex == i ? Colors.white : AppColors.brandTextSub,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNoticeBar() {
    return GestureDetector(
      onTap: _toggleNotice,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _noticeFilter ? AppColors.brandBlueBg : AppColors.brandMintBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _noticeFilter ? const Color(0xFFB6DCF5) : const Color(0xFFBFE8D5),
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
                  color: _noticeFilter ? const Color(0xFF3A7CB8) : const Color(0xFF2E8B6C),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _noticeFilter ? '✕ 清除' : '›',
              style: TextStyle(
                fontSize: 13,
                color: _noticeFilter ? const Color(0xFF3A7CB8) : const Color(0xFF2E8B6C),
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
                  color: Colors.white,
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
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandText,
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
                style: const TextStyle(fontSize: 15, color: AppColors.brandTextSub)),
          ),
          Expanded(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                color: valueColor ?? AppColors.brandText,
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
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('📦', style: TextStyle(fontSize: 48)),
          SizedBox(height: 12),
          Text('暂无药品数据', style: TextStyle(fontSize: 16, color: Color(0xFF999999))),
        ],
      ),
    );
  }
}
