import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// 本地通知服务（Android 支持定时；Windows 支持即时 Toast，
/// 定时场景由应用内 ReminderEngine 兜底）。
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// 通知点击回调（由 HomeShell 注册，用于打开复盘编辑弹窗）。
  Future<void> Function(String? payload)? onNotificationTap;

  static const int idWaterImmediate = 101;
  static const int idWaterScheduled = 201;
  static const int idPostureImmediate = 102;
  static const int idPostureScheduled = 202;
  static const int idEntertainment = 300;
  static const int idCountdownImmediate = 400;
  static const int idCountdownScheduled = 401;
  static const int idSleepScheduled = 501;

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'time_block_channel',
      '时间区块记录器',
      channelDescription: '计时、身体与娱乐监控提醒',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
    ),
    windows: WindowsNotificationDetails(),
  );

  Future<void> init() async {
    tzdata.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      windows: WindowsInitializationSettings(
        appName: '时间区块记录器',
        appUserModelId: 'com.timeblock.time_block_recorder',
        guid: '7a2f1c3e-4b5d-4e6f-9a1b-2c3d4e5f6a7b',
      ),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        onNotificationTap?.call(response.payload);
      },
    );
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();
    _ready = true;
  }

  Future<void> show(int id, String title, String body) async {
    if (!_ready) return;
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _details,
    );
  }

  /// Android 上安排后台定时通知；其它平台由应用内引擎触发。
  Future<void> scheduleAt(
    int id,
    String title,
    String body,
    DateTime when,
  ) async {
    if (!_ready) return;
    if (when.isBefore(DateTime.now())) return;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(when.toUtc(), tz.UTC),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) {
      // 权限被拒绝或调度失败时静默失效，不打断业务流程
    }
  }

  Future<void> cancel(int id) async {
    if (!_ready) return;
    await _plugin.cancel(id: id);
  }

  /// 每天固定时刻的本地定时通知（仅 Android；其它平台由应用内引擎兜底）。
  Future<void> scheduleDaily(
    int id,
    String title,
    String body,
    int hour,
    int minute, {
    String? payload,
  }) async {
    if (!_ready) return;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;
    final now = DateTime.now();
    var when = DateTime(now.year, now.month, now.day, hour, minute);
    if (!when.isAfter(now)) when = when.add(const Duration(days: 1));
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(when.toUtc(), tz.UTC),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payload,
      );
    } catch (_) {
      // 权限被拒绝或调度失败时静默失效，不打断业务流程
    }
  }

  /// 应用由通知启动时读取携带的 payload（用于唤起复盘弹窗）。
  Future<String?> launchPayload() async {
    if (!_ready) return null;
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      return details?.notificationResponse?.payload;
    } catch (_) {
      return null;
    }
  }
}
