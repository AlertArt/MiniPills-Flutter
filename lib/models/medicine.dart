// 药品数据模型 + add-medicine 页面纯业务逻辑
// 对应小程序 models/medicine.js

import 'dart:convert';
import 'dart:math';

/// 药品实体，对应数据库 medicines 表字段
class Medicine {
  final String id;
  final String? barcode;
  final String name;
  final String? spec;
  final String? manufacturer;
  final String? medType;
  final String? expireDate; // YYYY-MM-DD
  final int stock;
  final String? unit;
  final String? location;
  final List<String> images; // 多张图片路径

  const Medicine({
    required this.id,
    this.barcode,
    required this.name,
    this.spec,
    this.manufacturer,
    this.medType,
    this.expireDate,
    this.stock = 0,
    this.unit,
    this.location,
    this.images = const [],
  });

  /// 兼容旧数据：单张图片
  String? get image => images.isEmpty ? null : images.first;

  Medicine copyWith({
    String? id,
    String? barcode,
    String? name,
    String? spec,
    String? manufacturer,
    String? medType,
    String? expireDate,
    int? stock,
    String? unit,
    String? location,
    List<String>? images,
    bool clearBarcode = false,
    bool clearSpec = false,
    bool clearManufacturer = false,
    bool clearMedType = false,
    bool clearExpireDate = false,
    bool clearUnit = false,
    bool clearLocation = false,
    bool clearImage = false,
  }) {
    return Medicine(
      id: id ?? this.id,
      barcode: clearBarcode ? null : (barcode ?? this.barcode),
      name: name ?? this.name,
      spec: clearSpec ? null : (spec ?? this.spec),
      manufacturer: clearManufacturer ? null : (manufacturer ?? this.manufacturer),
      medType: clearMedType ? null : (medType ?? this.medType),
      expireDate: clearExpireDate ? null : (expireDate ?? this.expireDate),
      stock: stock ?? this.stock,
      unit: clearUnit ? null : (unit ?? this.unit),
      location: clearLocation ? null : (location ?? this.location),
      images: clearImage ? const [] : (images ?? this.images),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'barcode': barcode,
        'name': name,
        'spec': spec,
        'manufacturer': manufacturer,
        'medType': medType,
        'expire_date': expireDate,
        'stock': stock,
        'unit': unit,
        'location': location,
        if (images.isNotEmpty) 'images': images,
      };

  factory Medicine.fromJson(Map<String, dynamic> json) {
    List<String> images = [];
    final imgs = json['images'];
    if (imgs is List) {
      images = imgs.whereType<String>().toList();
    }
    // 兼容旧数据：仅有单张 image 字段
    final legacy = json['image'] as String?;
    if (images.isEmpty && legacy != null && legacy.isNotEmpty) {
      images = [legacy];
    }
    return Medicine(
      id: (json['id'] ?? '').toString(),
      barcode: json['barcode'] as String?,
      name: (json['name'] ?? '').toString(),
      spec: json['spec'] as String?,
      manufacturer: json['manufacturer'] as String?,
      medType: json['medType'] as String?,
      expireDate: json['expire_date'] as String?,
      stock: (json['stock'] is num) ? (json['stock'] as num).toInt() : (int.tryParse('${json['stock']}') ?? 0),
      unit: json['unit'] as String?,
      location: json['location'] as String?,
      images: images,
    );
  }
}

/// add-medicine 页面常量与纯业务方法
class AddMedicineLogic {
  static const List<String> medTypes = [
    '药片', '胶囊', '口服液', '颗粒剂', '软膏',
    '滴眼液', '喷雾剂', '注射液', '贴剂', '栓剂',
  ];

  static const Map<String, List<String>> typeUnits = {
    '药片': ['片'],
    '胶囊': ['粒'],
    '口服液': ['瓶', 'ml'],
    '颗粒剂': ['袋', '包'],
    '软膏': ['支'],
    '滴眼液': ['支', '瓶'],
    '喷雾剂': ['瓶'],
    '注射液': ['支', '瓶'],
    '贴剂': ['贴'],
    '栓剂': ['枚'],
  };

