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

  group('提醒窗口判断 shouldRemind', () {
    test('窗口内：到期当天(0)、临期(<=window)、已过期-1 天均应提醒', () {
      expect(NotificationService.shouldRemind(0, 7), isTrue);
      expect(NotificationService.shouldRemind(3, 7), isTrue);
      expect(NotificationService.shouldRemind(7, 7), isTrue);
      expect(NotificationService.shouldRemind(-1, 7), isTrue);
    });

    test('窗口外：尚未进入窗口(daysLeft>window) 不应提醒', () {
      expect(NotificationService.shouldRemind(8, 7), isFalse);
      expect(NotificationService.shouldRemind(30, 7), isFalse);
    });

    test('过期超过 1 天(daysLeft<-1) 不再提醒', () {
      expect(NotificationService.shouldRemind(-2, 7), isFalse);
      expect(NotificationService.shouldRemind(-60, 7), isFalse);
    });

    test('window=0 时仅到期当天(0)与刚过期(-1)提醒', () {
      expect(NotificationService.shouldRemind(0, 0), isTrue);
      expect(NotificationService.shouldRemind(-1, 0), isTrue);
      expect(NotificationService.shouldRemind(1, 0), isFalse);
      expect(NotificationService.shouldRemind(3, 0), isFalse);
    });
  });
}