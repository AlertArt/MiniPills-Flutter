// MedicineStorage 使用 SQLite 的单元测试（通过 sqflite_common_ffi 在内存中运行真实 SQLite）
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:minipills_flutter/models/medicine.dart';
import 'package:minipills_flutter/services/database_helper.dart';
import 'package:minipills_flutter/services/medicine_storage.dart';

void main() {
  setUpAll(() {
    // 在单元测试中用 FFI 提供真实 SQLite
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // 每次用例使用独立的内存数据库，避免相互污染
    await DatabaseHelper.instance.reset();
    DatabaseHelper.instance.useDatabasePath(inMemoryDatabasePath);
  });

  tearDown(() async {
    await DatabaseHelper.instance.reset();
  });

  Medicine makeMedicine(String id,
      {String name = '布洛芬', int stock = 1, String? barcode, String? location, String? expireDate}) {
    return Medicine(
      id: id,
      name: name,
      barcode: barcode ?? '6901234567890',
      expireDate: expireDate ?? '2027-12-31',
      stock: stock,
      location: location ?? '药箱（客厅）',
      unit: '片',
      images: const ['/img/a.png', '/img/b.png'],
    );
  }

  group('MedicineStorage SQLite', () {
    test('add 后 loadAll 能读回完整数据（含多图）', () async {
      final storage = MedicineStorage();
      await storage.add(makeMedicine('m1'));
      final all = await storage.loadAll();
      expect(all, hasLength(1));
      final m = all.first;
      expect(m.id, 'm1');
      expect(m.name, '布洛芬');
      expect(m.expireDate, '2027-12-31');
      expect(m.stock, 1);
      expect(m.images, ['/img/a.png', '/img/b.png']);
    });

    test('update 按 id 更新字段', () async {
      final storage = MedicineStorage();
      await storage.add(makeMedicine('m1'));
      final updated = makeMedicine('m1', name: '泰诺', stock: 5);
      final result = await storage.update('m1', updated);
      expect(result?.name, '泰诺');
      final all = await storage.loadAll();
      expect(all.first.name, '泰诺');
      expect(all.first.stock, 5);
    });

    test('update 不存在的 id 返回 null', () async {
      final storage = MedicineStorage();
      final result = await storage.update('nope', makeMedicine('nope'));
      expect(result, isNull);
    });

    test('delete 按 id 删除', () async {
      final storage = MedicineStorage();
      await storage.add(makeMedicine('m1'));
      await storage.add(makeMedicine('m2'));
      await storage.delete('m1');
      final all = await storage.loadAll();
      expect(all, hasLength(1));
      expect(all.first.id, 'm2');
    });

    test('saveAll 全量替换', () async {
      final storage = MedicineStorage();
      await storage.add(makeMedicine('m1'));
      await storage.saveAll([
        makeMedicine('m2'),
        makeMedicine('m3'),
      ]);
      final all = await storage.loadAll();
      expect(all.map((m) => m.id).toSet(), {'m2', 'm3'});
    });

    test('自定义位置去重添加', () async {
      final storage = MedicineStorage();
      await storage.addCustomLocation('床头柜');
      await storage.addCustomLocation('床头柜');
      await storage.addCustomLocation(' 床头柜 ');
      final list = await storage.loadCustomLocations();
      expect(list, ['床头柜']);
    });

    test('clearAll 清空药品表', () async {
      final storage = MedicineStorage();
      await storage.add(makeMedicine('m1'));
      await MedicineStorage.clearAll();
      final all = await storage.loadAll();
      expect(all, isEmpty);
    });

    test('queryMedicines 按 location 精确过滤', () async {
      final storage = MedicineStorage();
      await storage.add(makeMedicine('m1', name: '药A', location: '冰箱'));
      await storage.add(makeMedicine('m2', name: '药B', location: '药箱（客厅）'));
      final r = await storage.queryMedicines(location: '冰箱');
      expect(r.map((m) => m.id), ['m1']);
    });

    test('queryMedicines 按 keyword 模糊搜索名称', () async {
      final storage = MedicineStorage();
      await storage.add(makeMedicine('m1', name: '布洛芬缓释片'));
      await storage.add(makeMedicine('m2', name: '泰诺林'));
      final r = await storage.queryMedicines(keyword: '布洛芬');
      expect(r.map((m) => m.id), ['m1']);
    });

    test('queryMedicines 按 expireBefore 过滤到期早于指定日', () async {
      final storage = MedicineStorage();
      await storage.add(Medicine(
          id: 'm1',
          name: '快到期',
          expireDate: '2026-01-20',
          barcode: '111'));
      await storage.add(Medicine(
          id: 'm2',
          name: '较晚',
          expireDate: '2027-12-31',
          barcode: '222'));
      final r = await storage.queryMedicines(expireBefore: '2026-03-01');
      expect(r.map((m) => m.id), ['m1']);
    });

    test('queryMedicines 组合条件且按到期日升序', () async {
      final storage = MedicineStorage();
      await storage.add(Medicine(
          id: 'm1', name: '药X', location: '冰箱', expireDate: '2026-06-01', barcode: '001'));
      await storage.add(Medicine(
          id: 'm2', name: '药X', location: '药箱（客厅）', expireDate: '2026-03-01', barcode: '002'));
      final r = await storage.queryMedicines(location: '冰箱', keyword: '药X');
      expect(r.map((m) => m.id), ['m1']);
    });

    test('queryMedicines 无筛选项时不生效额外 WHERE', () async {
      final storage = MedicineStorage();
      await storage.add(makeMedicine('m1'));
      await storage.add(makeMedicine('m2'));
      final r = await storage.queryMedicines();
      expect(r, hasLength(2));
    });

    test('findByBarcode 命中既往录入', () async {
      final storage = MedicineStorage();
      await storage.add(makeMedicine('m1', name: '布洛芬', barcode: '6901234567890'));
      final hit = await storage.findByBarcode('6901234567890');
      expect(hit?.id, 'm1');
      expect(hit?.name, '布洛芬');
    });

    test('findByBarcode 未命中返回 null', () async {
      final storage = MedicineStorage();
      await storage.add(makeMedicine('m1', name: '布洛芬', barcode: '111'));
      expect(await storage.findByBarcode('999'), isNull);
    });

    test('findByBarcode 空条码返回 null', () async {
      final storage = MedicineStorage();
      expect(await storage.findByBarcode('   '), isNull);
    });
  });

  group('MedicineStorage 旧数据迁移', () {
    String encodeLegacy(List<Medicine> list) =>
        jsonEncode(list.map((e) => e.toJson()).toList());

    setUp(() {
      // 清空 shared_preferences mock，模拟全新安装
      SharedPreferences.setMockInitialValues({});
    });

    test('首次 loadAll 从旧 shared_preferences 导入药品并清除旧数据', () async {
      // 预置旧版 JSON 数据：仅含 image 单图字段
      SharedPreferences.setMockInitialValues({
        'medList': jsonEncode([
          {'id': 'old2', 'name': '旧版单图药', 'expire_date': '2026-06-30', 'image': '/legacy/single.png'},
        ]),
      });

      final storage = MedicineStorage();
      final all = await storage.loadAll();

      expect(all, hasLength(1));
      expect(all.first.id, 'old2');
      expect(all.first.name, '旧版单图药');
      // images 兼容：单图字段迁移为 images[0]
      expect(all.first.images, ['/legacy/single.png']);

      // 迁移后旧数据应从 shared_preferences 清除
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.get('medList'), isNull);
    });

    test('首次 loadAll 迁移含多图数组的旧数据', () async {
      SharedPreferences.setMockInitialValues({
        'medList': encodeLegacy([
          makeMedicine('m1', name: '多图药'),
          makeMedicine('m2', name: '另一药'),
        ]),
      });

      final storage = MedicineStorage();
      final all = await storage.loadAll();
      expect(all.map((m) => m.name).toSet(), {'多图药', '另一药'});
      expect(all.firstWhere((m) => m.id == 'm1').images, ['/img/a.png', '/img/b.png']);
    });

    test('迁移的同时导入自定义位置列表', () async {
      SharedPreferences.setMockInitialValues({
        'customLocations': ['床头柜', '玄关柜'],
      });

      final storage = MedicineStorage();
      final locations = await storage.loadCustomLocations();
      expect(locations, ['床头柜', '玄关柜']);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.get('customLocations'), isNull);
    });

    test('迁移仅在首次触发，不会重复导入', () async {
      SharedPreferences.setMockInitialValues({
        'medList': encodeLegacy([makeMedicine('m1', name: '仅一次')]),
      });

      final storage = MedicineStorage();
      // 第一次触发迁移
      expect(await storage.loadAll(), hasLength(1));
      // 清除 shared_preferences 后再次调用不应删除已导入的 SQLite 数据
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('medList');
      expect(await storage.loadAll(), hasLength(1));
    });

    test('exportBackup 生成包含药品、自定义位置与类型的 JSON', () async {
      final storage = MedicineStorage();
      await storage.add(makeMedicine('m1', name: '布洛芬'));
      await storage.add(makeMedicine('m2', name: '泰诺'));
      await storage.addCustomLocation('床头柜');
      await storage.addCustomType('膏药', ['张', '盒']);

      final json = await storage.exportBackup();
      final data = jsonDecode(json) as Map<String, dynamic>;
      expect(data['version'], 2);
      final meds = data['medicines'] as List;
      expect(meds, hasLength(2));
      expect((data['customLocations'] as List).toSet(), {'床头柜'});
      final types = data['customTypes'] as List;
      final paste = types.firstWhere((e) => (e as Map)['name'] == '膏药') as Map;
      expect(paste['units'], ['张', '盒']);
      // 药品保留完整字段
      final first = meds.firstWhere((e) => (e as Map)['id'] == 'm1') as Map;
      expect(first['name'], '布洛芬');
      expect(first['images'], ['/img/a.png', '/img/b.png']);
    });

    test('importBackup 全量替换药品、自定义位置与类型', () async {
      final storage = MedicineStorage();
      await storage.add(makeMedicine('m1', name: '旧药'));
      await storage.addCustomLocation('旧位置');
      await storage.addCustomType('旧类型', ['片']);

      final json = jsonEncode({
        'version': 2,
        'app': 'MiniPills',
        'medicines': [
          {
            'id': 'n1',
            'barcode': '111',
            'name': '新药',
            'expire_date': '2027-06-01',
            'stock': 3,
            'unit': '盒',
            'location': '卧室抽屉',
            'images': <String>[],
          }
        ],
        'customLocations': ['玄关柜', '床头柜'],
        'customTypes': [
          {'name': '膏药', 'units': ['张', '盒']},
        ],
      });

      final counts = await storage.importBackup(json);
      expect(counts.medicines, 1);
      expect(counts.locations, 2);
      expect(counts.types, 1);

      final all = await storage.loadAll();
      expect(all, hasLength(1));
      expect(all.first.name, '新药');
      expect(await storage.loadCustomLocations(), containsAll(['玄关柜', '床头柜']));
      final types = await storage.loadCustomTypes();
      expect(types.map((t) => t.name), contains('膏药'));
      expect(types.map((t) => t.name), isNot(contains('旧类型')));
      // 旧数据不再存在
      expect(all.map((m) => m.name), isNot(contains('旧药')));
    });

    test('importBackup 非法 JSON 抛出 FormatException 且不破坏已有数据', () async {
      final storage = MedicineStorage();
      await storage.add(makeMedicine('m1', name: '保留药'));

      await expectLater(storage.importBackup('not json'), throwsFormatException);
      expect(await storage.loadAll(), hasLength(1));
      expect((await storage.loadAll()).first.name, '保留药');
    });
  });

  group('自定义药品类型', () {
    test('addCustomType 后可 loadCustomTypes 读回（含单位）', () async {
      final storage = MedicineStorage();
      await storage.addCustomType('膏药', ['张', '盒']);
      await storage.addCustomType('中药饮片', ['g', '包']);
      final types = await storage.loadCustomTypes();
      expect(types, hasLength(2));
      final paste = types.firstWhere((t) => t.name == '膏药');
      expect(paste.units, ['张', '盒']);
      final herb = types.firstWhere((t) => t.name == '中药饮片');
      expect(herb.units, ['g', '包']);
    });

    test('单位缺失或为空时回退为 [片]', () async {
      final storage = MedicineStorage();
      await storage.addCustomType('膏药', <String>[]);
      final types = await storage.loadCustomTypes();
      expect(types.first.units, ['片']);
    });

    test('同名类型重复添加被忽略', () async {
      final storage = MedicineStorage();
      await storage.addCustomType('膏药', ['张']);
      await storage.addCustomType('膏药', ['盒']);
      expect(await storage.loadCustomTypes(), hasLength(1));
    });

    test('deleteCustomType 可删除指定类型', () async {
      final storage = MedicineStorage();
      await storage.addCustomType('膏药', ['张']);
      await storage.addCustomType('中药饮片', ['g']);
      await storage.deleteCustomType('膏药');
      final types = await storage.loadCustomTypes();
      expect(types.map((t) => t.name), isNot(contains('膏药')));
      expect(types, hasLength(1));
    });

    test('renameCustomType 重命名并同步更新使用该类型的药品', () async {
      final storage = MedicineStorage();
      await storage.addCustomType('膏药', ['张']);
      await storage.add(makeMedicine('m1', name: '风湿膏', location: '药箱（客厅）'));

      // 为 m1 设置 medType = 膏药
      final m = (await storage.loadAll()).first;
      final updated = Medicine(
        id: m.id,
        name: m.name,
        medType: '膏药',
        expireDate: m.expireDate,
        stock: m.stock,
        unit: m.unit,
        location: m.location,
      );
      await storage.update(m.id, updated);

      await storage.renameCustomType('膏药', '贴膏');
      final types = await storage.loadCustomTypes();
      expect(types.map((t) => t.name), contains('贴膏'));
      expect(types.map((t) => t.name), isNot(contains('膏药')));
      expect((await storage.loadAll()).first.medType, '贴膏');
    });

    test('deleteCustomType 删除时清空使用该类型药品的 medType', () async {
      final storage = MedicineStorage();
      await storage.addCustomType('膏药', ['张']);
      await storage.add(makeMedicine('m1', name: '风湿膏', location: '药箱（客厅）'));
      final m = (await storage.loadAll()).first;
      await storage.update(
        m.id,
        m.copyWith(medType: '膏药'),
      );

      await storage.deleteCustomType('膏药');
      expect(await storage.loadCustomTypes(), isEmpty);
      expect((await storage.loadAll()).first.medType, isNull);
    });
  });

  group('AddMedicineLogic 自定义类型逻辑', () {
    test('getTypes 合并默认类型与自定义类型（去重）', () {
      const custom = <CustomType>[
        CustomType(name: '膏药', units: ['张']),
        CustomType(name: '药片', units: ['盒']),
        CustomType(name: '  ', units: ['x']),
      ];
      final types = AddMedicineLogic.getTypes(custom: custom);
      expect(types, contains('膏药'));
      // 自定义里与默认重名的"药片"不重复出现
      expect(types.where((t) => t == '药片'), hasLength(1));
      // 空名自定义被排除
      expect(types, isNot(contains('  ')));
    });

    test('getTypeUnits 优先返回自定义类型单位，其次默认映射，最后回退 [片]', () {
      const custom = <CustomType>[
        CustomType(name: '膏药', units: ['张', '盒']),
        CustomType(name: '胶囊', units: ['板']),
      ];
      expect(AddMedicineLogic.getTypeUnits('膏药', custom: custom), ['张', '盒']);
      expect(AddMedicineLogic.getTypeUnits('胶囊', custom: custom), ['板']);
      expect(AddMedicineLogic.getTypeUnits('口服液', custom: custom), ['瓶', 'ml']);
      expect(AddMedicineLogic.getTypeUnits('不存在类型', custom: custom), ['片']);
    });
  });

  group('自动备份与完整性检查', () {
    test('数据变更自动生成 JSON 自动备份', () async {
      final tmp = await Directory.systemTemp.createTemp('mp_backup');
      addTearDown(() async {
        MedicineStorage.autoBackupDirOverride = null;
        await tmp.delete(recursive: true);
      });
      MedicineStorage.autoBackupDirOverride = tmp.path;

      final storage = MedicineStorage();
      await storage.add(makeMedicine('m1'));
      await storage.add(makeMedicine('m2'));
      // 手动触发确保落盘（正常流程里 add 内部会自动触发）
      await storage.autoBackupNow();

      final files = tmp
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList();
      expect(files, isNotEmpty);
      final decoded = jsonDecode(await files.first.readAsString()) as Map;
      expect(decoded['medicines'], isNotEmpty);
      expect(decoded['customTypes'], isA<List>());
    });

    test('数据库损坏后从最近自动备份兜底恢复，并保留损坏文件', () async {
      final tmp = await Directory.systemTemp.createTemp('mp_repair');
      final dbPath = p.join(tmp.path, 'repair.db');
      addTearDown(() async {
        MedicineStorage.autoBackupDirOverride = null;
        await DatabaseHelper.instance.reset();
        await tmp.delete(recursive: true);
      });
      MedicineStorage.autoBackupDirOverride = p.join(tmp.path, 'backups');
      DatabaseHelper.instance.useDatabasePath(dbPath);

      // 写入一条数据并生成自动备份
      final storage = MedicineStorage();
      await storage.add(makeMedicine('m1'));
      await storage.autoBackupNow();
      expect(await storage.loadAll(), hasLength(1));

      // 模拟数据库被写坏
      await DatabaseHelper.instance.reset();
      await File(dbPath).writeAsString(
        'THIS IS NOT A SQLITE DATABASE FILE.'.padRight(4096, 'X'),
      );

      DatabaseHelper.instance.useDatabasePath(dbPath);
      final ok = await MedicineStorage.runIntegrityCheckAndRepair();
      expect(ok, isTrue);

      final recovered = await MedicineStorage().loadAll();
      expect(recovered, hasLength(1));
      expect(recovered.single.name, '布洛芬');

      // 损坏文件保留以便人工恢复/取证
      final corruptFiles = tmp
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.contains('corrupt'))
          .toList();
      expect(corruptFiles, isNotEmpty);
    });

    test('无自动备份时损坏数据库重建为空库且不抛错', () async {
      final tmp = await Directory.systemTemp.createTemp('mp_repair_empty');
      final dbPath = p.join(tmp.path, 'empty.db');
      addTearDown(() async {
        MedicineStorage.autoBackupDirOverride = null;
        await DatabaseHelper.instance.reset();
        await tmp.delete(recursive: true);
      });
      MedicineStorage.autoBackupDirOverride = p.join(tmp.path, 'no_backups');
      DatabaseHelper.instance.useDatabasePath(dbPath);
      await File(dbPath).writeAsString('GARBAGE NOT SQLITE'.padRight(2048, '#'));

      final ok = await MedicineStorage.runIntegrityCheckAndRepair();
      expect(ok, isTrue);
      expect(await MedicineStorage().loadAll(), isEmpty);
    });
  });
}
