// 药品条码联网查询服务 —— 扫码自动追溯的远程数据源
// 流程：GET {url}?barcode=<code> -> 解析返回的名称/品牌/厂商/规格/图片。
// URL 与 Key 默认取 ApiConfig，可在 App 内"药品查询 API 设置"中覆盖（持久化到 shared_preferences）。

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_config.dart';

/// 联网查询到的药品信息
class MedicineLookupResult {
  final bool found;
  final String name;
  final String brand;
  final String manufacturer;
  final String spec;
  final String image;

  const MedicineLookupResult({
    required this.found,
    this.name = '',
    this.brand = '',
    this.manufacturer = '',
    this.spec = '',
    this.image = '',
  });
}

/// 用户可在设置中覆盖的联网查询配置
class LookupSettings {
  final String url;
  final String key;

  const LookupSettings({required this.url, required this.key});
}

class BarcodeLookupService {
  BarcodeLookupService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  // shared_preferences 的持久化键
  static const String _urlKey = 'lookupApiUrl';
  static const String _keyKey = 'lookupApiKey';

  Future<LookupSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_urlKey)?.trim() ?? ApiConfig.barcodeLookupUrl;
    final key = prefs.getString(_keyKey)?.trim() ?? ApiConfig.barcodeLookupKey;
    return LookupSettings(url: url, key: key);
  }

  Future<void> saveSettings({required String url, required String key}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_urlKey, url.trim());
    await prefs.setString(_keyKey, key.trim());
  }

  bool isConfigured(LookupSettings settings) {
    final url = settings.url.trim();
    return url.isNotEmpty &&
        !url.contains('your-medicine-lookup.example.com') &&
        !url.contains('your-project.functions.supabase.co');
  }

  /// 联网查询药品信息。未配置有效数据源时抛出 StateError（由调用方降级）。
  /// 数据源未命中时返回 found=false。
  Future<MedicineLookupResult> lookup(
    String barcode, {
    LookupSettings? settingsOverride,
  }) async {
    final code = barcode.trim();
    if (code.isEmpty) return const MedicineLookupResult(found: false);

    final settings = settingsOverride ?? await loadSettings();
    if (!isConfigured(settings)) {
      throw StateError('未配置药品查询 API');
    }

    final uri = Uri.parse(settings.url).replace(queryParameters: {'barcode': code});
    final headers = <String, String>{'Accept': 'application/json'};
    if (settings.key.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${settings.key}';
    }

    final response = await _client
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('药品查询失败 (${response.statusCode})');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw Exception('药品查询返回格式异常');
    }
    final data = decoded['data'] ?? decoded;
    if (data is! Map<String, dynamic>) {
      throw Exception('药品查询返回格式异常');
    }
    if (data['found'] == false) {
      return const MedicineLookupResult(found: false);
    }
    return MedicineLookupResult(
      found: true,
      name: (data['name'] as String?) ?? '',
      brand: (data['brand'] as String?) ?? '',
      manufacturer: (data['manufacturer'] as String?) ?? '',
      spec: (data['spec'] as String?) ?? '',
      image: (data['image'] as String?) ?? '',
    );
  }
}
