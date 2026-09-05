// NotificationService 到期提醒天数设置的单元测试
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:minipills_flutter/services/notification_service.dart';

void main() {
  group('到期提醒天数设置', () {
    test('默认提醒天数为 7', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await NotificationService.instance.loadReminderDays(), 7);
    });

    test('保存后可读回，且读回值被限制到 0~30', () async {
      SharedPreferences.setMockInitialValues({});
      final svc = NotificationService.instance;
      await svc.saveReminderDays(3);
      expect(await svc.loadReminderDays(), 3);

      await svc.saveReminderDays(-5);
      expect(await svc.loadReminderDays(), 0);

      await svc.saveReminderDays(99);
      expect(await svc.loadReminderDays(), 30);
    });

    test('constructor default 与 0 均保留', () async {
      SharedPreferences.setMockInitialValues({});
      final svc = NotificationService.instance;
      await svc.saveReminderDays(0);
      expect(await svc.loadReminderDays(), 0);
      expect(NotificationService.defaultReminderDays, 7);
    });
  });
}