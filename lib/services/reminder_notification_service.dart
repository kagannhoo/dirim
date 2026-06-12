import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/health_reminder.dart';

class ReminderNotificationService {
  ReminderNotificationService._();
  static final ReminderNotificationService instance = ReminderNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _androidChannelId = 'dirim_health_reminders';
  static const _androidChannelName = 'Sağlık Hatırlatıcıları';
  static const _androidChannelDesc = 'İlaç, randevu ve sağlık kontrolü bildirimleri';

  static const _weekdayMap = {
    'pzt': DateTime.monday,
    'sal': DateTime.tuesday,
    'car': DateTime.wednesday,
    'per': DateTime.thursday,
    'cum': DateTime.friday,
    'cmt': DateTime.saturday,
    'paz': DateTime.sunday,
  };

  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    try {
      final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneInfo.identifier));
    } catch (e) {
      debugPrint('Saat dilimi ayarlanamadı, varsayılan kullanılıyor: $e');
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _androidChannelId,
          _androidChannelName,
          description: _androidChannelDesc,
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );
    }

    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    await initialize();

    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      await android?.requestExactAlarmsPermission();
      return granted ?? true;
    }

    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return true;
  }

  Future<bool> areNotificationsEnabled() async {
    await initialize();
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.areNotificationsEnabled() ?? true;
    }
    return true;
  }

  int _notificationId(String reminderId, int slot) {
    return '$reminderId-$slot'.hashCode & 0x7FFFFFFF;
  }

  NotificationDetails _details(ReminderType type, String body) {
    final color = type.color;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _androidChannelId,
        _androidChannelName,
        channelDescription: _androidChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: color,
        styleInformation: BigTextStyleInformation(body),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  String _buildBody(HealthReminder reminder, {bool isEarly = false}) {
    final buffer = StringBuffer();
    if (isEarly) {
      buffer.write('${reminder.notifyBeforeMinutes} dk sonra: ');
    }
    buffer.write(reminder.title);
    if (reminder.dosage != null && reminder.dosage!.isNotEmpty) {
      buffer.write(' · ${reminder.dosage}');
    }
    if (reminder.location != null && reminder.location!.isNotEmpty) {
      buffer.write('\n📍 ${reminder.location}');
    }
    if (reminder.doctorName != null && reminder.doctorName!.isNotEmpty) {
      buffer.write('\nDr. ${reminder.doctorName}');
    }
    if (reminder.description != null && reminder.description!.isNotEmpty) {
      buffer.write('\n${reminder.description}');
    }
    return buffer.toString();
  }

  String _titleFor(HealthReminder reminder, {bool isEarly = false}) {
    if (isEarly) return 'Yaklaşan ${reminder.type.label} Hatırlatıcısı';
    switch (reminder.type) {
      case ReminderType.medication:
        return '💊 İlaç Zamanı';
      case ReminderType.appointment:
        return '🏥 Randevu Hatırlatması';
      case ReminderType.checkup:
        return '❤️ Sağlık Kontrolü';
      case ReminderType.custom:
        return '🔔 Dirim Hatırlatıcı';
    }
  }

  tz.TZDateTime _applyNotifyBefore(tz.TZDateTime time, int minutes) {
    return time.subtract(Duration(minutes: minutes));
  }

  tz.TZDateTime _nextWeekdayTime(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    while (scheduled.weekday != weekday || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  Future<void> _scheduleAt({
    required int id,
    required HealthReminder reminder,
    required tz.TZDateTime scheduledDate,
    required bool isEarly,
    DateTimeComponents? matchComponents,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    if (matchComponents == null && scheduledDate.isBefore(now)) return;

    final body = _buildBody(reminder, isEarly: isEarly);
    final details = _details(reminder.type, body);

    await _plugin.zonedSchedule(
      id: id,
      title: _titleFor(reminder, isEarly: isEarly),
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: matchComponents,
    );
  }

  Future<void> cancelReminder(String reminderId) async {
    for (var slot = 0; slot < 20; slot++) {
      await _plugin.cancel(id: _notificationId(reminderId, slot));
    }
  }

  Future<void> scheduleReminder(HealthReminder reminder) async {
    if (!reminder.isActive) return;
    if (reminder.scheduledTime == null) return;

    await cancelReminder(reminder.id);

    final hour = reminder.scheduledTime!.hour;
    final minute = reminder.scheduledTime!.minute;
    var slot = 0;

    if (reminder.isRecurring && reminder.repeatDays.isNotEmpty) {
      for (final dayCode in reminder.repeatDays) {
        final weekday = _weekdayMap[dayCode];
        if (weekday == null) continue;

        final mainTime = _nextWeekdayTime(weekday, hour, minute);

        if (reminder.notifyBeforeMinutes > 0) {
          final earlyTime = _applyNotifyBefore(mainTime, reminder.notifyBeforeMinutes);
          if (earlyTime.isAfter(tz.TZDateTime.now(tz.local))) {
            await _scheduleAt(
              id: _notificationId(reminder.id, slot++),
              reminder: reminder,
              scheduledDate: earlyTime,
              isEarly: true,
              matchComponents: DateTimeComponents.dayOfWeekAndTime,
            );
          }
        }

        await _scheduleAt(
          id: _notificationId(reminder.id, slot++),
          reminder: reminder,
          scheduledDate: mainTime,
          isEarly: false,
          matchComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
      return;
    }

    // Tek seferlik veya günlük tekrar (tarih + saat)
    tz.TZDateTime mainTime;
    if (reminder.scheduledDate != null) {
      final d = reminder.scheduledDate!;
      mainTime = tz.TZDateTime(tz.local, d.year, d.month, d.day, hour, minute);
    } else {
      mainTime = _nextWeekdayTime(DateTime.now().weekday, hour, minute);
    }

    if (reminder.notifyBeforeMinutes > 0) {
      final earlyTime = _applyNotifyBefore(mainTime, reminder.notifyBeforeMinutes);
      if (earlyTime.isAfter(tz.TZDateTime.now(tz.local))) {
        await _scheduleAt(
          id: _notificationId(reminder.id, slot++),
          reminder: reminder,
          scheduledDate: earlyTime,
          isEarly: true,
        );
      }
    }

    await _scheduleAt(
      id: _notificationId(reminder.id, slot),
      reminder: reminder,
      scheduledDate: mainTime,
      isEarly: false,
    );
  }

  Future<void> syncReminders(List<HealthReminder> reminders) async {
    await initialize();

    for (final reminder in reminders) {
      await cancelReminder(reminder.id);
    }

    for (final reminder in reminders) {
      if (reminder.isActive) {
        try {
          await scheduleReminder(reminder);
        } catch (e) {
          debugPrint('Bildirim planlanamadı (${reminder.title}): $e');
        }
      }
    }
  }

  Future<void> syncFromSupabase() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final response = await Supabase.instance.client
          .from('health_reminders')
          .select()
          .eq('user_id', user.id);

      final reminders = (response as List)
          .map((e) => HealthReminder.fromMap(Map<String, dynamic>.from(e)))
          .toList();

      await syncReminders(reminders);
    } catch (e) {
      debugPrint('Supabase hatırlatıcı senkronizasyonu hatası: $e');
    }
  }
}
