import 'category.dart';
import 'day_mode.dart';

class AppSettings {
  AppSettings({
    required this.workdayTargets,
    required this.restdayTargets,
    required this.weeklyGoals,
    required this.waterEnabled,
    required this.waterIntervalMin,
    required this.entertainmentEnabled,
    required this.entertainmentApps,
    required this.themeMode,
    required this.lastWaterMs,
    required this.postureThresholdSec,
    required this.sleepReminderEnabled,
    required this.sleepReminderHour,
    required this.sleepReminderMinute,
  });

  /// 工作日 / 休息日每日目标时长（分钟），key 为分类 code。
  Map<String, int> workdayTargets;
  Map<String, int> restdayTargets;

  /// 周目标（四大分类每周总时长，分钟）。
  Map<String, int> weeklyGoals;

  /// 喝水提醒。
  bool waterEnabled;
  int waterIntervalMin;

  /// 娱乐监控。
  bool entertainmentEnabled;
  List<String> entertainmentApps;

  /// 主题：light / dark / system。
  String themeMode;

  /// 上次喝水提醒触发时间戳（毫秒）。
  int lastWaterMs;

  /// 起身活动提醒阈值（秒），默认 50 分钟。
  int postureThresholdSec;

  /// 每日睡觉提醒。
  bool sleepReminderEnabled;
  int sleepReminderHour;
  int sleepReminderMinute;

  /// 每日目标上限：一天 24 小时 = 1440 分钟。
  static const int maxDailyTotalMin = 24 * 60;

  /// 每周目标上限：7 天 × 24 小时 = 10080 分钟。
  static const int maxWeeklyTotalMin = 7 * 24 * 60;

  factory AppSettings.createDefault() => AppSettings(
    workdayTargets: {
      AppCategory.workStudy.code: 480,
      AppCategory.freeRecovery.code: 120,
      AppCategory.entertainment.code: 90,
      AppCategory.sleep.code: 480,
      AppCategory.other.code: 30,
    },
    restdayTargets: {
      AppCategory.workStudy.code: 180,
      AppCategory.freeRecovery.code: 240,
      AppCategory.entertainment.code: 180,
      AppCategory.sleep.code: 540,
      AppCategory.other.code: 60,
    },
    weeklyGoals: {
      AppCategory.workStudy.code: 2400,
      AppCategory.freeRecovery.code: 1200,
      AppCategory.entertainment.code: 900,
      AppCategory.sleep.code: 3360,
      AppCategory.other.code: 300,
    },
    waterEnabled: true,
    waterIntervalMin: 60,
    entertainmentEnabled: true,
    entertainmentApps: [
      '抖音',
      '快手',
      'B站',
      '王者荣耀',
      'Steam',
      'com.ss.android.ugc.aweme',
      'com.smile.gifmaker',
      'tv.danmaku.bili',
      'com.tencent.tmgp.sgame',
    ],
    themeMode: 'system',
    lastWaterMs: 0,
    postureThresholdSec: 3000,
    sleepReminderEnabled: false,
    sleepReminderHour: 23,
    sleepReminderMinute: 0,
  );

  int targetMinutes(String categoryCode, DayMode mode) {
    final map = switch (mode) {
      DayMode.workday => workdayTargets,
      DayMode.restday => restdayTargets,
      DayMode.emergency => const <String, int>{},
    };
    return map[categoryCode] ?? 0;
  }

  void setTarget(String categoryCode, DayMode mode, int minutes) {
    final map = switch (mode) {
      DayMode.workday => workdayTargets,
      DayMode.restday => restdayTargets,
      DayMode.emergency => null,
    };
    if (map != null) map[categoryCode] = minutes;
  }

  /// 某模式下每日目标合计（分钟）。
  int dailyTotalMin(DayMode mode) {
    final map = switch (mode) {
      DayMode.workday => workdayTargets,
      DayMode.restday => restdayTargets,
      DayMode.emergency => const <String, int>{},
    };
    return map.values.fold(0, (sum, v) => sum + v);
  }

