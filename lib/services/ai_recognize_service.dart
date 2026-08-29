// AI 识别服务 —— 对应小程序 utils/ai.js / add-medicine.js
// 流程：图片 -> 压缩 -> base64 -> POST data:image/jpeg;base64,... 到 ai-recognize 云函数

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';

/// AI 识别结果
class AiResult {
  final String name;
  final String spec;
  final String expireDate; // YYYY-MM-DD，可为空字符串
  final String manufacturer;

  const AiResult({
    this.name = '',
    this.spec = '',
    this.expireDate = '',
    this.manufacturer = '',
  });

  factory AiResult.fromJson(Map<String, dynamic> json) => AiResult(
        name: json['name'] as String? ?? '',
        spec: json['spec'] as String? ?? '',
        expireDate: json['expire_date'] as String? ?? '',
        manufacturer: json['manufacturer'] as String? ?? '',
      );
}

class AiRecognizeService {
  /// 将图片路径读取为 base64（无扩展名时按 jpeg）
  Future<String> fileToBase64(String filePath) async {
    final isAsset = filePath.startsWith('assets/');
    final bytes = await _readBytes(filePath, isAsset);
    return base64Encode(bytes);
  }

  Future<Uint8List> _readBytes(String path, bool isAsset) async {
    if (isAsset) {
      return rootBundle.load(path).then((b) => b.buffer.asUint8List());
    }
    final file = File(path);
    return file.readAsBytes();
  }

  /// 压缩图片：文件 > 一定尺寸时用 Flutter 缩略（简化：直接截图重编码）
  /// Flutter 无内置 jpeg 压缩，这里保持原字节；如需压缩可引入 image 包。
  Future<Uint8List> _compress(Uint8List bytes) async {
    return bytes;
  }

  /// 识别药品：读取图片 -> base64 -> POST 到 ai-recognize
  /// [filePath] 图片本地路径或 assets 路径
  Future<AiResult> recognizeMedicine(
    String filePath, {
    String? urlOverride,
  }) async {
    final bytes = await _readBytes(filePath, filePath.startsWith('assets/'));
    final base64 = base64Encode(await _compress(bytes));

    final url = urlOverride ?? ApiConfig.aiRecognizeUrl;
    final response = await http
        .post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'image': 'data:image/jpeg;base64,$base64'}),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('网络请求失败，请检查网络连接 (${response.statusCode})');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw Exception('AI 识别失败');
    }
    if (decoded['success'] != true) {
      throw Exception(decoded['error'] ?? 'AI 识别失败');
    }
    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('AI 返回格式异常');
    }
    return AiResult.fromJson(data);
  }
}
