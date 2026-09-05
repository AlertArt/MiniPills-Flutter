// 药品列表业务逻辑 —— 对应小程序 models/med-list.js

import 'dart:ui' show Color;
import 'medicine.dart';

/// 临期阶段顺序，用于排序
const Map<String, int> stageOrder = {
  'expired': 0,
  '3days': 1,
  '1week': 2,
  '15days': 3,
  '1month': 4,
  '3months': 5,
  'normal': 6,
};

/// 阶段显示文案
const Map<String, String> stageText = {
  'expired': '已过期',
  '3days': '3天内过期',
  '1week': '一周内过期',
  '15days': '半个月内过期',
  '1month': '一个月内过期',
  '3months': '三个月内过期',
  'normal': '正常',
};

String getStage(int diff) {
  if (diff <= 0) return 'expired';
  if (diff <= 3) return '3days';
  if (diff <= 7) return '1week';
  if (diff <= 15) return '15days';
  if (diff <= 30) return '1month';
  if (diff <= 90) return '3months';
  return 'normal';
}

/// 解析日期为"当天 0 点"均匀的 UTC DateTime
DateTime _parseDate(dynamic d) {
  if (d is String && d.length == 10) {
    return DateTime.utc(
        int.parse(d.substring(0, 4)), int.parse(d.substring(5, 7)), int.parse(d.substring(8, 10)));
  }
  if (d is DateTime) return d;
  return DateTime.tryParse('$d') ?? DateTime.now();
}

/// 计算剩余天数与状态
/// [nowDate] 可选，用于测试固定日期（YYYY-MM-DD）
({int daysLeft, String status, String stage, String stageText}) computeStatus(
  String? expireDate,
  String? nowDate,
) {
  final expire = _parseDate(expireDate);
  DateTime now;
  if (nowDate != null && nowDate.isNotEmpty) {
    now = _parseDate(nowDate);
  } else {
    final t = DateTime.now();
    now = DateTime.utc(t.year, t.month, t.day);
  }
  final diff = ((expire.difference(now)).inSeconds / (24 * 60 * 60)).round();
  final stage = getStage(diff);
  final status = stage == 'normal' ? 'normal' : (stage == 'expired' ? 'expired' : 'warning');
  return (
    daysLeft: diff,
    status: status,
    stage: stage,
    stageText: stageText[stage] ?? '正常',
  );
}

/// 带展示字段的列表条目
class MedListItem {
  final Medicine medicine;
  final int daysLeft;
  final String status; // normal / warning / expired
  final String stage;
  final String stageText;

  const MedListItem({
    required this.medicine,
    required this.daysLeft,
    required this.status,
    required this.stage,
    required this.stageText,
  });
}

/// 库存不足阈值：库存数量低于该值视为「库存不足」
const int lowStockThreshold = 5;

/// 筛选 + 排序构建列表
/// filters 支持：storageLocation, keyword, stage, urgent, medType, lowStock
List<MedListItem> buildMedList(
  List<Medicine> items, {
  String? nowDate,
  String? storageLocation,
  String? keyword,
  String? stage,
  bool? urgent,
  String? medType,
  bool? lowStock,
}) {
  final result = items.map((item) {
    final info = computeStatus(item.expireDate, nowDate);
    return MedListItem(
      medicine: item,
      daysLeft: info.daysLeft,
      status: info.status,
      stage: info.stage,
      stageText: info.stageText,
    );
  }).toList();

  final filtered = result.where((item) {
    if (storageLocation != null &&
        storageLocation.isNotEmpty &&
        item.medicine.location != storageLocation) {
      return false;
    }
    if (keyword != null &&
        keyword.isNotEmpty &&
        !(item.medicine.name.toLowerCase().contains(keyword.toLowerCase()))) {
      return false;
    }
    if (stage != null && stage.isNotEmpty && item.stage != stage) {
      return false;
    }
    if (urgent == true && item.stage == 'normal') {
      return false;
    }
    if (medType != null && medType.isNotEmpty && item.medicine.medType != medType) {
      return false;
    }
    if (lowStock == true && item.medicine.stock >= lowStockThreshold) {
      return false;
    }
    return true;
  }).toList();

  filtered.sort((a, b) {
    final diff = (stageOrder[a.stage] ?? 6) - (stageOrder[b.stage] ?? 6);
    if (diff != 0) return diff;
    return a.daysLeft - b.daysLeft;
  });

  return filtered;
}