  /// 默认位置列表
  static const List<String> defaultLocations = [
    '药箱（客厅）', '药箱（厨房）', '冰箱', '卧室抽屉', '随身包', '办公室',
  ];

  /// 获取位置候选：默认位置 + 用户自定义记忆位置（去重）
  static List<String> getLocations({List<String> custom = const []}) {
    final result = <String>[...defaultLocations];
    for (final loc in custom) {
      final t = loc.trim();
      if (t.isNotEmpty && !result.contains(t)) {
        result.add(t);
      }
    }
    return result;
  }

  /// 校验药品必填字段。返回错误列表，空列表表示校验通过。
  static List<String> validateMedicine(Map<String, dynamic> data) {
    final errors = <String>[];
    final name = (data['name'] as String? ?? '').trim();
    if (name.isEmpty) {
      errors.add('药品名称不能为空');
    } else if (name.length > 200) {
      errors.add('药品名称不能超过200个字符');
    }

    final expire = data['expire_date'] as String?;
    if (expire == null || expire.isEmpty) {
      errors.add('有效期不能为空');
    } else if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(expire)) {
      errors.add('有效期格式不正确，应为 YYYY-MM-DD');
    } else if (DateTime.tryParse(expire) == null) {
      errors.add('有效期不是有效日期');
    }

    final stock = data['stock'];
    if (stock != null) {
      final n = stock is num ? stock.toInt() : int.tryParse('$stock');
      if (n == null || n < 0) {
        errors.add('库存不能为负数');
      }
    }

    final barcode = data['barcode'] as String?;
    if (barcode != null && barcode.length > 50) {
      errors.add('条形码不能超过50个字符');
    }
    final location = data['location'] as String?;
    if (location != null && location.length > 200) {
      errors.add('存放位置不能超过200个字符');
    }
    return errors;
  }

  /// 更新提交按钮状态
  static ({bool canSubmit, String submitText}) updateSubmitState({
    required String name,
    required String? expireDate,
  }) {
    final hasName = name.trim().isNotEmpty;
    final hasExpire = expireDate != null;
    return (
      canSubmit: hasName && hasExpire,
      submitText: hasName ? '确认添加' : '请填写药品信息',
    );
  }

  /// AI 识别结果回填表单
  static Map<String, dynamic> fillFormFromAi(Map<String, dynamic>? aiData) {
    final expire = aiData?['expire_date'] as String?;
    return {
      'name': aiData?['name'] as String? ?? '',
      'spec': aiData?['spec'] as String? ?? '',
      'manufacturer': aiData?['manufacturer'] as String? ?? '',
      'expireDate': (expire == null || expire.isEmpty) ? null : expire,
      'expireDateDisplay':
          (expire == null || expire.isEmpty) ? '' : expire.substring(0, expire.length >= 7 ? 7 : expire.length),
    };
  }

  /// 构建提交到存储的药品数据，并生成 id
  static Map<String, dynamic> buildSubmitData(Map<String, dynamic> data) => {
        'barcode': data['barcode'] as String?,
        'name': (data['name'] as String? ?? '').trim(),
        'spec': data['spec'] as String?,
        'manufacturer': data['manufacturer'] as String?,
        'medType': data['medType'] as String? ?? '',
        'expire_date': data['expireDate'],
        'stock': data['stock'] ?? 0,
        'unit': data['stockUnit'] as String? ?? '片',
        'location': data['location'] as String?,
        'images': data['images'] is List ? data['images'] : const [],
      };

  /// 生成唯一 id（对应 js 的 Date.now()+random）
  static final Random _random = Random();

  static String generateId() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = List.generate(6, (_) => chars[_random.nextInt(chars.length)]).join();
    return '${ts}_$rand';
  }
}

/// 便捷 JSON 编解码（保存列表时使用）
String encodeMedList(List<Medicine> list) =>
    jsonEncode(list.map((e) => e.toJson()).toList());

List<Medicine> decodeMedList(String source) {
  final data = jsonDecode(source);
  if (data is! List) return [];
  return data
      .whereType<Map>()
      .map((e) => Medicine.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}
