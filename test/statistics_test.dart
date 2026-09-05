// 统计数据纯逻辑测试
import 'package:flutter_test/flutter_test.dart';
import 'package:minipills_flutter/models/medicine.dart';
import 'package:minipills_flutter/models/statistics.dart';

Medicine med({
  required String id,
  required String name,
  required String expireDate,
  int stock = 0,
  String? unit,
  String? location,
  String? medType,
}) {
  return Medicine(
    id: id,
    name: name,
    expireDate: expireDate,
    stock: stock,
    unit: unit,
    location: location,
    medType: medType,
  );
}

void main() {
  group('buildMedicineStats', () {
    final items = [
      med(id: '1', name: '过期A', expireDate: '2026-01-10', stock: 2, location: '药箱', medType: '药片'),
      med(id: '2', name: '过期B', expireDate: '2026-01-12', stock: 10, location: '冰箱', medType: '胶囊'),
      med(id: '3', name: '临期', expireDate: '2026-01-18', stock: 4, location: '药箱', medType: '药片'),
      med(id: '4', name: '正常', expireDate: '2027-06-01', stock: 30, location: '冰箱'),
      med(id: '5', name: '无位置', expireDate: '2027-06-01', stock: 1),
    ];

    test('基本计数与库存汇总', () {
      final s = buildMedicineStats(items, '2026-01-15');
      expect(s.total, 5);
      expect(s.totalStock, 47);
      expect(s.expiredCount, 2);
      expect(s.expiringCount, 1);
      expect(s.lowStockCount, 3); // stock < 5：过期A(2)、临期(4)、无位置(1)
    });

    test('阶段分布计数', () {
      final s = buildMedicineStats(items, '2026-01-15');
      expect(s.stageCounts['expired'], 2);
      expect(s.stageCounts['3days'], 1);
      expect(s.stageCounts['normal'], 2);
      expect(s.stageCounts['1month'], isNull);
    });

    test('位置分布只统计非空位置', () {
      final s = buildMedicineStats(items, '2026-01-15');
      expect(s.locationCounts['药箱'], 2);
      expect(s.locationCounts['冰箱'], 2);
      expect(s.locationCounts.length, 2);
    });

    test('类型分布只统计非空类型', () {
      final s = buildMedicineStats(items, '2026-01-15');
      expect(s.typeCounts['药片'], 2);
      expect(s.typeCounts['胶囊'], 1);
      expect(s.typeCounts.length, 2);
    });

    test('空列表返回全 0', () {
      final s = buildMedicineStats(const [], '2026-01-15');
      expect(s.total, 0);
      expect(s.totalStock, 0);
      expect(s.expiredCount, 0);
      expect(s.expiringCount, 0);
      expect(s.lowStockCount, 0);
    });
  });
}