// 全局共享 Providers —— 使用 flutter_riverpod 轻量引入
// 集中提供：存储单例、药品列表状态、自定义位置状态。
// 页面通过 Consumer 组件消费，避免每页重复 new 实例。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/medicine.dart';
import 'services/medicine_storage.dart';

/// 共享的 MedicineStorage 单例（内部使用 DatabaseHelper.instance，跨页共用）。
final medicineRepositoryProvider = Provider<MedicineStorage>((ref) {
  return MedicineStorage();
});

/// 药品列表的响应式状态。
/// 数据变更（增/删/改/导入）后通过 [refreshMedicines] 更新。
final medicinesProvider = StateProvider<List<Medicine>>((ref) => []);

/// 自定义存放位置列表状态。
final locationsProvider = StateProvider<List<String>>((ref) => []);

/// 从数据库刷新药品列表状态。
Future<void> refreshMedicines(WidgetRef ref, {MedicineStorage? storage}) async {
  final repo = storage ?? ref.read(medicineRepositoryProvider);
  final items = await repo!.loadAll();
  // medicineRepositoryProvider 为顶层 Provider，存活于整个 ProviderScope 生命周期，
  // 因此 await 之后仍可安全更新 medicinesProvider。
  ref.read(medicinesProvider.notifier).state = items;
}

/// 从数据库刷新自定义位置状态，并注入到默认位置列表中（供各页共用）。
Future<List<String>> refreshLocations(WidgetRef ref, {MedicineStorage? storage}) async {
  final repo = storage ?? ref.read(medicineRepositoryProvider);
  final custom = await repo!.loadCustomLocations();
  final locs = AddMedicineLogic.getLocations(custom: custom);
  ref.read(locationsProvider.notifier).state = locs;
  return locs;
}
