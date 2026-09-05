// BarcodeLookupService 单元测试：联网追溯解析、配置判断、设置持久化
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:minipills_flutter/services/barcode_lookup_service.dart';

void main() {
  final mockFound = MockClient((request) async {
    return http.Response(
      jsonEncode({
        'code': 0,
        'data': {
          'barcode': '6921168509256',
          'found': true,
          'name': '农夫山泉 饮用天然水550ml',
          'brand': '农夫山泉',
          'manufacturer': '农夫山泉股份有限公司',
          'spec': '550ml',
          'image': 'https://img/water.png',
        },
      }),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });

  group('lookup', () {
    test('命中时正确解析名称/品牌/厂商/规格/图片', () async {
      final svc = BarcodeLookupService(client: mockFound);
      final settings = const LookupSettings(
        url: 'https://v1.apizero.cn/api/barcode-lookup',
        key: '',
      );
      final res = await svc.lookup('6921168509256', settingsOverride: settings);
      expect(res.found, isTrue);
      expect(res.name, '农夫山泉 饮用天然水550ml');
      expect(res.brand, '农夫山泉');
      expect(res.manufacturer, '农夫山泉股份有限公司');
      expect(res.spec, '550ml');
      expect(res.image, 'https://img/water.png');
    });

    test('数据源未命中时返回 found=false 且字段为空', () async {
      final mockMiss = MockClient((request) async {
        return http.Response(
          jsonEncode({'code': 0, 'data': {'found': false}}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final svc = BarcodeLookupService(client: mockMiss);
      final res = await svc.lookup(
        '6921168509999',
        settingsOverride: const LookupSettings(url: 'https://x/api', key: ''),
      );
      expect(res.found, isFalse);
      expect(res.name, isEmpty);
    });

    test('未配置有效数据源时抛出 StateError', () async {
      final svc = BarcodeLookupService(client: mockFound);
      // 占位地址视为未配置
      final settings = const LookupSettings(
        url: 'https://your-medicine-lookup.example.com/api/barcode-lookup',
        key: '',
      );
      expect(
        () => svc.lookup('6921168509256', settingsOverride: settings),
        throwsStateError,
      );
    });

    test('空条形码直接返回 found=false 且不发起请求', () async {
      var called = false;
      final spy = MockClient((request) async {
        called = true;
        return http.Response('{}', 200);
      });
      final svc = BarcodeLookupService(client: spy);
      final res = await svc.lookup(
        '   ',
        settingsOverride: const LookupSettings(url: 'https://x/api', key: ''),
      );
      expect(res.found, isFalse);
      expect(called, isFalse);
    });
  });

  group('设置持久化', () {
    test('saveSettings 后可 loadSettings 读回', () async {
      SharedPreferences.setMockInitialValues({});
      final svc = BarcodeLookupService(client: mockFound);
      await svc.saveSettings(
        url: 'https://v1.apizero.cn/api/barcode-lookup',
        key: 'secret-key',
      );
      final settings = await svc.loadSettings();
      expect(settings.url, 'https://v1.apizero.cn/api/barcode-lookup');
      expect(settings.key, 'secret-key');
    });

    test('isConfigured 判断占位地址为未配置，默认真实接口为已配置', () async {
      final svc = BarcodeLookupService(client: mockFound);
      expect(
        svc.isConfigured(
          const LookupSettings(
            url: 'https://your-medicine-lookup.example.com/api/barcode-lookup',
            key: '',
          ),
        ),
        isFalse,
      );
      expect(
        svc.isConfigured(const LookupSettings(url: 'https://v1.apizero.cn/api/barcode-lookup', key: '')),
        isTrue,
      );
    });
  });

  group('联网追溯缓存', () {
    test('命中进程内缓存时不再发起网络请求', () async {
      var calls = 0;
      final spy = MockClient((request) async {
        calls++;
        return http.Response(
          jsonEncode({
            'code': 0,
            'data': {'found': true, 'name': '缓存药', 'brand': 'B'},
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      SharedPreferences.setMockInitialValues({});
      final svc = BarcodeLookupService(client: spy);
      final settings = const LookupSettings(url: 'https://x/api', key: '');
      final first = await svc.lookup('6900001', settingsOverride: settings);
      expect(first.found, isTrue);
      expect(calls, 1);

      final second = await svc.lookup('6900001', settingsOverride: settings);
      expect(second.name, '缓存药');
      expect(calls, 1, reason: '第二次命中缓存，不重复请求');
    });

    test('命中 shared_preferences 持久化缓存时不发起网络请求', () async {
      var calls = 0;
      final spy = MockClient((request) async {
        calls++;
        return http.Response('{}', 200);
      });
      final prefs = <String, Object>{
        'lookupCache_6900002':
            '{"found":true,"name":"持久化药","brand":"X","manufacturer":"","spec":"","image":""}',
      };
      SharedPreferences.setMockInitialValues(prefs);
      final svc = BarcodeLookupService(client: spy);
      final res = await svc.lookup(
        '6900002',
        settingsOverride: const LookupSettings(url: 'https://x/api', key: ''),
      );
      expect(res.found, isTrue);
      expect(res.name, '持久化药');
      expect(calls, 0);
    });

    test('未命中缓存时才发起网络请求并回写缓存', () async {
      var calls = 0;
      final spy = MockClient((request) async {
        calls++;
        return http.Response(
          jsonEncode({
            'code': 0,
            'data': {'found': true, 'name': '新药', 'brand': 'N'},
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      SharedPreferences.setMockInitialValues({});
      final svc = BarcodeLookupService(client: spy);
      final res = await svc.lookup(
        '6900003',
        settingsOverride: const LookupSettings(url: 'https://x/api', key: ''),
      );
      expect(calls, 1);
      expect(res.name, '新药');
      // 缓存已写入 prefs
      final cached = await SharedPreferences.getInstance();
      expect(cached.getString('lookupCache_6900003'), contains('新药'));
    });

    test('clearCache 清空进程内存后仍命中持久化缓存，不重复请求', () async {
      var calls = 0;
      final spy = MockClient((request) async {
        calls++;
        return http.Response(
          jsonEncode({
            'code': 0,
            'data': {'found': true, 'name': '药', 'brand': 'B'},
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      SharedPreferences.setMockInitialValues({});
      final svc = BarcodeLookupService(client: spy);
      final settings = const LookupSettings(url: 'https://x/api', key: '');
      await svc.lookup('6900004', settingsOverride: settings);
      expect(calls, 1);

      svc.clearCache(); // 仅清空进程内缓存
      final res = await svc.lookup('6900004', settingsOverride: settings);
      expect(res.found, isTrue);
      expect(calls, 1, reason: '持久化缓存仍命中，不再发起网络请求');
    });
  });
}
