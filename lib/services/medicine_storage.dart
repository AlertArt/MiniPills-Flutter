// 本地存储服务 —— 对应小程序 wx.getStorageSync('medList')
// 使用 shared_preferences 进行 json 持久化

import 'package:shared_preferences/shared_preferences.dart';
import '../models/medicine.dart';

class MedicineStorage {
  static const String _key = 'medList';

  /// 自定义存放位置列表的存储 key
  static const String _customLocationsKey = 'customLocations';

  /// 读取自定义存放位置列表
  Future<List<String>> loadCustomLocations() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_customLocationsKey) ?? <String>[];
  }

  /// 保存自定义存放位置（记忆列表，含默认位置时去重显示在 UI 层）
  Future<void> addCustomLocation(String location) async {
    final t = location.trim();
    if (t.isEmpty) return;
    final list = await loadCustomLocations();
    if (list.contains(t)) return;
    list.add(t);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_customLocationsKey, list);
  }

  /// 读取药品列表
  Future<List<Medicine>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return decodeMedList(raw);
    } catch (_) {
      // 损坏数据时安全降级
      return [];
    }
  }

  /// 保存完整列表
  Future<void> saveAll(List<Medicine> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, encodeMedList(list));
  }

  /// 新增药品
  Future<void> add(Medicine medicine) async {
    final list = await loadAll();
    list.add(medicine);
    await saveAll(list);
  }

  /// 按 id 更新
  Future<Medicine?> update(String id, Medicine updated) async {
    final list = await loadAll();
    final idx = list.indexWhere((m) => m.id == id);
    if (idx == -1) return null;
    list[idx] = updated;
    await saveAll(list);
    return updated;
  }

  /// 按 id 删除
  Future<void> delete(String id) async {
    final list = await loadAll();
    list.removeWhere((m) => m.id == id);
    await saveAll(list);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