  /// 每周目标合计（分钟）。
  int weeklyTotalMin() => weeklyGoals.values.fold(0, (sum, v) => sum + v);

  /// 某分类在某模式下可设置的最大分钟数（全天合计不超过 24 小时）。
  int maxDailyMinutes(String categoryCode, DayMode mode) {
    final map = switch (mode) {
      DayMode.workday => workdayTargets,
      DayMode.restday => restdayTargets,
      DayMode.emergency => const <String, int>{},
    };
    final others = map.entries
        .where((e) => e.key != categoryCode)
        .fold<int>(0, (sum, e) => sum + e.value);
    final allowed = maxDailyTotalMin - others;
    return allowed < 0 ? 0 : allowed;
  }

  /// 某分类周目标可设置的最大分钟数（每周合计不超过 168 小时）。
  int maxWeeklyMinutes(String categoryCode) {
    final others = weeklyGoals.entries
        .where((e) => e.key != categoryCode)
        .fold<int>(0, (sum, e) => sum + e.value);
    final allowed = maxWeeklyTotalMin - others;
    return allowed < 0 ? 0 : allowed;
  }

  Map<String, dynamic> toJson() => {
    'workdayTargets': workdayTargets,
    'restdayTargets': restdayTargets,
    'weeklyGoals': weeklyGoals,
    'waterEnabled': waterEnabled,
    'waterIntervalMin': waterIntervalMin,
    'entertainmentEnabled': entertainmentEnabled,
    'entertainmentApps': entertainmentApps,
    'themeMode': themeMode,
    'lastWaterMs': lastWaterMs,
    'postureThresholdSec': postureThresholdSec,
    'sleepReminderEnabled': sleepReminderEnabled,
    'sleepReminderHour': sleepReminderHour,
    'sleepReminderMinute': sleepReminderMinute,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final defaults = AppSettings.createDefault();
    Map<String, int> readIntMap(dynamic value) => {
      for (final e in (value as Map?)?.entries ?? <MapEntry>[])
        if (e.value is num) e.key.toString(): (e.value as num).toInt(),
    };
    List<String> readStrList(dynamic value) => ((value as List?) ?? const [])
        .map((e) => e.toString())
        .where((e) => e.trim().isNotEmpty)
        .toList();
    final theme = (json['themeMode'] ?? '').toString();
    return AppSettings(
      workdayTargets: {
        ...defaults.workdayTargets,
        ...readIntMap(json['workdayTargets']),
      },
      restdayTargets: {
        ...defaults.restdayTargets,
        ...readIntMap(json['restdayTargets']),
      },
      weeklyGoals: {
        ...defaults.weeklyGoals,
        ...readIntMap(json['weeklyGoals']),
      },
      waterEnabled: (json['waterEnabled'] ?? defaults.waterEnabled) == true,
      waterIntervalMin:
          (json['waterIntervalMin'] as num?)?.toInt() ??
          defaults.waterIntervalMin,
      entertainmentEnabled:
          (json['entertainmentEnabled'] ?? defaults.entertainmentEnabled) ==
          true,
      entertainmentApps: readStrList(json['entertainmentApps']),
      themeMode: theme.isEmpty ? defaults.themeMode : theme,
      lastWaterMs: (json['lastWaterMs'] as num?)?.toInt() ?? 0,
      postureThresholdSec:
          (json['postureThresholdSec'] as num?)?.toInt() ?? 3000,
      sleepReminderEnabled:
          (json['sleepReminderEnabled'] ?? defaults.sleepReminderEnabled) ==
          true,
      sleepReminderHour:
          (json['sleepReminderHour'] as num?)?.toInt() ??
          defaults.sleepReminderHour,
      sleepReminderMinute:
          (json['sleepReminderMinute'] as num?)?.toInt() ??
          defaults.sleepReminderMinute,
    );
  }
}
