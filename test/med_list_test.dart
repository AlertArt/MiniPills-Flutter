// 业务逻辑单元测试 —— 对应小程序 tests/med-list.test.js

import 'package:flutter_test/flutter_test.dart';
import 'package:minipills_flutter/models/med_list.dart';
import 'package:minipills_flutter/models/medicine.dart';

Medicine med({
  required String id,
  required String name,
  required String expireDate,
  int stock = 0,
  String? unit,
  String? location,
}) {
  return Medicine(
    id: id,
    name: name,
    expireDate: expireDate,
    stock: stock,
    unit: unit,
    location: location,
  );
}

void main() {
  group('computeStatus', () {
    test('30天后过期 status=warning days_left=30', () {
      final r = computeStatus('2026-02-14', '2026-01-15');
      expect(r.daysLeft, 30);
      expect(r.status, 'warning');
    });

    test('91天后过期 status=normal', () {
      final r = computeStatus('2026-04-16', '2026-01-15');
      expect(r.daysLeft, 91);
      expect(r.status, 'normal');
    });

    test('已过期60天 days_left为负数 status=expired', () {
      final r = computeStatus('2025-11-16', '2026-01-15');
      expect(r.daysLeft, -60);
      expect(r.status, 'expired');
    });

    test('第90天为warning边界', () {
      final r = computeStatus('2026-04-15', '2026-01-15');
      expect(r.daysLeft, 90);
      expect(r.status, 'warning');
    });

    test('第91天为normal边界', () {
      final r = computeStatus('2026-04-16', '2026-01-15');
      expect(r.status, 'normal');
    });

    test('stage: 3天内为3days', () {
      final r = computeStatus('2026-01-18', '2026-01-15');
      expect(r.stage, '3days');
      expect(r.stageText, '3天内过期');
    });

    test('stage: 1周内为1week', () {
      final r = computeStatus('2026-01-22', '2026-01-15');
      expect(r.stage, '1week');
      expect(r.stageText, '一周内过期');
    });

    test('stage: 一个月内为1month', () {
      final r = computeStatus('2026-02-14', '2026-01-15');
      expect(r.stage, '1month');
      expect(r.stageText, '一个月内过期');
    });

    test('stage: 三个月内为3months', () {
      final r = computeStatus('2026-04-15', '2026-01-15');
      expect(r.daysLeft, 90);
      expect(r.stage, '3months');
    });

    test('stage: 已过期为expired', () {
      final r = computeStatus('2026-01-10', '2026-01-15');
      expect(r.stage, 'expired');
      expect(r.stageText, '已过期');
    });
  });

  group('buildExpireNotice', () {
    final items = [
      med(id: '1', name: '过期药A', expireDate: '2026-01-10'),
      med(id: '2', name: '过期药B', expireDate: '2026-01-12'),
      med(id: '3', name: '三天药', expireDate: '2026-01-17'),
      med(id: '4', name: '一周药', expireDate: '2026-01-20'),
      med(id: '5', name: '半月药', expireDate: '2026-01-28'),
      med(id: '6', name: '月药', expireDate: '2026-02-10'),
      med(id: '7', name: '季药', expireDate: '2026-04-01'),
      med(id: '8', name: '正常药', expireDate: '2027-01-01'),
    ];

    test('统计各阶段数量', () {
      final n = buildExpireNotice(items, '2026-01-15');
      expect(n.hasNotice, true);
      expect(n.total, 7);
      expect(n.counts['expired'], 2);
      expect(n.counts['3days'], 1);
      expect(n.counts['1week'], 1);
      expect(n.counts['15days'], 1);
      expect(n.counts['1month'], 1);
      expect(n.counts['3months'], 1);
    });

    test('通知文案按紧急程度排序', () {
      final n = buildExpireNotice(items, '2026-01-15');
      final expiredIdx = n.text.indexOf('已过期');
      final monthIdx = n.text.indexOf('一个月内');
      expect(expiredIdx >= 0, true);
      expect(monthIdx >= 0, true);
      expect(expiredIdx < monthIdx, true);
    });

    test('无临期药品 hasNotice=false', () {
      final n = buildExpireNotice([med(id: '1', name: '正常药', expireDate: '2027-01-01')], '2026-01-15');
      expect(n.hasNotice, false);
      expect(n.total, 0);
    });

    test('空列表 hasNotice=false', () {
      final n = buildExpireNotice(const [], '2026-01-15');
      expect(n.hasNotice, false);
    });
  });

  group('buildMedList', () {
    final items = [
      med(id: '1', name: '过期药', expireDate: '2026-01-10'),
      med(id: '2', name: '临期药', expireDate: '2026-02-15'),
      med(id: '3', name: '正常药', expireDate: '2027-01-01'),
    ];

    test('urgent 只返回临期和过期', () {
      final r = buildMedList(items, nowDate: '2026-01-15', urgent: true);
      expect(r.length, 2);
      for (final item in r) {
        expect(item.stage != 'normal', true);
      }
    });

    test('按 stage 筛选', () {
      final r = buildMedList(items, nowDate: '2026-01-15', stage: 'expired');
      expect(r.length, 1);
      expect(r[0].medicine.name, '过期药');
    });

    test('排序按阶段紧急程度', () {
      final r = buildMedList(items, nowDate: '2026-01-15');
      expect(r[0].medicine.name, '过期药');
      expect(r[1].medicine.name, '临期药');
      expect(r[2].medicine.name, '正常药');
    });

    test('无筛选返回全部并追加days_left和status', () {
      final sample = [
        med(id: '1', name: '布洛芬', expireDate: '2025-09-25', stock: 24, unit: '粒', location: '客厅红药箱'),
        med(id: '2', name: '头孢', expireDate: '2025-12-10', stock: 12, unit: '片', location: '冰箱冷藏'),
        med(id: '3', name: '氯雷他定', expireDate: '2026-02-20', stock: 6, unit: '片', location: '客厅红药箱'),
        med(id: '4', name: '蒙脱石散', expireDate: '2026-04-01', stock: 10, unit: '袋', location: '主卧抽屉'),
        med(id: '5', name: '维C', expireDate: '2026-07-01', stock: 60, unit: '片', location: '客厅红药箱'),
        med(id: '6', name: '阿莫西林', expireDate: '2027-01-01', stock: 36, unit: '粒', location: '冰箱冷藏'),
      ];
      final r = buildMedList(sample, nowDate: '2026-01-15');
      expect(r.length, 6);
      expect(r.first.daysLeft, isA<int>());
      expect(r.first.status, isNotEmpty);
    });

    test('排序: expired在前, normal最后', () {
      final sample = [
        med(id: '1', name: 'a', expireDate: '2025-09-25'),
        med(id: '2', name: 'b', expireDate: '2025-12-10'),
        med(id: '3', name: 'c', expireDate: '2026-02-20'),
        med(id: '4', name: 'd', expireDate: '2026-04-01'),
        med(id: '5', name: 'e', expireDate: '2026-07-01'),
        med(id: '6', name: 'f', expireDate: '2027-01-01'),
      ];
      final r = buildMedList(sample, nowDate: '2026-01-15');
      final statuses = r.map((x) => x.status).toList();
      final expiredIdx = statuses.indexOf('expired');
      final normalIdx = statuses.lastIndexOf('normal');
      expect(expiredIdx >= 0, true);
      expect(normalIdx >= 0, true);
      for (var i = 0; i <= expiredIdx; i++) {
        expect(r[i].status, 'expired');
      }
      for (var i = normalIdx; i < r.length; i++) {
        expect(r[i].status, 'normal');
      }
    });

    test('同状态按过期时间从近到远', () {
      final sample = [
        med(id: '1', name: 'a', expireDate: '2025-09-25'),
        med(id: '2', name: 'b', expireDate: '2025-12-10'),
        med(id: '3', name: 'c', expireDate: '2026-07-01'),
      ];
      final r = buildMedList(sample, nowDate: '2026-01-15');
      final expiredItems = r.where((x) => x.status == 'expired').toList();
      expect(expiredItems.length, 2);
      expect(expiredItems[0].daysLeft <= expiredItems[1].daysLeft, true);
    });

    test('按 storage_location 筛选', () {
      final sample = [
        med(id: '1', name: 'a', expireDate: '2025-09-25', location: '冰箱冷藏'),
        med(id: '2', name: 'b', expireDate: '2025-12-10', location: '客厅红药箱'),
      ];
      final r = buildMedList(sample, nowDate: '2026-01-15', storageLocation: '冰箱冷藏');
      expect(r.length, 1);
      expect(r[0].medicine.location, '冰箱冷藏');
    });

    test('按 keyword 搜索不区分大小写', () {
      final sample = [
        med(id: '1', name: 'ABc', expireDate: '2027-01-01'),
        med(id: '2', name: 'xyz', expireDate: '2027-01-01'),
      ];
      final r = buildMedList(sample, nowDate: '2026-01-15', keyword: 'ab');
      expect(r.length, 1);
      expect(r[0].medicine.name, 'ABc');
    });

    test('空数组返回空数组', () {
      final r = buildMedList(const [], nowDate: '2026-01-15');
      expect(r.length, 0);
    });
  });

  group('查找/更新/删除', () {
    final items = [
      med(id: 'a1', name: '布洛芬', expireDate: '2025-09-25', stock: 24, unit: '粒', location: '客厅红药箱'),
      med(id: 'a2', name: '头孢克肟', expireDate: '2025-12-10', stock: 12, unit: '片', location: '冰箱冷藏'),
    ];

    test('findMedicineById 按 id 找到药品', () {
      final found = findMedicineById(items, 'a1');
      expect(found, isNotNull);
      expect(found!.name, '布洛芬');
    });

    test('findMedicineById 不存在的 id 返回 null', () {
      expect(findMedicineById(items, 'nonexist'), isNull);
    });

    test('updateMedicine 更新名称和库存', () {
      final list = [med(id: 'b1', name: '阿莫西林', expireDate: '2027-01-01', stock: 36)];
      final updated = updateMedicine(list, 'b1',
          Medicine(id: 'b1', name: '阿莫西林胶囊', expireDate: '2027-01-01', stock: 20));
      expect(updated, isNotNull);
      expect(list[0].name, '阿莫西林胶囊');
      expect(list[0].stock, 20);
    });

    test('updateMedicine 不存在的 id 返回原列表', () {
      final list = [med(id: 'b1', name: '药', expireDate: '2027-01-01')];
      updateMedicine(list, 'b2', Medicine(id: 'b2', name: '新药', expireDate: '2027-01-01'));
      expect(list.length, 1);
      expect(list[0].name, '药');
    });

    test('deleteMedicine 删除指定药品', () {
      final r = deleteMedicine(items, 'a1');
      expect(r.length, 1);
      expect(r[0].id, 'a2');
    });

    test('clearExpiredMedicines 清除过期', () {
      final list = [
        med(id: '1', name: '过期', expireDate: '2025-12-01'),
        med(id: '2', name: '正常', expireDate: '2027-06-01'),
      ];
      final r = clearExpiredMedicines(list, '2026-01-15');
      expect(r.length, 1);
      expect(r[0].id, '2');
    });
  });

  group('Medicine 序列化', () {
    test('toJson/fromJson 往返一致', () {
      final m = Medicine(
        id: 'x1',
        barcode: '690123',
        name: '布洛芬',
        spec: '0.3g*24',
        manufacturer: '某厂',
        medType: '药片',
        expireDate: '2026-03-01',
        stock: 30,
        unit: '片',
        location: '冰箱',
        image: '/a.jpg',
      );
      final json = m.toJson();
      final back = Medicine.fromJson(json);
      expect(back.id, 'x1');
      expect(back.name, '布洛芬');
      expect(back.stock, 30);
      expect(back.barcode, '690123');
      expect(back.expireDate, '2026-03-01');
    });
  });

  group('AddMedicineLogic', () {
    test('validateMedicine 校验必填项', () {
      expect(AddMedicineLogic.validateMedicine({'name': '', 'expire_date': null}).length, greaterThan(0));
      expect(
        AddMedicineLogic.validateMedicine({'name': '药', 'expire_date': '2026-03-01'}).length,
        0,
      );
    });

    test('updateSubmitState 名称未填写时禁用', () {
      final s = AddMedicineLogic.updateSubmitState(name: '', expireDate: '2026-03-01');
      expect(s.canSubmit, false);
      expect(s.submitText, '请填写药品信息');
    });

    test('updateSubmitState 名称+有效期齐全可用', () {
      final s = AddMedicineLogic.updateSubmitState(name: '药', expireDate: '2026-03-01');
      expect(s.canSubmit, true);
      expect(s.submitText, '确认添加');
    });

    test('fillFormFromAi 回填字段并缩写有效期', () {
      final filled = AddMedicineLogic.fillFormFromAi({
        'name': '布洛芬',
        'spec': '0.3g*24',
        'expire_date': '2026-03-15',
        'manufacturer': '某厂',
      });
      expect(filled['name'], '布洛芬');
      expect(filled['expireDate'], '2026-03-15');
      expect(filled['expireDateDisplay'], '2026-03');
    });

    test('buildSubmitData 构建提交数据', () {
      final data = AddMedicineLogic.buildSubmitData({
        'name': ' 药 ',
        'expireDate': '2026-03-01',
        'stock': 30,
        'stockUnit': '片',
        'location': '冰箱',
      });
      expect(data['name'], '药');
      expect(data['expire_date'], '2026-03-01');
      expect(data['stock'], 30);
    });

    test('generateId 生成唯一 id', () {
      final a = AddMedicineLogic.generateId();
      final b = AddMedicineLogic.generateId();
      expect(a, isNot(b));
      expect(a.contains('_'), true);
    });
  });
}
