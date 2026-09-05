// 本地存储服务 —— 对应小程序 wx.getStorageSync('medList')
// 使用 SQLite（sqflite）持久化，首次启动从旧 shared_preferences JSON 数据一次性迁移。
// 每次数据变更自动生成 JSON 自动备份（防误删/损坏），启动时做完整性检查并自动兜底恢复。

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../models/medicine.dart';
import 'database_helper.dart';
import 'notification_service.dart';

class MedicineStorage {
  static const String _legacyKey = 'medList';

  /// 自定义存放位置列表的存储 key（旧 shared_preferences 数据）
  static const String _customLocationsKey = 'customLocations';

  /// 自动备份存放目录名（位于应用文档目录下）
  static const String _autoBackupDirName = 'auto_backups';

  /// 自动备份保留数量上限（超出清理最旧的）
  static const int _maxAutoBackups = 12;

  /// 测试可注入的自动备份目录（为空时使用应用文档目录）
  @visibleForTesting
  static String? autoBackupDirOverride;

  final DatabaseHelper _db = DatabaseHelper.instance;

  bool _migrated = false;

  /// 执行一次性迁移：从旧 shared_preferences 导入药品与自定义位置（仅一次）
  Future<void> _migrateIfNeeded() async {
    if (_migrated) return;
    _migrated = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_legacyKey);
      if (raw != null && raw.isNotEmpty) {
        final oldList = decodeMedList(raw);
        final db = await _db.database;
        final batch = db.batch();
        for (final m in oldList) {
          batch.insert(
            DatabaseHelper.medicinesTable,
            _db.medicineToRow(m),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
        await prefs.remove(_legacyKey);
      }

      final oldCustom = prefs.getStringList(_customLocationsKey);
      if (oldCustom != null && oldCustom.isNotEmpty) {
        final db = await _db.database;
        final batch = db.batch();
        for (final loc in oldCustom) {
          batch.insert(
            DatabaseHelper.customLocationsTable,
            {'name': loc.trim()},
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
        await batch.commit(noResult: true);
        await prefs.remove(_customLocationsKey);
      }
    } catch (_) {
      // 迁移失败不阻塞应用，下次启动重试
      _migrated = false;
    }
  }

  /// 读取自定义存放位置列表
  Future<List<String>> loadCustomLocations() async {
    await _migrateIfNeeded();
    final db = await _db.database;
    final rows = await db.query(
      DatabaseHelper.customLocationsTable,
      columns: ['name'],
      orderBy: 'id ASC',
    );
    return rows.map((r) => r['name'] as String).toList();
  }

  /// 保存自定义存放位置（记忆列表，含默认位置时去重显示在 UI 层）
  Future<void> addCustomLocation(String location) async {
    final t = location.trim();
    if (t.isEmpty) return;
    await _migrateIfNeeded();
    final db = await _db.database;
    await db.insert(
      DatabaseHelper.customLocationsTable,
      {'name': t},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// 读取全部自定义药品类型（类型名 + 对应单位列表）
  Future<List<CustomType>> loadCustomTypes() async {
    await _migrateIfNeeded();
    final db = await _db.database;
    final rows = await db.query(
      DatabaseHelper.customTypesTable,
      orderBy: 'id ASC',
    );
    final result = <CustomType>[];
    for (final row in rows) {
      final name = (row['name'] as String?)?.trim() ?? '';
      if (name.isEmpty) continue;
      List<String> units = [];
      final unitsRaw = row['units'] as String?;
      if (unitsRaw != null && unitsRaw.isNotEmpty) {
        try {
          units = List<String>.from(jsonDecode(unitsRaw) as List)
              .map((e) => (e as String?)?.trim() ?? '')
              .where((e) => e.isNotEmpty)
              .toList();
        } catch (_) {
          units = [];
        }
      }
      result.add(CustomType(name: name, units: units));
    }
    return result;
  }

  /// 新增自定义药品类型。类型名重复时忽略；[units] 为空则回退 ['片']。
  Future<void> addCustomType(String name, List<String> units) async {
    final t = name.trim();
    if (t.isEmpty) return;
    final cleanUnits = (units.isEmpty ? ['片'] : units)
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (cleanUnits.isEmpty) {
      cleanUnits.add('片');
    }
    await _migrateIfNeeded();
    final db = await _db.database;
    await db.insert(
      DatabaseHelper.customTypesTable,
      {'name': t, 'units': jsonEncode(cleanUnits)},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// 读取药品列表
  Future<List<Medicine>> loadAll() async {
    await _migrateIfNeeded();
    final db = await _db.database;
    final rows = await db.query(
      DatabaseHelper.medicinesTable,
      orderBy: 'id ASC',
    );
    return rows.map(_db.rowToMedicine).toList();
  }

  /// SQL 下推查询：按存放位置 / 名称关键字过滤（WHERE 下推），降低内存过滤开销。
  /// [location] 非空时过滤存放位置；[keyword] 非空时按名称模糊搜索。
  /// 排序仍由上层按"到期阶段"进行，因此此处仅为过滤下推。
  Future<List<Medicine>> queryMedicines({
    String? location,
    String? keyword,
    String? expireBefore, // YYYY-MM-DD，仅返回到期日在此之前（含）的药品
  }) async {
    await _migrateIfNeeded();
    final db = await _db.database;
    final where = <String>[];
    final args = <Object?>[];
    if (location != null && location.isNotEmpty) {
      where.add('location = ?');
      args.add(location);
    }
    if (keyword != null && keyword.trim().isNotEmpty) {
      where.add('name LIKE ?');
      args.add('%${keyword.trim()}%');
    }
    if (expireBefore != null && expireBefore.isNotEmpty) {
      where.add('expire_date IS NOT NULL AND expire_date <= ?');
      args.add(expireBefore);
    }
    final rows = await db.query(
      DatabaseHelper.medicinesTable,
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'expire_date ASC',
    );
    return rows.map(_db.rowToMedicine).toList();
  }

  /// 按条形码精确查找药品（追溯复用：同一条码的既往录入）。
  /// 返回最新录入的一条；未找到返回 null。
  Future<Medicine?> findByBarcode(String barcode) async {
    final code = barcode.trim();
    if (code.isEmpty) return null;
    await _migrateIfNeeded();
    final db = await _db.database;
    final rows = await db.query(
      DatabaseHelper.medicinesTable,
      where: 'barcode = ?',
      whereArgs: [code],
      orderBy: 'rowid DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _db.rowToMedicine(rows.first);
  }

  /// 保存完整列表（全量替换：清空后重写）
  Future<void> saveAll(List<Medicine> list) async {
    await _migrateIfNeeded();
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.delete(DatabaseHelper.medicinesTable);
      final batch = txn.batch();
      for (final m in list) {
        batch.insert(
          DatabaseHelper.medicinesTable,
          _db.medicineToRow(m),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
    _afterChange();
  }

  /// 新增药品
  Future<void> add(Medicine medicine) async {
    await _migrateIfNeeded();
    final db = await _db.database;
    await db.insert(
      DatabaseHelper.medicinesTable,
      _db.medicineToRow(medicine),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _afterChange();
  }

  /// 按 id 更新
  Future<Medicine?> update(String id, Medicine updated) async {
    await _migrateIfNeeded();
    final db = await _db.database;
    final n = await db.update(
      DatabaseHelper.medicinesTable,
      _db.medicineToRow(updated),
      where: 'id = ?',
      whereArgs: [id],
    );
    if (n == 0) return null;
    _afterChange();
    return updated;
  }

  /// 按 id 删除
  Future<void> delete(String id) async {
    await _migrateIfNeeded();
    final db = await _db.database;
    await db.delete(
      DatabaseHelper.medicinesTable,
      where: 'id = ?',
      whereArgs: [id],
    );
    _afterChange();
  }

  /// 导出 JSON 备份：包含全部药品、自定义位置与自定义类型
  Future<String> exportBackup() async {
    final items = await loadAll();
    final custom = await loadCustomLocations();
    final customTypes = await loadCustomTypes();
    return jsonEncode({
      'version': 2,
      'app': 'MiniPills',
      'exported_at': DateTime.now().toIso8601String(),
      'medicines': items.map((e) => e.toJson()).toList(),
      'customLocations': custom,
      'customTypes': customTypes.map((e) => e.toMap()).toList(),
    });
  }

  /// 从 JSON 备份字符串恢复数据（全量替换已有药品、自定义位置与自定义类型）。
  /// 返回 (药品数, 位置数, 类型数)。
  Future<({int medicines, int locations, int types})> importBackup(String source) async {
    final data = jsonDecode(source);
    if (data is! Map) throw const FormatException('无效的备份文件格式');
    final rawMeds = data['medicines'];
    final rawLocs = data['customLocations'];
    final rawTypes = data['customTypes'];
    if (rawMeds is! List) throw const FormatException('备份缺少 medicines 字段');

    await _migrateIfNeeded();
    final medicines = <Medicine>[];
    for (final e in rawMeds) {
      if (e is Map) {
        medicines.add(Medicine.fromJson(Map<String, dynamic>.from(e)));
      }
    }

    final locations = <String>[];
    if (rawLocs is List) {
      for (final l in rawLocs) {
        if (l is String && l.trim().isNotEmpty) {
          locations.add(l.trim());
        }
      }
    }

    final customTypes = <CustomType>[];
    if (rawTypes is List) {
      for (final t in rawTypes) {
        if (t is Map) {
          final ct = CustomType.fromMap(Map<String, dynamic>.from(t));
          if (ct.name.trim().isNotEmpty) {
            customTypes.add(ct);
          }
        }
      }
    }

    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.delete(DatabaseHelper.medicinesTable);
      await txn.delete(DatabaseHelper.customLocationsTable);
      await txn.delete(DatabaseHelper.customTypesTable);
      final batch = txn.batch();
      for (final m in medicines) {
        batch.insert(
          DatabaseHelper.medicinesTable,
          _db.medicineToRow(m),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final loc in locations) {
        batch.insert(
          DatabaseHelper.customLocationsTable,
          {'name': loc},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      for (final ct in customTypes) {
        batch.insert(
          DatabaseHelper.customTypesTable,
          {'name': ct.name, 'units': jsonEncode(ct.units)},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await batch.commit(noResult: true);
    });
    _afterChange();
    return (
      medicines: medicines.length,
      locations: locations.length,
      types: customTypes.length,
    );
  }

  /// 重命名自定义类型，并同步更新使用该类型的所有药品
  Future<void> renameCustomType(String oldName, String newName) async {
    final t = newName.trim();
    if (t.isEmpty) return;
    await _migrateIfNeeded();
    final db = await _db.database;
    await db.transaction((txn) async {
      // 类型表自身更新
      await txn.update(
        DatabaseHelper.customTypesTable,
        {'name': t},
        where: 'name = ?',
        whereArgs: [oldName],
      );
      // 同步更新使用该类型的所有药品
      await txn.update(
        DatabaseHelper.medicinesTable,
        {'medType': t},
        where: 'medType = ?',
        whereArgs: [oldName],
      );
    });
  }

  /// 删除自定义类型。当类型被药品使用时，将该药品的 medType 置空（视为未设置），避免残留失效类型引用。
  Future<void> deleteCustomType(String name) async {
    await _migrateIfNeeded();
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.delete(
        DatabaseHelper.customTypesTable,
        where: 'name = ?',
        whereArgs: [name],
      );
      await txn.update(
        DatabaseHelper.medicinesTable,
        {'medType': null},
        where: 'medType = ?',
        whereArgs: [name],
      );
    });
  }

  /// 数据变更后的统一收尾：异步重建到期提醒 + 异步生成自动备份（均不阻塞主流程）
  void _afterChange() {
    unawaited(_rescheduleNotifications());
    unawaited(_autoBackupNow());
  }

  /// 立即执行一次自动备份（内部由数据变更自动触发，公开供测试/手动调用）。
  /// 生成 JSON 备份到自动备份目录，并清理超出上限的旧备份。失败静默忽略。
  Future<void> autoBackupNow() => _autoBackupNow();

  Future<void> _autoBackupNow() async {
    try {
      final dir = await _autoBackupDir();
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      while (files.length >= _maxAutoBackups) {
        try {
          await files.removeAt(0).delete();
        } catch (_) {}
      }
      final json = await exportBackup();
      final target = File(p.join(dir.path, _autoBackupFileName(DateTime.now())));
      await target.writeAsString(json, flush: true);
    } catch (_) {
      // 自动备份失败不影响主流程
    }
  }

  static String _autoBackupFileName(DateTime now) {
    String two(int v) => v.toString().padLeft(2, '0');
    String three(int v) => v.toString().padLeft(3, '0');
    return 'minipills_auto_${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}_'
        '${three(now.millisecond)}.json';
  }

  static Future<Directory> _autoBackupDir() async {
    final override = autoBackupDirOverride;
    if (override != null && override.isNotEmpty) {
      return Directory(override);
    }
    final docs = await getApplicationDocumentsDirectory();
    return Directory(p.join(docs.path, _autoBackupDirName));
  }

  /// 最新一份自动备份的文件路径（按文件名时间戳倒序取最新）；无则返回 null。
  static Future<String?> _latestAutoBackupPath() async {
    try {
      final dir = await _autoBackupDir();
      if (!await dir.exists()) return null;
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path));
      if (files.isEmpty) return null;
      return files.first.path;
    } catch (_) {
      return null;
    }
  }

  /// 启动时数据安全兜底：检测数据库完整性，损坏则保留损坏文件、从最近自动备份恢复。
  /// 返回整体是否处理完成（不抛错）；未损坏时直接返回 true。
  static Future<bool> runIntegrityCheckAndRepair() async {
    final helper = DatabaseHelper.instance;
    try {
      final db = await helper.database;
      final rows = await db.rawQuery('PRAGMA quick_check');
      final ok = rows.isNotEmpty && '${rows.first.values.first}' == 'ok';
      if (ok) return true;
    } catch (_) {
      // 打开失败也视为损坏，进入修复
    }
    return _repairCorruptDatabase(helper);
  }

  static Future<bool> _repairCorruptDatabase(DatabaseHelper helper) async {
    try {
      await helper.forceClose();
      final path = await helper.filePath();
      if (path != ':memory:' && path.isNotEmpty) {
        final file = File(path);
        if (await file.exists()) {
          final corruptPath =
              '$path.corrupt.${DateTime.now().millisecondsSinceEpoch}.db';
          await file.rename(corruptPath); // 保留损坏文件便于取证，再重建新库
        }
      }
      final latest = await _latestAutoBackupPath();
      if (latest != null) {
        final src = await File(latest).readAsString();
        await MedicineStorage().importBackup(src);
      } else {
        // 无自动备份：打开全新空库继续使用
        await DatabaseHelper.instance.database;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 数据变更后异步重建到期提醒通知（不阻塞主流程）
  Future<void> _rescheduleNotifications() async {
    try {
      final items = await loadAll();
      await NotificationService.instance.rescheduleAll(items);
    } catch (_) {
      // 通知失败不影响数据操作
    }
  }

  /// 公开的提醒重建入口（供设置变更后主动调用）
  Future<void> rescheduleNotifications() => _rescheduleNotifications();

  /// 启动时初始化通知服务并请求权限（含首次调度）
  static Future<void> initNotifications() async {
    final service = NotificationService.instance;
    await service.init();
    await service.requestPermissions();
    final items = await MedicineStorage().loadAll();
    await service.rescheduleAll(items);
  }

  static Future<void> clearAll() async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(DatabaseHelper.medicinesTable);
  }
}
