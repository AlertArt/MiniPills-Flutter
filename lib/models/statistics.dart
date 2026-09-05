// 盘点统计数据模型 —— 纯业务逻辑，无 UI 依赖
// 提供品种/库存/到期/位置的简单统计概览。

import 'med_list.dart';
import 'medicine.dart';

/// 统计概览数据
class MedicineStats {
  /// 药品品种总数
  final int total;

  /// 所有药品库存数量之和
  final int totalStock;

  /// 已过期品种数
  final int expiredCount;

  /// 临期（未过期但进入提醒阶段）品种数
  final int expiringCount;

  /// 库存不足（库存 < lowStockThreshold）品种数
  final int lowStockCount;

  /// 各到期阶段 -> 品种数（order 与 stageOrder 一致）
  final Map<String, int> stageCounts;

  /// 存放位置 -> 品种数
  final Map<String, int> locationCounts;

  /// 药品类型 -> 品种数
  final Map<String, int> typeCounts;

  const MedicineStats({
    required this.total,
    required this.totalStock,
    required this.expiredCount,
    required this.expiringCount,
    required this.lowStockCount,
    required this.stageCounts,
    required this.locationCounts,
    required this.typeCounts,
  });
}

/// 生成统计概览。[nowDate] 可选，用于测试固定日期（YYYY-MM-DD）
MedicineStats buildMedicineStats(List<Medicine> items, [String? nowDate]) {
  var totalStock = 0;
  var expiredCount = 0;
  var expiringCount = 0;
  var lowStockCount = 0;
  final stageCounts = <String, int>{};
  final locationCounts = <String, int>{};
  final typeCounts = <String, int>{};

  for (final m in items) {
    totalStock += m.stock;
    if (m.stock < lowStockThreshold) lowStockCount++;

    final stage = computeStatus(m.expireDate, nowDate).stage;
    stageCounts[stage] = (stageCounts[stage] ?? 0) + 1;
    if (stage == 'expired') {
      expiredCount++;
    } else if (stage != 'normal') {
      expiringCount++;
    }

    final loc = m.location;
    if (loc != null && loc.isNotEmpty) {
      locationCounts[loc] = (locationCounts[loc] ?? 0) + 1;
    }

    final type = m.medType;
    if (type != null && type.isNotEmpty) {
      typeCounts[type] = (typeCounts[type] ?? 0) + 1;
    }
  }

  return MedicineStats(
    total: items.length,
    totalStock: totalStock,
    expiredCount: expiredCount,
    expiringCount: expiringCount,
    lowStockCount: lowStockCount,
    stageCounts: stageCounts,
    locationCounts: locationCounts,
    typeCounts: typeCounts,
  );
}

/// 到期阶段展示顺序（用于图表从上到下排列）
const List<String> statsStageOrder = [
  'expired', '3days', '1week', '15days', '1month', '3months', 'normal',
];