import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// تنبيه واحد: أذان، أو أذكار، أو ورد
class Alert {
  const Alert({required this.id, required this.at, required this.title, required this.body, this.adhan = false});

  final int id;
  final DateTime at;
  final String title;
  final String body;

  /// يشغّل صوت الأذان مش صوت التنبيه العادي
  final bool adhan;
}

/// الإشعارات على كل الأنظمة.
///
/// أندرويد: النظام بيجدول الإشعارات بنفسه (حتى والتطبيق مقفول) وبيشغّل الأذان
/// كصوت الإشعار. ويندوز والويب: التطبيق نفسه بيطلع الإشعار ويشغّل الأذان في
/// وقته، فلازم يكون شغال (ولو متصغّر).
class Notifier {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static bool get _android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// النظام بيجدول التنبيهات بنفسه
  bool get osScheduling => _android;

  Future<void> init() async {
    try {
      _ready = await _plugin.initialize(
            settings: const InitializationSettings(
              android: AndroidInitializationSettings('@mipmap/ic_launcher'),
              windows: WindowsInitializationSettings(
                appName: 'إذاعة أذكار المسلم',
                appUserModelId: 'AzkarElMuslim.Radio',
                guid: '6d2c1f3e-8f47-4b8e-9a51-2f0a7c3d9b14',
              ),
              linux: LinuxInitializationSettings(defaultActionName: 'فتح'),
            ),
          ).timeout(const Duration(seconds: 8)) ??
          false;
    } catch (e) {
      debugPrint('notifications init failed: $e');
    }
  }

  /// لازم تتنادى من ضغطة زرار (المتصفح بيرفض لو الطلب جه لوحده)
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    try {
      if (kIsWeb) {
        final web = _plugin.resolvePlatformSpecificImplementation<WebFlutterLocalNotificationsPlugin>();
        return await web?.requestNotificationsPermission() ?? false;
      }
      if (_android) {
        final a = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        final ok = await a?.requestNotificationsPermission() ?? false;
        if (await a?.canScheduleExactNotifications() == false) await a?.requestExactAlarmsPermission();
        return ok;
      }
      return true;
    } catch (e) {
      debugPrint('notifications permission failed: $e');
      return false;
    }
  }

  static const _adhanDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'adhan_v1',
      'الأذان',
      channelDescription: 'الأذان في مواقيت الصلاة',
      importance: Importance.max,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound('adhan'),
      audioAttributesUsage: AudioAttributesUsage.alarm,
      category: AndroidNotificationCategory.alarm,
    ),
    windows: WindowsNotificationDetails(),
    web: WebNotificationDetails(requireInteraction: true),
  );

  static const _reminderDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'reminders_v1',
      'الأذكار والورد',
      channelDescription: 'تذكير بأذكار الصباح والمساء والورد اليومي',
      importance: Importance.high,
      priority: Priority.high,
    ),
    windows: WindowsNotificationDetails(),
    web: WebNotificationDetails(),
  );

  /// أندرويد: بنمسح القديم ونجدول الأيام الجاية كلها
  Future<void> schedule(List<Alert> alerts) async {
    if (!_ready || !osScheduling) return;
    try {
      await _plugin.cancelAll();
      final a = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final exact = await a?.canScheduleExactNotifications() ?? false;
      final now = DateTime.now();
      for (final alert in alerts) {
        if (!alert.at.isAfter(now)) continue;
        await _plugin.zonedSchedule(
          id: alert.id,
          title: alert.title,
          body: alert.body,
          scheduledDate: tz.TZDateTime.from(alert.at, tz.UTC),
          notificationDetails: alert.adhan ? _adhanDetails : _reminderDetails,
          androidScheduleMode: exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (e) {
      debugPrint('notifications schedule failed: $e');
    }
  }

  /// ويندوز والويب: التطبيق بيطلع الإشعار بنفسه في وقته
  Future<void> showNow(Alert alert) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id: alert.id,
        title: alert.title,
        body: alert.body,
        notificationDetails: alert.adhan ? _adhanDetails : _reminderDetails,
      );
    } catch (e) {
      debugPrint('notification failed: $e');
    }
  }
}
