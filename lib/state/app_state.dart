import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/app_data.dart';
import '../models/category.dart';
import '../models/day_meta.dart';
import '../models/day_mode.dart';
import '../models/event_item.dart';
import '../models/planned_entry.dart';
import '../models/time_record.dart';
import '../models/timer_snapshot.dart';
import '../services/import_export.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../utils/format.dart';

/// 全局导航 key，供非 Widget 环境（如娱乐提醒弹窗）使用。
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// 计时会话：支持正计时与倒计时。
class TimerSession {
  TimerSession({
    required this.event,
    required this.countdown,
    required this.estimateSec,
    required this.startedAt,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final EventItem event;

  /// true=倒计时（设置预估时长），false=正计时。
  final bool countdown;
  final int estimateSec;
  final DateTime startedAt;
  final DateTime Function() _now;

  int baseRunningMs = 0;
  int pausedMs = 0;
  DateTime? lastResumeAt;
  DateTime? pausedAt;
  bool running = false;

  /// 倒计时自然结束（等待用户确认保存）。
  bool finished = false;

  void start() {
    lastResumeAt = _now();
    running = true;
  }

  void pause() {
    if (!running) return;
    final now = _now();
    baseRunningMs += now.difference(lastResumeAt!).inMilliseconds;
    pausedAt = now;
    lastResumeAt = null;
    running = false;
  }

  void resume() {
    if (running) return;
    if (pausedAt != null) {
      pausedMs += _now().difference(pausedAt!).inMilliseconds;
      pausedAt = null;
    }
    lastResumeAt = _now();
    running = true;
  }

  int get elapsedRunningMs =>
      baseRunningMs +
      (running && lastResumeAt != null
          ? _now().difference(lastResumeAt!).inMilliseconds
          : 0);

  int get elapsedRunningSec => elapsedRunningMs ~/ 1000;

  /// 暂停累计毫秒（含当前暂停段）。
  int get pausedTotalMs =>
      pausedMs +
      (pausedAt != null ? _now().difference(pausedAt!).inMilliseconds : 0);

  int get remainingMs =>
      countdown ? math.max(0, estimateSec * 1000 - elapsedRunningMs) : 0;

  int get remainingSec => remainingMs ~/ 1000;

  int get wallMs => _now().difference(startedAt).inMilliseconds;

  /// 从持久化快照恢复为运行中状态。
  void restoreRunning({
    required int accumulatedRunningMs,
    required int accumulatedPausedMs,
    required DateTime at,
  }) {
    baseRunningMs = accumulatedRunningMs;
    pausedMs = accumulatedPausedMs;
    lastResumeAt = at;
    running = true;
  }

  /// 从持久化快照恢复为暂停状态。
  void restorePaused({
    required int accumulatedRunningMs,
    required int accumulatedPausedMs,
    required DateTime at,
  }) {
    baseRunningMs = accumulatedRunningMs;
    pausedMs = accumulatedPausedMs;
    pausedAt = at;
    running = false;
  }
}

/// 某一天的有效统计汇总（该日存在事件记录）。
class DaySummary {
  DaySummary({required this.date, required this.totals});

  final DateTime date;

  /// 该日各大类累计秒数（分类 code -> 秒）。
  final Map<String, int> totals;

  int get totalSec => totals.values.fold<int>(0, (sum, v) => sum + v);
}

/// 周统计结果（今天向前 7 天；只统计有事件记录的有效日期）。
class WeekStats {
  DateTime weekStart = DateTime.now();
  DateTime weekEnd = DateTime.now();
  final Map<String, int> workdayTotals = {};
  final Map<String, int> restdayTotals = {};
  final Map<String, int> weekTotals = {};
  final List<DateTime> emergencyDays = [];
  final List<DaySummary> activeDays = [];
  int workdayCount = 0;
  int restdayCount = 0;
  int activeDayCount = 0;

  /// 是否存在有效记录日期。
  bool get hasRecords => activeDays.isNotEmpty;

  /// 总时长（秒）= 全部有效日期事件时长之和。
  int get totalSec => weekTotals.values.fold<int>(0, (sum, v) => sum + v);

  /// 日均时长（秒）= 总时长 / 有效记录天数；无有效日期返回 0，防止除以 0。
  int get averageSec => activeDayCount > 0 ? totalSec ~/ activeDayCount : 0;
}

class AppState extends ChangeNotifier {
  AppState({required AppData initialData, required this.storage})
    : data = initialData;

  final AppData data;
  final StorageService storage;
  TimerSession? session;
  Timer? _ticker;

  int _postureThresholdSec = 3000;

  // ---------- 日期模式 ----------
  bool get isTodayWorkday => isWorkday(DateTime.now());

  DayMode modeForDate(DateTime date) {
    final meta = data.dayMetas[dateKey(date)];
    return meta?.resolve() ?? DayMode.defaultFor(date);
  }

  DayMode get modeForToday => modeForDate(DateTime.now());

  DayMeta? metaFor(DateTime date) => data.dayMetas[dateKey(date)];

  DayMeta _metaOrCreate(DateTime date) => data.dayMetas.putIfAbsent(
    dateKey(date),
    () => DayMeta(date: dateKey(date)),
  );

  /// 访问某一天：不存在日期记录时当场创建空白记录（不预生成未来日期）。
  DayMeta dayMetaFor(DateTime date) {
    final key = dateKey(date);
    final existing = data.dayMetas[key];
    if (existing != null) return existing;
    final meta = DayMeta(date: key);
    data.dayMetas[key] = meta;
    _save();
    return meta;
  }

  void setDayModeOverride(DateTime date, DayMode mode) {
    final meta = _metaOrCreate(date);
    meta.modeOverride = mode.code;
    _saveAndNotify();
    _syncWaterAlarm();
  }

  void clearDayModeOverride(DateTime date) {
    final key = dateKey(date);
    final meta = data.dayMetas[key];
    if (meta != null) {
      meta.modeOverride = null;
      if (meta.note.isEmpty && meta.review.isEmpty) data.dayMetas.remove(key);
    }
    _saveAndNotify();
    _syncWaterAlarm();
  }

  void setDayNote(DateTime date, String text) {
    _metaOrCreate(date).note = text.trim();
    _saveAndNotify();
  }

  void setDayReview(DateTime date, String text) {
    _metaOrCreate(date).review = text.trim();
    _saveAndNotify();
  }

  // ---------- 查询 ----------
  List<EventItem> eventsOf(AppCategory category) =>
      data.events.where((e) => e.categoryCode == category.code).toList();

  EventItem? eventById(String id) {
    for (final e in data.events) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// 收藏优先的选择列表。
  List<EventItem> sortedEvents() {
    final list = [...data.events]
      ..sort((a, b) {
        if (a.favorite != b.favorite) return a.favorite ? -1 : 1;
        final c = a.categoryCode.compareTo(b.categoryCode);
        return c != 0 ? c : a.name.compareTo(b.name);
      });
    return list;
  }

  /// 某日某分类累计秒数（按记录与当天的重叠区间计算，支持跨天记录）。
  int daySeconds(DateTime date, String categoryCode) {
    final startMs = dateOnly(date).millisecondsSinceEpoch;
    final endMs = startMs + const Duration(days: 1).inMilliseconds;
    var total = 0;
    for (final r in data.records) {
      if (r.categoryCode != categoryCode) continue;
      final s = math.max(r.startMs, startMs);
      final e = math.min(r.endMs, endMs);
      if (e > s) total += (e - s) ~/ 1000;
    }
    return total;
  }

  Map<String, int> dayTotals(DateTime date) => {
    for (final c in AppCategory.values) c.code: daySeconds(date, c.code),
  };

  /// 每日目标（秒）。突发情况返回 null（不做目标对比）。
  int? dayTargetSec(String categoryCode, {DateTime? date}) {
    final d = date ?? DateTime.now();
    final mode = modeForDate(d);
    if (mode == DayMode.emergency) return null;
    return data.settings.targetMinutes(categoryCode, mode) * 60;
  }

  int weekGoalSec(String categoryCode) =>
      (data.settings.weeklyGoals[categoryCode] ?? 0) * 60;

  int weekSeconds(String categoryCode) {
    final startMs = startOfWeek(DateTime.now()).millisecondsSinceEpoch;
    final endMs = startMs + 7 * const Duration(days: 1).inMilliseconds;
    var total = 0;
    for (final r in data.records) {
      if (r.categoryCode != categoryCode) continue;
      final s = math.max(r.startMs, startMs);
      final e = math.min(r.endMs, endMs);
      if (e > s) total += (e - s) ~/ 1000;
    }
    return total;
  }

  List<TimeRecord> recordsOnDay(DateTime date) {
    final startMs = dateOnly(date).millisecondsSinceEpoch;
    final endMs = startMs + const Duration(days: 1).inMilliseconds;
    return data.records
        .where((r) => r.startMs < endMs && r.endMs > startMs)
        .toList()
      ..sort((a, b) => b.startMs.compareTo(a.startMs));
  }

  /// 单条记录在指定日期内的重叠秒数。
  int recordSecondsOnDay(TimeRecord r, DateTime date) {
    final startMs = dateOnly(date).millisecondsSinceEpoch;
    final endMs = startMs + const Duration(days: 1).inMilliseconds;
    final s = math.max(r.startMs, startMs);
    final e = math.min(r.endMs, endMs);
    return e > s ? (e - s) ~/ 1000 : 0;
  }

  Set<String> get allTags {
    final s = <String>{};
    for (final r in data.records) {
      s.addAll(r.tags);
    }
    return s;
  }

  /// 复盘弹窗顶部的时间简易分析提示。
  /// 仅弹窗打开时实时计算；无记录或「其他」模式返回 null。
  String? reviewAnalysisHint(DateTime date) {
    final mode = modeForDate(date);
    if (mode == DayMode.emergency) return null;
    final totals = dayTotals(date);
    final totalSec = totals.values.fold<int>(0, (sum, v) => sum + v);
    if (totalSec <= 0) return null;
    final studySec = totals[AppCategory.workStudy.code] ?? 0;
    final entRatio = (totals[AppCategory.entertainment.code] ?? 0) / totalSec;
    if (mode == DayMode.workday) {
      if (studySec < 4 * 3600) return '今日学习时长偏少，可以适当增加专注时间';
      if (entRatio > 0.5) return '今日娱乐占比偏高，注意分配时间';
      return '今日时间分配比较不错';
    }
    // 休息日：话术放宽，不做严苛评判
    if (entRatio > 0.7) return '今天娱乐时间偏多，注意劳逸结合';
    return '休息日保持轻松节奏，记得留出放松时间';
  }

  /// 周统计：统计范围是今天（含）向前 7 天。
  /// 只统计有事件记录的有效日期；平均时长 = 总时长 / 有效记录天数。
  WeekStats computeWeekStats([DateTime? base]) {
    final today = dateOnly(base ?? DateTime.now());
    final start = today.subtract(const Duration(days: 6));
    final stats = WeekStats()
      ..weekStart = start
      ..weekEnd = today;
    for (var i = 0; i < 7; i++) {
      final day = start.add(Duration(days: i));
      // 过滤掉完全没有事件记录的日期，只保留有事件的有效日期
      if (recordsOnDay(day).isEmpty) continue;
      final mode = modeForDate(day);
      final totals = dayTotals(day);
      stats.activeDays.add(DaySummary(date: day, totals: totals));
      stats.activeDayCount++;
      for (final c in AppCategory.values) {
        final sec = totals[c.code] ?? 0;
        stats.weekTotals[c.code] = (stats.weekTotals[c.code] ?? 0) + sec;
        if (mode == DayMode.workday) {
          stats.workdayTotals[c.code] =
              (stats.workdayTotals[c.code] ?? 0) + sec;
        } else if (mode == DayMode.restday) {
          stats.restdayTotals[c.code] =
              (stats.restdayTotals[c.code] ?? 0) + sec;
        }
      }
      if (mode == DayMode.workday) {
        stats.workdayCount++;
      } else if (mode == DayMode.restday) {
        stats.restdayCount++;
      } else {
        stats.emergencyDays.add(day);
      }
    }
    return stats;
  }

  // ---------- 事件管理 ----------
  EventItem? addEvent(String name, AppCategory category, {String note = ''}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    final event = EventItem(
      id: newId(),
      name: trimmed,
      categoryCode: category.code,
      note: note.trim(),
      createdAt: DateTime.now(),
    );
    data.events.add(event);
    _saveAndNotify();
    return event;
  }

  // ---------- 预录入（明日/今日计划） ----------

  /// 某日期已登记的预录入计划（按创建先后排序）。
  List<PlannedEntry> plansOnDate(DateTime date) {
    final list = data.plans[dateKey(date)] ?? const <PlannedEntry>[];
    return [...list]..sort((a, b) => a.createdAtMs.compareTo(b.createdAtMs));
  }

  /// 把某个事件预录入到指定日期（仅登记，不启动计时、不产生计时记录）。
  void addPlan(DateTime date, {required EventItem event, String note = ''}) {
    final key = dateKey(date);
    final entry = PlannedEntry(
      id: newId(),
      eventId: event.id,
      eventName: event.name,
      categoryCode: event.categoryCode,
      date: key,
      note: note.trim(),
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    data.plans.putIfAbsent(key, () => []).add(entry);
    _saveAndNotify();
  }

  void updatePlanNote(PlannedEntry plan, String note) {
    plan.note = note.trim();
    _saveAndNotify();
  }

  void deletePlan(PlannedEntry plan) {
    final list = data.plans[plan.date];
    if (list == null) return;
    list.removeWhere((p) => p.id == plan.id);
    if (list.isEmpty) data.plans.remove(plan.date);
    _saveAndNotify();
  }

  void updateEvent(EventItem event, String name, AppCategory category) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    event.name = trimmed;
    event.categoryCode = category.code;
    _saveAndNotify();
  }

  /// 更新事件备注（开始计时前、计时中、计时结束后均可编辑）。
  void updateEventNote(EventItem event, String note) {
    event.note = note.trim();
    _saveAndNotify();
  }

  void toggleFavorite(EventItem event) {
    event.favorite = !event.favorite;
    _saveAndNotify();
  }

  void deleteEvent(EventItem event) {
    data.events.removeWhere((e) => e.id == event.id);
    _saveAndNotify();
  }

  // ---------- 计时器 ----------
  void startTimer(
    EventItem event, {
    bool countdown = false,
    int estimateSec = 0,
  }) {
    _ticker?.cancel();
    session = TimerSession(
      event: event,
      countdown: countdown,
      estimateSec: math.max(1, estimateSec),
      startedAt: DateTime.now(),
    )..start();
    _startTicker();
    _resetPosture();
    _syncAlarms();
    _persistTimer();
    notifyListeners();
  }

  void pauseTimer() {
    final t = session;
    if (t == null || !t.running) return;
    t.pause();
    _syncAlarms();
    _persistTimer();
    notifyListeners();
  }

  void resumeTimer() {
    final t = session;
    if (t == null || t.running) return;
    t.resume();
    _startTicker();
    _syncAlarms();
    _persistTimer();
    notifyListeners();
  }

  /// 结束并保存记录；tags 为本次记录的自定义标签。
  void endTimer({List<String> tags = const []}) {
    final t = session;
    if (t == null) return;
    final now = DateTime.now();
    final duration = t.countdown && t.finished
        ? t.estimateSec
        : t.elapsedRunningSec;
    _addRecord(
      TimeRecord(
        id: newId(),
        eventId: t.event.id,
        eventName: t.event.name,
        categoryCode: t.event.categoryCode,
        startMs: t.startedAt.millisecondsSinceEpoch,
        endMs: now.millisecondsSinceEpoch,
        durationSec: math.max(1, duration),
        pausedSec: t.pausedTotalMs ~/ 1000,
        tags: tags,
        modeCode: modeForDate(t.startedAt).code,
        createdAtMs: now.millisecondsSinceEpoch,
      ),
    );
    _clearSession();
  }

  /// 放弃当前计时（不保存）。
  void discardTimer() {
    _clearSession();
  }

  /// 倒计时自然结束时调用：发提醒并弹窗让用户确认。
  void handleCountdownFinished() {
    final t = session;
    if (t == null || !t.finished) return;
    NotificationService.instance.cancel(
      NotificationService.idCountdownScheduled,
    );
    NotificationService.instance.show(
      NotificationService.idCountdownImmediate,
      '倒计时结束',
      '「${t.event.name}」预估时长已到，请确认是否结束计时。',
    );
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    showDialog<void>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('倒计时结束'),
        content: Text('「${t.event.name}」倒计时已结束。\n是否保存本次记录？'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              discardTimer();
            },
            child: const Text('放弃'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              endTimer();
            },
            child: const Text('保存记录'),
          ),
        ],
      ),
    );
  }

  // ---------- 手动补录 ----------
  void addBackfill({
    required EventItem event,
    required DateTime start,
    required DateTime end,
    List<String> tags = const [],
  }) {
    var s = start;
    var e = end;
    if (e.isBefore(s)) {
      final tmp = s;
      s = e;
      e = tmp;
    }
    if (!e.isAfter(s)) e = s.add(const Duration(seconds: 1));
    _addRecord(
      TimeRecord(
        id: newId(),
        eventId: event.id,
        eventName: event.name,
        categoryCode: event.categoryCode,
        startMs: s.millisecondsSinceEpoch,
        endMs: e.millisecondsSinceEpoch,
        durationSec: math.max(1, e.difference(s).inSeconds),
        pausedSec: 0,
        tags: tags,
        modeCode: modeForDate(s).code,
        isBackfill: true,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  // ---------- 已完成记录：编辑 / 删除 ----------
  void updateRecord(
    TimeRecord record, {
    required EventItem event,
    required DateTime start,
    required DateTime end,
    List<String> tags = const [],
  }) {
    var s = start;
    var e = end;
    if (e.isBefore(s)) {
      final tmp = s;
      s = e;
      e = tmp;
    }
    if (!e.isAfter(s)) e = s.add(const Duration(seconds: 1));
    final index = data.records.indexWhere((r) => r.id == record.id);
    if (index < 0) return;
    final duration = math.max(1, e.difference(s).inSeconds);
    final updated = record.copyWith(
      eventId: event.id,
      eventName: event.name,
      categoryCode: event.categoryCode,
      startMs: s.millisecondsSinceEpoch,
      endMs: e.millisecondsSinceEpoch,
      durationSec: duration,
      pausedSec: math.min(record.pausedSec, duration),
      tags: tags,
      modeCode: modeForDate(s).code,
    );
    data.records[index] = updated;
    _saveAndNotify();
  }

  void deleteRecord(TimeRecord record) {
    data.records.removeWhere((r) => r.id == record.id);
    _saveAndNotify();
  }

  /// 时间轴专用标签集合。
  static const Set<String> timelineLabels = {'学习', '工作', '娱乐', '其他'};

  /// 修改已完成记录的「时间轴分类」（写入该记录的标签字段）。
  void setRecordTimelineLabel(TimeRecord record, String label) {
    if (!timelineLabels.contains(label)) return;
    final index = data.records.indexWhere((r) => r.id == record.id);
    if (index < 0) return;
    final newTags = <String>[
      label,
      ...record.tags.where((t) => !timelineLabels.contains(t)),
    ];
    data.records[index] = record.copyWith(tags: newTags);
    _saveAndNotify();
  }

  /// 时间轴空白「其他」块确认分类后，生成一条真实计时记录。
  void addTimelineRecord(
    DateTime date,
    int startMinute,
    int endMinute,
    String label,
  ) {
    if (!timelineLabels.contains(label)) return;
    final dayStart = dateOnly(date);
    final start = dayStart.add(Duration(minutes: math.max(0, startMinute)));
    final end = dayStart.add(Duration(minutes: math.min(1440, endMinute)));
    if (!end.isAfter(start)) return;
    final categoryCode = switch (label) {
      '学习' || '工作' => AppCategory.workStudy.code,
      '娱乐' => AppCategory.entertainment.code,
      _ => AppCategory.other.code,
    };
    _addRecord(
      TimeRecord(
        id: newId(),
        eventId: 'timeline_${label}_${dateKey(date)}_$startMinute',
        eventName: '时间轴·$label',
        categoryCode: categoryCode,
        startMs: start.millisecondsSinceEpoch,
        endMs: end.millisecondsSinceEpoch,
        durationSec: math.max(1, end.difference(start).inSeconds),
        pausedSec: 0,
        tags: [label],
        modeCode: modeForDate(date).code,
        isBackfill: true,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  // ---------- 设置 ----------
  void setTarget(String categoryCode, DayMode mode, int minutes) {
    final value = math.max(0, minutes);
    final map = switch (mode) {
      DayMode.workday => data.settings.workdayTargets,
      DayMode.restday => data.settings.restdayTargets,
      DayMode.emergency => null,
    };
    if (map == null) return;
    map[categoryCode] = math.min(
      value,
      data.settings.maxDailyMinutes(categoryCode, mode),
    );
    _saveAndNotify();
  }

  void setWeeklyGoal(String categoryCode, int minutes) {
    final value = math.max(0, minutes);
    data.settings.weeklyGoals[categoryCode] = math.min(
      value,
      data.settings.maxWeeklyMinutes(categoryCode),
    );
    _saveAndNotify();
  }

  void setThemeMode(String mode) {
    data.settings.themeMode = mode;
    _saveAndNotify();
  }

  void setWaterEnabled(bool enabled) {
    data.settings.waterEnabled = enabled;
    _saveAndNotify();
    _syncWaterAlarm();
  }

  void setWaterInterval(int minutes) {
    data.settings.waterIntervalMin = minutes.clamp(30, 120);
    _saveAndNotify();
    _syncWaterAlarm();
  }

  void setSleepReminderEnabled(bool enabled) {
    data.settings.sleepReminderEnabled = enabled;
    _saveAndNotify();
    _syncSleepAlarm();
  }

  void setSleepReminderTime(int hour, int minute) {
    data.settings.sleepReminderHour = hour.clamp(0, 23);
    data.settings.sleepReminderMinute = minute.clamp(0, 59);
    _saveAndNotify();
    _syncSleepAlarm();
  }

  void setEntertainmentEnabled(bool enabled) {
    data.settings.entertainmentEnabled = enabled;
    _saveAndNotify();
  }

  void addEntertainmentApp(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (data.settings.entertainmentApps.contains(trimmed)) return;
    data.settings.entertainmentApps.add(trimmed);
    _saveAndNotify();
  }

  void removeEntertainmentApp(String name) {
    data.settings.entertainmentApps.remove(name);
    _saveAndNotify();
  }

  // ---------- 提醒调度 ----------
  int get postureThresholdSec => _postureThresholdSec;

  void _resetPosture() {
    _postureThresholdSec = 3000;
    data.settings.postureThresholdSec = 3000;
    _save();
    _syncPostureAlarm();
  }

  void advancePostureThreshold() {
    _postureThresholdSec += 3000;
    data.settings.postureThresholdSec = _postureThresholdSec;
    _save();
    _syncPostureAlarm();
  }

  void markWaterFired(int nowMs) {
    data.settings.lastWaterMs = nowMs;
    _save();
  }

  /// 安排 Android 后台休息喝水提醒；其它平台由 ReminderEngine 应用内触发。
  void scheduleWaterAlarm() {
    NotificationService.instance.cancel(NotificationService.idWaterScheduled);
    if (!data.settings.waterEnabled) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final interval = data.settings.waterIntervalMin * 60000;
    var next = data.settings.lastWaterMs > 0
        ? data.settings.lastWaterMs + interval
        : now + interval;
    if (next <= now) next = now + interval;
    NotificationService.instance.scheduleAt(
      NotificationService.idWaterScheduled,
      '休息喝水提醒',
      '连续工作这么久，该休息一下喝杯水啦 💧',
      DateTime.fromMillisecondsSinceEpoch(next),
    );
  }

  void _syncWaterAlarm() {
    if (data.settings.waterEnabled) {
      scheduleWaterAlarm();
    } else {
      NotificationService.instance.cancel(NotificationService.idWaterScheduled);
    }
  }

  /// 安排 Android 每日睡觉提醒；点击通知唤起当日复盘编辑弹窗。
  void scheduleSleepReminder() {
    NotificationService.instance.cancel(NotificationService.idSleepScheduled);
    if (!data.settings.sleepReminderEnabled) return;
    NotificationService.instance.scheduleDaily(
      NotificationService.idSleepScheduled,
      '睡觉提醒',
      '该睡觉了，请完成今日复盘。',
      data.settings.sleepReminderHour,
      data.settings.sleepReminderMinute,
      payload: 'sleep_review',
    );
  }

  void _syncSleepAlarm() {
    if (data.settings.sleepReminderEnabled) {
      scheduleSleepReminder();
    } else {
      NotificationService.instance.cancel(NotificationService.idSleepScheduled);
    }
  }

  void _syncAlarms() {
    _syncPostureAlarm();
    _syncCountdownAlarm();
  }

  /// 起身活动提醒：工作学习计时运行时安排 50 分钟节点；突发模式同样生效。
  void _syncPostureAlarm() {
    NotificationService.instance.cancel(NotificationService.idPostureScheduled);
    final t = session;
    if (t == null ||
        !t.running ||
        t.event.categoryCode != AppCategory.workStudy.code) {
      return;
    }
    final remaining = _postureThresholdSec - t.elapsedRunningSec;
    final when = remaining > 0
        ? DateTime.now().add(Duration(seconds: remaining))
        : DateTime.now().add(const Duration(seconds: 20));
    NotificationService.instance.scheduleAt(
      NotificationService.idPostureScheduled,
      '起身活动提醒',
      '已连续专注 50 分钟，请起身活动一下腰部～',
      when,
    );
  }

  void _syncCountdownAlarm() {
    NotificationService.instance.cancel(
      NotificationService.idCountdownScheduled,
    );
    final t = session;
    if (t == null || !t.countdown || !t.running || t.finished) return;
    final remaining = t.remainingSec;
    if (remaining <= 0) return;
    NotificationService.instance.scheduleAt(
      NotificationService.idCountdownScheduled,
      '倒计时结束',
      '「${t.event.name}」预估时长已到。',
      DateTime.now().add(Duration(seconds: remaining)),
    );
  }

  /// 娱乐提醒弹窗（仅提醒，不强制关闭、不锁机）。
  void showEntertainmentAlert(String app) {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    showDialog<void>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        icon: const Icon(Icons.visibility_off_outlined),
        title: const Text('娱乐提醒'),
        content: Text('当前处于工作学习计时，请勿使用娱乐应用。\n\n检测到：$app'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  // ---------- 导入导出 ----------
  Future<String?> exportAllJson() => exportJsonFile(data);

  Future<String?> importMergeJson() async {
    final incoming = await pickJsonFile();
    if (incoming == null) return null;
    final before = data.records.length;
    data.mergeFrom(incoming);
    _saveAndNotify();
    final after = data.records.length;
    return '导入完成：事件 ${incoming.events.length} 个，记录 ${incoming.records.length} 条（合并前 $before 条，合并后 $after 条）';
  }

  Future<String?> exportAllCsv() => exportCsvFile(data.records);

  // ---------- 内部 ----------
  void _addRecord(TimeRecord record) {
    data.records.add(record);
    _saveAndNotify();
  }

  void _clearSession() {
    _ticker?.cancel();
    _ticker = null;
    session = null;
    NotificationService.instance.cancel(NotificationService.idPostureScheduled);
    NotificationService.instance.cancel(
      NotificationService.idCountdownScheduled,
    );
    unawaited(storage.clearTimerState());
    notifyListeners();
  }

  /// 持久化当前计时状态（运行/暂停），供杀后台后恢复。
  void _persistTimer() {
    final t = session;
    if (t == null) {
      unawaited(storage.clearTimerState());
      return;
    }
    unawaited(
      storage.saveTimerState(
        TimerSnapshot(
          status: t.running ? 'running' : 'paused',
          eventId: t.event.id,
          startedAtMs: t.startedAt.millisecondsSinceEpoch,
          elapsedRunningMs: t.baseRunningMs,
          pausedMs: t.pausedMs,
          countdown: t.countdown,
          estimateSec: t.estimateSec,
        ),
      ),
    );
  }

  /// 应用启动时读取本地计时状态并恢复会话。
  Future<void> restoreTimerState() async {
    final snap = await storage.loadTimerState();
    if (snap == null) return;
    final event = eventById(snap.eventId);
    if (event == null) {
      await storage.clearTimerState();
      return;
    }
    final now = DateTime.now();
    session = TimerSession(
      event: event,
      countdown: snap.countdown,
      estimateSec: math.max(1, snap.estimateSec),
      startedAt: DateTime.fromMillisecondsSinceEpoch(snap.startedAtMs),
    );
    if (snap.isRunning) {
      // 正在运行：用当前系统时间减去开始时间戳计算逝去时长，合并计入总时长
      final wallMs = now.millisecondsSinceEpoch - snap.startedAtMs;
      final accumulated = math.max(0, wallMs - snap.pausedMs);
      session!.restoreRunning(
        accumulatedRunningMs: accumulated,
        accumulatedPausedMs: snap.pausedMs,
        at: now,
      );
    } else {
      session!.restorePaused(
        accumulatedRunningMs: snap.elapsedRunningMs,
        accumulatedPausedMs: snap.pausedMs,
        at: now,
      );
    }
    _startTicker();
    _resetPosture();
    _syncAlarms();
    notifyListeners();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final t = session;
      if (t == null) return;
      if (t.countdown && t.running && t.remainingMs <= 0) {
        t.pause();
        t.finished = true;
        NotificationService.instance.cancel(
          NotificationService.idCountdownScheduled,
        );
        notifyListeners();
        handleCountdownFinished();
        return;
      }
      notifyListeners();
    });
  }

  void _save() {
    unawaited(storage.save(data));
  }

  void _saveAndNotify() {
    _save();
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