/// 构建临期通知
class ExpireNotice {
  final int total;
  final bool hasNotice;
  final String text;
  final Map<String, int> counts;

  const ExpireNotice({
    required this.total,
    required this.hasNotice,
    required this.text,
    required this.counts,
  });
}

ExpireNotice buildExpireNotice(List<Medicine> items, [String? nowDate]) {
  final counts = <String, int>{};
  for (final item in items) {
    final info = computeStatus(item.expireDate, nowDate);
    counts[info.stage] = (counts[info.stage] ?? 0) + 1;
  }
  const order = ['expired', '3days', '1week', '15days', '1month', '3months'];
  final parts = <String>[];
  var total = 0;
  for (final key in order) {
    final c = counts[key];
    if (c != null && c > 0) {
      parts.add('$c种${stageText[key]}');
      total += c;
    }
  }
  return ExpireNotice(
    total: total,
    hasNotice: total > 0,
    text: parts.join(' · '),
    counts: counts,
  );
}

/// 通过 id 查找
Medicine? findMedicineById(List<Medicine> list, String id) {
  for (final m in list) {
    if (m.id == id) return m;
  }
  return null;
}

/// 更新指定药品（就地修改传入列表，返回更新后的条目；未找到返回 null）
Medicine? updateMedicine(List<Medicine> list, String id, Medicine updated) {
  final idx = list.indexWhere((m) => m.id == id);
  if (idx == -1) return null;
  list[idx] = updated;
  return updated;
}

/// 删除指定药品
List<Medicine> deleteMedicine(List<Medicine> list, String id) {
  return list.where((m) => m.id != id).toList();
}

/// 清除过期药品
List<Medicine> clearExpiredMedicines(List<Medicine> list, [String? nowDate]) {
  return list
      .where((m) => computeStatus(m.expireDate, nowDate).status != 'expired')
      .toList();
}

/// 统计过期数量
int countExpired(List<Medicine> list, [String? nowDate]) {
  return list.where((m) => computeStatus(m.expireDate, nowDate).status == 'expired').length;
}

/* ================= 阶段配色（对应小程序 med-list.wxss 各 tag） ================= */

/// 阶段对应的标签配色（前景色 + 背景色）
class StageColor {
  final Color foreground;
  final Color background;
  const StageColor(this.foreground, this.background);
}

const Color _white = Color(0xFFFFFFFF);
const Color _inkDark = Color(0xFF5A4A2A);
const Color _inkGreen = Color(0xFF4A5230);

StageColor stageColor(String stage) {
  switch (stage) {
    case 'expired':
      // #f56c6c
      return const StageColor(_white, Color(0xFFF56C6C));
    case '3days':
      // #f0835c
      return const StageColor(_white, Color(0xFFF0835C));
    case '1week':
      // #f5a05f
      return const StageColor(_white, Color(0xFFF5A05F));
    case '15days':
      // #f7bc6b
      return const StageColor(_white, Color(0xFFF7BC6B));
    case '1month':
      // #f5d06e (深色文字)
      return const StageColor(_inkDark, Color(0xFFF5D06E));
    case '3months':
      // #d9d96b (深色文字)
      return const StageColor(_inkGreen, Color(0xFFD9D96B));
    case 'normal':
      // #3eb489
      return const StageColor(_white, Color(0xFF3EB489));
    default:
      return const StageColor(_white, Color(0xFF3EB489));
  }
}
