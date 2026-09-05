// 统计概览页 —— 库存/到期/位置的简单统计图表（无第三方图表库）

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/med_list.dart';
import '../models/statistics.dart';
import '../providers.dart';
import '../services/medicine_storage.dart';
import '../theme.dart';

class StatisticsPage extends ConsumerStatefulWidget {
  const StatisticsPage({super.key});

  @override
  ConsumerState<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends ConsumerState<StatisticsPage> {
  MedicineStorage? _storage;
  MedicineStats? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _storage = ref.read(medicineRepositoryProvider);
    _load();
  }

  Future<void> _load() async {
    final items = await _storage!.loadAll();
    if (!mounted) return;
    setState(() {
      _stats = buildMedicineStats(items);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    return Scaffold(
      appBar: AppBar(title: const Text('统计概览')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.brandBlue))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _buildSummaryGrid(stats!),
                  const SizedBox(height: 20),
                  _buildSectionTitle('到期分布', '按 已过期 → 正常 排列'),
                  if (stats.total == 0)
                    _buildEmptyHint('暂无药品数据')
                  else
                    _buildStageBars(stats),
                  const SizedBox(height: 20),
                  _buildSectionTitle('存放位置', '各位置的药品品种数'),
                  if (stats.locationCounts.isEmpty)
                    _buildEmptyHint('暂未记录位置')
                  else
                    _buildLocationBars(stats),
                  if (stats.lowStockCount > 0) ...[
                    const SizedBox(height: 20),
                    _buildSectionTitle('低库存提醒', '库存 < $lowStockThreshold 的药品'),
                    _buildLowStockList(),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, String sub) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 2),
        Text(sub, style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildEmptyHint(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }

  Widget _buildSummaryGrid(MedicineStats stats) {
    return Row(
      children: [
        _summaryCard('品种数', '${stats.total}', AppColors.brandBlue),
        const SizedBox(width: 10),
        _summaryCard('库存总数', '${stats.totalStock}', AppColors.brandMint),
        const SizedBox(width: 10),
        _summaryCard('临期/过期', '${stats.expiringCount + stats.expiredCount}',
            AppColors.brandWarning),
        const SizedBox(width: 10),
        _summaryCard('低库存', '${stats.lowStockCount}', AppColors.brandDanger),
      ],
    );
  }

  Widget _summaryCard(String label, String value, Color accent) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: context.appCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.appBorder),
        ),
        child: Column(
          children: [
            SizedBox(
              width: 36,
              height: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(value,
                style: theme.textTheme.titleLarge
                    ?.copyWith(color: accent, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(label,
                style: theme.textTheme.bodySmall?.copyWith(color: context.appTextSub)),
          ],
        ),
      ),
    );
  }

  Widget _buildStageBars(MedicineStats stats) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        children: [
          for (final stage in statsStageOrder)
            if ((stats.stageCounts[stage] ?? 0) > 0)
              _barRow(
                label: stageText[stage] ?? stage,
                count: stats.stageCounts[stage]!,
                total: stats.total,
                color: stageColor(stage).background,
              ),
        ],
      ),
    );
  }

  Widget _buildLocationBars(MedicineStats stats) {
    final entries = stats.locationCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxCount = entries.fold<int>(1, (m, e) => e.value > m ? e.value : m);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        children: [
          for (final e in entries)
            _barRow(
              label: e.key,
              count: e.value,
              total: maxCount,
              color: AppColors.brandMint,
            ),
        ],
      ),
    );
  }

  Widget _buildLowStockList() {
    final count = _stats?.lowStockCount ?? 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appBorder),
      ),
      child: Text(
        '有 $count 种药品库存低于 $lowStockThreshold，建议及时补充。',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  Widget _barRow({
    required String label,
    required int count,
    required int total,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final ratio = total <= 0 ? 0.0 : (count / total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(label,
                style: theme.textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 10,
                backgroundColor: context.appBorder.withValues(alpha: 0.5),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 40,
            child: Text('$count',
                textAlign: TextAlign.right,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}