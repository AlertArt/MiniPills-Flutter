// SQLite 数据库助手 —— MiniPills 主存储（替换 shared_preferences 的 JSON 全量读写）
// 提供药品表 + 自定义位置表，并在首次启动时从旧 shared_preferences 数据一次性迁移。

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import '../models/medicine.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper _instance = DatabaseHelper._();

  static DatabaseHelper get instance => _instance;

  static const String _dbName = 'minipills.db';
  static const int _dbVersion = 1;

  static const String medicinesTable = 'medicines';
  static const String customLocationsTable = 'custom_locations';

  Database? _db;

  /// 测试可注入的数据库路径（如内存库），为空时使用真实文件路径
  String? _overridePath;

  @visibleForTesting
  void useDatabasePath(String path) {
    _overridePath = path;
  }

  /// 测试用：关闭当前连接并清空路径，使下次调用重新打开数据库
  @visibleForTesting
  Future<void> reset() async {
    await _db?.close();
    _db = null;
    _overridePath = null;
  }

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final path = _overridePath ?? p.join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $medicinesTable (
        id TEXT PRIMARY KEY,
        barcode TEXT,
        name TEXT NOT NULL,
        spec TEXT,
        manufacturer TEXT,
        medType TEXT,
        expire_date TEXT,
        stock INTEGER NOT NULL DEFAULT 0,
        unit TEXT,
        location TEXT,
        images TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE $customLocationsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // 预留升级钩子
  }

  /// 将 Medicine 写入行数据（images 存为 JSON 字符串）
  Map<String, dynamic> medicineToRow(Medicine m) => {
        'id': m.id,
        'barcode': m.barcode,
        'name': m.name,
        'spec': m.spec,
        'manufacturer': m.manufacturer,
        'medType': m.medType,
        'expire_date': m.expireDate,
        'stock': m.stock,
        'unit': m.unit,
        'location': m.location,
        'images': m.images.isEmpty ? null : jsonEncode(m.images),
      };

  /// 将行数据还原为 Medicine
  Medicine rowToMedicine(Map<String, dynamic> row) {
    final imagesJson = row['images'] as String?;
    List<String> images = [];
    if (imagesJson != null && imagesJson.isNotEmpty) {
      try {
        images = List<String>.from(jsonDecode(imagesJson) as List);
      } catch (_) {
        images = [];
      }
    }
    return Medicine(
      id: row['id'] as String,
      barcode: row['barcode'] as String?,
      name: row['name'] as String,
      spec: row['spec'] as String?,
      manufacturer: row['manufacturer'] as String?,
      medType: row['medType'] as String?,
      expireDate: row['expire_date'] as String?,
      stock: row['stock'] as int? ?? 0,
      unit: row['unit'] as String?,
      location: row['location'] as String?,
      images: images,
    );
  }
}
