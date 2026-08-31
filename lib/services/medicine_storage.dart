// 本地存储服务 —— 对应小程序 wx.getStorageSync('medList')
// 使用 SQLite（sqflite）持久化，首次启动从旧 shared_preferences JSON 数据一次性迁移。

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../models/medicine.dart';
import 'database_helper.dart';

class MedicineStorage {
  static const String _legacyKey = 'medList';

  /// 自定义存放位置列表的存储 key（旧 shared_preferences 数据）
  static const String _customLocationsKey = 'customLocations';

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
  }

  static Future<void> clearAll() async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(DatabaseHelper.medicinesTable);
  }
}
