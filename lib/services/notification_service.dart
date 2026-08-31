// 药品到期提醒通知服务
// 使用 flutter_local_notifications + timezone 调度本地通知。
// 每次药品数据变更后调用 rescheduleAll() 重建到期提醒。

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/medicine.dart';

/// 到期提醒：在到期前 [reminderDays] 天内，每天提醒一次。
/// 即将到期（0 天后到期）与已到期各提醒一次。
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// 到期前多少天开始提醒（含当天）
  static const int reminderDays = 7;

  static const String _channelId = 'expiry_reminder';
  static const String _channelName = '药品到期提醒';

  /// 初始化插件、申请权限、设置时区。
  Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    try {
      await _plugin.initialize(settings: initSettings);
      _initialized = true;
    } catch (_) {
      // 初始化失败（如测试环境）不阻塞应用
    }
  }

  /// 请求通知权限（Android 13+ 需要运行时权限）。
  Future<void> requestPermissions() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (_) {}
  }

  /// 根据全部药品重建到期提醒（先清空旧的，再按需调度）。
  Future<void> rescheduleAll(List<Medicine> items) async {
    await init();
    await _cancelAll();
    if (items.isEmpty) return;

    var index = 0;
    for (final m in items) {
      final date = _parseExpire(m.expireDate);
      if (date == null) continue;
      final daysLeft = _daysUntil(date);
      if (daysLeft < -1) continue; // 已过期超过 1 天不再提醒

      final title = '药品到期提醒';
      final body = _buildBody(m, daysLeft);
      await _scheduleDaily(index++, title, body);
    }
  }

  String _buildBody(Medicine m, int daysLeft) {
    final when = daysLeft < 0
        ? '已于 ${_fmt(m.expireDate!)} 到期'
        : (daysLeft == 0 ? '今天到期' : '还有 $daysLeft 天到期');
    final name = m.name.isEmpty ? '药品' : m.name;
    final pos = (m.location != null && m.location!.isNotEmpty) ? '，位于「${m.location}」' : '';
    return '$name$when$pos，请及时服用或处理。';
  }

  Future<void> _scheduleDaily(int id, String title, String body) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: '药品到期前提醒',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(),
    );

    // 每天提醒一次：已过期 → 明天 9:00；即将到期 → 每天 9:00 直到到期日
    try {
      final now = tz.TZDateTime.now(tz.local);
      var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 9);
      if (!scheduled.isAfter(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
      await _plugin.zonedSchedule(
        id: _idFor(id),
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) {
      // 单个调度失败不影响其它
    }
  }

  int _idFor(int index) => 1000 + index;

  Future<void> _cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  static DateTime? _parseExpire(String? s) {
    if (s == null || s.isEmpty) return null;
    final dt = DateTime.tryParse(s);
    if (dt == null) return null;
    return DateTime(dt.year, dt.month, dt.day);
  }

  static int _daysUntil(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return date.difference(today).inDays;
  }

  static String _fmt(String s) {
    if (s.length >= 7) return s.substring(0, 7);
    return s;
  }
}
