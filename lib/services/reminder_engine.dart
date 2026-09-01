import 'dart:io' show Platform;
import 'dart:async';

import '../models/category.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import 'notification_service.dart';

/// 应用运行期间的提醒引擎：休息喝水提醒（所有模式）、
/// 工作学习连续 50 分钟起身活动提醒（其他模式同样生效）。
class ReminderEngine {
  ReminderEngine(this._state);

  final AppState _state;
  Timer? _timer;
  String? _lastSleepShownDate;

  void start() {
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _tick());
    _tick();
  }

  Future<void> _tick() async {
    await _checkWater();
    await _checkPosture();
    await _checkSleep();
  }

  Future<void> _checkWater() async {
    final s = _state.data.settings;
    if (!s.waterEnabled) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (s.lastWaterMs <= 0) {
      _state.markWaterFired(now);
      _state.scheduleWaterAlarm();
      return;
    }
    if (now - s.lastWaterMs >= s.waterIntervalMin * 60000) {
      _state.markWaterFired(now);
      _state.scheduleWaterAlarm();
      await NotificationService.instance.show(
        NotificationService.idWaterImmediate,
        '休息喝水提醒',
        '连续工作这么久，该休息一下喝杯水啦 💧',
      );
    }
  }

  Future<void> _checkPosture() async {
    final t = _state.session;
    if (t == null ||
        !t.running ||
        t.event.categoryCode != AppCategory.workStudy.code) {
      return;
    }
    if (t.elapsedRunningSec >= _state.postureThresholdSec) {
      _state.advancePostureThreshold();
      await NotificationService.instance.show(
        NotificationService.idPostureImmediate,
        '起身活动提醒',
        '已连续专注 50 分钟，请起身活动一下腰部～',
      );
    }
  }

  /// 每日睡觉提醒：Android 由本地定时通知触发；Windows 等平台在应用内兜底触发。
  Future<void> _checkSleep() async {
    if (Platform.isAndroid) return;
    final s = _state.data.settings;
    if (!s.sleepReminderEnabled) return;
    final now = DateTime.now();
    if (now.hour != s.sleepReminderHour ||
        now.minute != s.sleepReminderMinute) {
      return;
    }
    final key = dateKey(now);
    if (_lastSleepShownDate == key) return;
    _lastSleepShownDate = key;
    await NotificationService.instance.show(
      NotificationService.idSleepScheduled,
      '睡觉提醒',
      '该睡觉了，请完成今日复盘。',
    );
  }

  void dispose() {
    _timer?.cancel();
  }
}
