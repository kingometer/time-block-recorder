import 'app_settings.dart';
import 'category.dart';
import 'day_meta.dart';
import 'event_item.dart';
import 'time_record.dart';
import '../utils/format.dart';

class AppData {
  AppData({
    required this.events,
    required this.records,
    required this.dayMetas,
    required this.settings,
    this.schemaVersion = 2,
  });

  List<EventItem> events;
  List<TimeRecord> records;

  /// 按日期（yyyy-MM-dd）索引的每日附加信息。
  Map<String, DayMeta> dayMetas;
  AppSettings settings;
  int schemaVersion;

  /// 首次启动的默认数据：内置初始事件、默认每日/周目标。
  factory AppData.createDefault() {
    final now = DateTime.now();
    final events = <EventItem>[];
    void add(String cat, String name) => events.add(
      EventItem(id: newId(), name: name, categoryCode: cat, createdAt: now),
    );
    for (final n in ['上课', '学C语言', 'STM32项目调试', '写作业']) {
      add(AppCategory.workStudy.code, n);
    }
    for (final n in ['弹吉他', '看书', '健身运动', '散步']) {
      add(AppCategory.freeRecovery.code, n);
    }
    for (final n in ['打游戏', '刷短视频']) {
      add(AppCategory.entertainment.code, n);
    }
    add(AppCategory.sleep.code, '夜间睡眠');
    return AppData(
      events: events,
      records: [],
      dayMetas: {},
      settings: AppSettings.createDefault(),
    );
  }

  /// 导入合并：
  /// - 事件按 id 覆盖（导入文件优先）；
  /// - 计时记录按 id / (eventId, 开始时间) 去重，更新时间戳更新的记录覆盖旧的；
  /// - 每日备注/复盘/手动模式按日期合并，导入文件的非空字段优先；
  /// - 各类目标与设置以导入文件为准。
  void mergeFrom(AppData incoming) {
    final eventMap = {for (final e in events) e.id: e};
    for (final e in incoming.events) {
      eventMap[e.id] = e;
    }
    events
      ..clear()
      ..addAll(eventMap.values)
      ..sort((a, b) {
        final c = a.createdAt.compareTo(b.createdAt);
        return c != 0 ? c : a.name.compareTo(b.name);
      });

    final byId = <String, TimeRecord>{for (final r in records) r.id: r};
    final byKey = <String, TimeRecord>{
      for (final r in records) '${r.eventId}|${r.startMs}': r,
    };
    for (final r in incoming.records) {
      final existing = byId[r.id];
      if (existing != null) {
        if (r.createdAtMs >= existing.createdAtMs) {
          byId[r.id] = r;
          byKey['${r.eventId}|${r.startMs}'] = r;
        }
      } else {
        final key = '${r.eventId}|${r.startMs}';
        final same = byKey[key];
        if (same == null || r.createdAtMs >= same.createdAtMs) {
          byKey[key] = r;
          byId[r.id] = r;
        }
      }
    }
    records
      ..clear()
      ..addAll(byId.values)
      ..sort((a, b) => b.startMs.compareTo(a.startMs));

    final mergedMetas = {for (final m in dayMetas.values) m.date: m};
    incoming.dayMetas.forEach((date, meta) {
      final cur = mergedMetas[date];
      if (cur == null) {
        mergedMetas[date] = meta;
      } else {
        mergedMetas[date] = DayMeta(
          date: date,
          modeOverride: (meta.modeOverride?.isNotEmpty ?? false)
              ? meta.modeOverride
              : cur.modeOverride,
          note: meta.note.isNotEmpty ? meta.note : cur.note,
          review: meta.review.isNotEmpty ? meta.review : cur.review,
        );
      }
    });
    dayMetas
      ..clear()
      ..addAll(mergedMetas);

    settings.workdayTargets = {...incoming.settings.workdayTargets};
    settings.restdayTargets = {...incoming.settings.restdayTargets};
    settings.weeklyGoals = {...incoming.settings.weeklyGoals};
    settings.waterEnabled = incoming.settings.waterEnabled;
    settings.waterIntervalMin = incoming.settings.waterIntervalMin;
    settings.entertainmentEnabled = incoming.settings.entertainmentEnabled;
    settings.entertainmentApps = [...incoming.settings.entertainmentApps];
    settings.themeMode = incoming.settings.themeMode;
    if (incoming.settings.lastWaterMs > 0) {
      settings.lastWaterMs =
          settings.lastWaterMs > 0 &&
              settings.lastWaterMs < incoming.settings.lastWaterMs
          ? settings.lastWaterMs
          : incoming.settings.lastWaterMs;
    }
    settings.postureThresholdSec = incoming.settings.postureThresholdSec;
    settings.sleepReminderEnabled = incoming.settings.sleepReminderEnabled;
    settings.sleepReminderHour = incoming.settings.sleepReminderHour;
    settings.sleepReminderMinute = incoming.settings.sleepReminderMinute;
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'settings': settings.toJson(),
    'events': events.map((e) => e.toJson()).toList(),
    'records': records.map((r) => r.toJson()).toList(),
    'dayMetas': dayMetas.values.map((m) => m.toJson()).toList(),
  };

  factory AppData.fromJson(Map<String, dynamic> json) {
    final events = ((json['events'] as List?) ?? const [])
        .map((e) => EventItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    final records = ((json['records'] as List?) ?? const [])
        .map((r) => TimeRecord.fromJson((r as Map).cast<String, dynamic>()))
        .toList();
    final dayMetas = <String, DayMeta>{};
    for (final m in ((json['dayMetas'] as List?) ?? const [])) {
      final meta = DayMeta.fromJson((m as Map).cast<String, dynamic>());
      dayMetas[meta.date] = meta;
    }
    final settings = json['settings'] is Map
        ? AppSettings.fromJson(
            (json['settings'] as Map).cast<String, dynamic>(),
          )
        : AppSettings.createDefault();
    return AppData(
      events: events,
      records: records,
      dayMetas: dayMetas,
      settings: settings,
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
    );
  }
}
