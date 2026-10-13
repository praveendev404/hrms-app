import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:workmanager/workmanager.dart';

import '../constants/api_endpoints.dart';
import '../constants/app_constants.dart';

/// What the user chose on the Reminders screen (kept on the phone only).
class ReminderSettings {
  final bool checkIn;
  final bool checkOut;
  final bool alerts;
  final TimeOfDayLite inTime;
  final TimeOfDayLite outTime;

  const ReminderSettings({
    this.checkIn = false,
    this.checkOut = false,
    this.alerts = false,
    this.inTime = const TimeOfDayLite(9, 30),
    this.outTime = const TimeOfDayLite(18, 30),
  });

  ReminderSettings copyWith({
    bool? checkIn,
    bool? checkOut,
    bool? alerts,
    TimeOfDayLite? inTime,
    TimeOfDayLite? outTime,
  }) =>
      ReminderSettings(
        checkIn: checkIn ?? this.checkIn,
        checkOut: checkOut ?? this.checkOut,
        alerts: alerts ?? this.alerts,
        inTime: inTime ?? this.inTime,
        outTime: outTime ?? this.outTime,
      );
}

class TimeOfDayLite {
  final int hour;
  final int minute;
  const TimeOfDayLite(this.hour, this.minute);

  String get label => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

const _kBackgroundTask = 'hrms.checkNotifications';
const _kLastSeenKey = 'reminder_last_notification_id';

/// Local reminders (check-in / check-out, weekdays) and a background check for new
/// notifications. There is no server push (FCM) for this app, so the background check
/// polls the notifications API about every 15 minutes while alerts are switched on.
class ReminderService {
  ReminderService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const _channel = AndroidNotificationDetails(
    'hrms_reminders',
    'Reminders and alerts',
    channelDescription: 'Check-in and check-out reminders and new HR notifications',
    importance: Importance.high,
    priority: Priority.high,
  );
  static const _details = NotificationDetails(android: _channel, iOS: DarwinNotificationDetails());

  static const _idIn = 1000; // + weekday (1..5)
  static const _idOut = 2000;

  static Future<void> init() async {
    if (_ready || kIsWeb) return;
    tzdata.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      // Falls back to UTC; reminders would then fire at the wrong hour, so say so in debug.
      debugPrint('ReminderService: could not read the phone time zone');
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    _ready = true;
  }

  /// Asks Android 13+ for the notification permission. True when allowed.
  static Future<bool> requestPermission() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) return await android.requestNotificationsPermission() ?? false;
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
  }

  static Future<ReminderSettings> load() async {
    final p = await SharedPreferences.getInstance();
    TimeOfDayLite t(String k, TimeOfDayLite d) {
      final v = p.getInt(k);
      return v == null ? d : TimeOfDayLite(v ~/ 60, v % 60);
    }

    const d = ReminderSettings();
    return ReminderSettings(
      checkIn: p.getBool('rem_in') ?? false,
      checkOut: p.getBool('rem_out') ?? false,
      alerts: p.getBool('rem_alerts') ?? false,
      inTime: t('rem_in_t', d.inTime),
      outTime: t('rem_out_t', d.outTime),
    );
  }

  /// Saves the choices and (re)schedules everything to match them.
  static Future<void> apply(ReminderSettings s) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('rem_in', s.checkIn);
    await p.setBool('rem_out', s.checkOut);
    await p.setBool('rem_alerts', s.alerts);
    await p.setInt('rem_in_t', s.inTime.hour * 60 + s.inTime.minute);
    await p.setInt('rem_out_t', s.outTime.hour * 60 + s.outTime.minute);

    await init();
    await _weekdays(_idIn, s.checkIn, s.inTime, 'Time to check in', 'Good morning. Mark your attendance for today.');
    await _weekdays(_idOut, s.checkOut, s.outTime, 'Time to check out', 'Wrapping up? Do not forget to check out.');
    await _setBackgroundCheck(s.alerts);
  }

  /// Called on logout: no reminders or background calls for a signed-out phone.
  static Future<void> stopAll() async {
    try {
      final p = await SharedPreferences.getInstance();
      for (final k in ['rem_in', 'rem_out', 'rem_alerts', _kLastSeenKey]) {
        await p.remove(k); // the switches go back to off, matching what is scheduled
      }
      await init();
      await _plugin.cancelAll();
      await Workmanager().cancelByUniqueName(_kBackgroundTask);
    } catch (_) {}
  }

  static Future<void> _weekdays(int baseId, bool on, TimeOfDayLite at, String title, String body) async {
    for (var day = DateTime.monday; day <= DateTime.friday; day++) {
      final id = baseId + day;
      await _plugin.cancel(id: id);
      if (!on) continue;
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: _next(day, at),
        notificationDetails: _details,
        // Inexact: no special "alarms & reminders" permission, may drift a few minutes.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  static tz.TZDateTime _next(int weekday, TimeOfDayLite at) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, at.hour, at.minute);
    while (t.weekday != weekday || !t.isAfter(now)) {
      t = t.add(const Duration(days: 1));
    }
    return t;
  }

  static Future<void> _setBackgroundCheck(bool on) async {
    if (!Platform.isAndroid) return;
    final wm = Workmanager();
    await wm.initialize(hrmsBackgroundDispatcher);
    if (!on) {
      await wm.cancelByUniqueName(_kBackgroundTask);
      return;
    }
    // Start from "now": only notifications that arrive after switching on are announced.
    final p = await SharedPreferences.getInstance();
    await p.remove(_kLastSeenKey);
    await wm.registerPeriodicTask(
      _kBackgroundTask,
      _kBackgroundTask,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
  }

  /// One pass of the background check (also usable from tests).
  static Future<void> checkForNewNotifications() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: AppConstants.authTokenKey);
    if (token == null || token.isEmpty) return; // signed out

    final dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: AppConstants.connectionTimeout,
      receiveTimeout: AppConstants.receiveTimeout,
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
    ));
    final r = await dio.post(ApiEndpoints.notificationsList, data: {
      'onlyUnread': true,
      'pageModel': {'startIndex': 0, 'pageSize': 20},
    });
    final list = ((r.data as Map<String, dynamic>)['list'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    if (list.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final lastSeen = prefs.getInt(_kLastSeenKey);
    final ids = list.map((e) => (e['id'] as num?)?.toInt() ?? 0).toList();
    final newest = ids.fold<int>(0, (m, v) => v > m ? v : m);
    await prefs.setInt(_kLastSeenKey, newest);
    if (lastSeen == null) return; // first pass only sets the baseline

    final fresh = list.where((e) => ((e['id'] as num?)?.toInt() ?? 0) > lastSeen).toList();
    if (fresh.isEmpty) return;

    await init();
    if (fresh.length == 1) {
      final n = fresh.first;
      await _plugin.show(
        id: 3000 + ((n['id'] as num?)?.toInt() ?? 0) % 1000,
        title: (n['title'] ?? 'HRMS').toString(),
        body: (n['message'] ?? '').toString(),
        notificationDetails: _details,
      );
    } else {
      await _plugin.show(
        id: 2999,
        title: 'HRMS',
        body: 'You have ${fresh.length} new notifications.',
        notificationDetails: _details,
      );
    }
  }
}

/// Entry point WorkManager calls in a fresh isolate.
@pragma('vm:entry-point')
void hrmsBackgroundDispatcher() {
  Workmanager().executeTask((task, input) async {
    try {
      await ReminderService.checkForNewNotifications();
      return true;
    } catch (_) {
      return true; // try again at the next scheduled run, no aggressive retry
    }
  });
}
