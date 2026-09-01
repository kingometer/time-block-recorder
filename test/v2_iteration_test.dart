import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:time_block_recorder/models/app_data.dart';
import 'package:time_block_recorder/models/app_settings.dart';
import 'package:time_block_recorder/models/category.dart';
import 'package:time_block_recorder/models/day_mode.dart';
import 'package:time_block_recorder/models/time_record.dart';
import 'package:time_block_recorder/models/timer_snapshot.dart';
import 'package:time_block_recorder/services/storage_service.dart';
import 'package:time_block_recorder/state/app_state.dart';
import 'package:time_block_recorder/utils/format.dart';
import 'package:time_block_recorder/widgets/day_timeline.dart';

class _FakeStorage extends StorageService {
  TimerSnapshot? snapshot;

  @override
  Future<void> save(AppData data) async {}

  @override
  Future<TimerSnapshot?> loadTimerState() async => snapshot;

  @override
  Future<void> saveTimerState(TimerSnapshot snap) async {
    snapshot = snap;
  }

  @override
  Future<void> clearTimerState() async {
    snapshot = null;
  }
}

AppState makeState([StorageService? storage]) => AppState(
  initialData: AppData.createDefault(),
  storage: storage ?? _FakeStorage(),
);

TimeRecord makeRecord({
  required int startMs,
  required int endMs,
  String categoryCode = 'workStudy',
  List<String> tags = const [],
}) => TimeRecord(
  id: 'r${startMs}_$endMs',
  eventId: 'e1',
  eventName: '上课',
  categoryCode: categoryCode,
  startMs: startMs,
  endMs: endMs,
  durationSec: (endMs - startMs) ~/ 1000,
  tags: tags,
  modeCode: 'workday',
  createdAtMs: endMs,
);

void main() {
  group('计时快照持久化', () {
    test('TimerSnapshot JSON 往返一致', () {
      final snap = TimerSnapshot(
        status: 'running',
        eventId: 'e1',
        startedAtMs: 1000,
        elapsedRunningMs: 50000,
        pausedMs: 20000,
        countdown: true,
        estimateSec: 3600,
      );
      final restored = TimerSnapshot.fromJson(
        jsonDecode(jsonEncode(snap.toJson())) as Map<String, dynamic>,
      );
      expect(restored.status, 'running');
      expect(restored.isRunning, isTrue);
      expect(restored.eventId, 'e1');
      expect(restored.startedAtMs, 1000);
      expect(restored.elapsedRunningMs, 50000);
      expect(restored.pausedMs, 20000);
      expect(restored.countdown, isTrue);
      expect(restored.estimateSec, 3600);
    });

    test('restoreTimerState：running 按当前时间补算逝去时长', () async {
      final storage = _FakeStorage();
      final state = makeState(storage);
      final event = state.data.events.first;
      final now = DateTime.now();
      storage.snapshot = TimerSnapshot(
        status: 'running',
        eventId: event.id,
        startedAtMs: now
            .subtract(const Duration(minutes: 30))
            .millisecondsSinceEpoch,
        elapsedRunningMs: 0,
        pausedMs: const Duration(minutes: 10).inMilliseconds,
        countdown: false,
        estimateSec: 0,
      );
      await state.restoreTimerState();
      final session = state.session!;
      expect(session.running, isTrue);
      expect(session.elapsedRunningSec, closeTo(1200, 3));
    });

    test('restoreTimerState：paused 使用保存的累计时长', () async {
      final storage = _FakeStorage();
      final state = makeState(storage);
      final event = state.data.events.first;
      storage.snapshot = TimerSnapshot(
        status: 'paused',
        eventId: event.id,
        startedAtMs: DateTime.now().millisecondsSinceEpoch,
        elapsedRunningMs: 90000,
        pausedMs: 10000,
        countdown: false,
        estimateSec: 0,
      );
      await state.restoreTimerState();
      final session = state.session!;
      expect(session.running, isFalse);
      expect(session.elapsedRunningSec, 90);
      expect(session.pausedTotalMs ~/ 1000, 10);
    });

    test('restoreTimerState：事件已删除则清除快照', () async {
      final storage = _FakeStorage();
      final state = makeState(storage);
      storage.snapshot = TimerSnapshot(
        status: 'running',
        eventId: 'not-exist',
        startedAtMs: DateTime.now().millisecondsSinceEpoch,
        elapsedRunningMs: 0,
        pausedMs: 0,
        countdown: false,
        estimateSec: 0,
      );
      await state.restoreTimerState();
      expect(state.session, isNull);
      expect(storage.snapshot, isNull);
    });

    test('endTimer 生成记录并清空本地计时快照', () {
      final storage = _FakeStorage();
      final state = makeState(storage);
      final event = state.data.events.first;
      state.startTimer(event);
      state.endTimer();
      expect(state.session, isNull);
      expect(storage.snapshot, isNull);
      expect(state.data.records.length, 1);
    });
  });

  group('复盘时间分析提示', () {
    test('工作日学习时长偏少', () {
      final state = makeState();
      final date = DateTime(2026, 9, 1); // 周二
      final study = state.eventsOf(AppCategory.workStudy).first;
      state.addBackfill(
        event: study,
        start: date.add(const Duration(hours: 9)),
        end: date.add(const Duration(hours: 10)),
      );
      expect(state.reviewAnalysisHint(date), '今日学习时长偏少，可以适当增加专注时间');
    });

    test('工作日娱乐占比过高', () {
      final state = makeState();
      final date = DateTime(2026, 9, 1);
      final study = state.eventsOf(AppCategory.workStudy).first;
      final ent = state.eventsOf(AppCategory.entertainment).first;
      state.addBackfill(
        event: study,
        start: date.add(const Duration(hours: 8)),
        end: date.add(const Duration(hours: 12)),
      );
      state.addBackfill(
        event: ent,
        start: date.add(const Duration(hours: 12)),
        end: date.add(const Duration(hours: 17)),
      );
      expect(state.reviewAnalysisHint(date), '今日娱乐占比偏高，注意分配时间');
    });

    test('工作日时间分配均衡', () {
      final state = makeState();
      final date = DateTime(2026, 9, 1);
      final study = state.eventsOf(AppCategory.workStudy).first;
      final free = state.eventsOf(AppCategory.freeRecovery).first;
      final ent = state.eventsOf(AppCategory.entertainment).first;
      state.addBackfill(
        event: study,
        start: date.add(const Duration(hours: 8)),
        end: date.add(const Duration(hours: 13)),
      );
      state.addBackfill(
        event: free,
        start: date.add(const Duration(hours: 13)),
        end: date.add(const Duration(hours: 14)),
      );
      state.addBackfill(
        event: ent,
        start: date.add(const Duration(hours: 14)),
        end: date.add(const Duration(hours: 15)),
      );
      expect(state.reviewAnalysisHint(date), '今日时间分配比较不错');
    });

    test('休息日话术放宽', () {
      final state = makeState();
      final date = DateTime(2026, 9, 5); // 周六
      final ent = state.eventsOf(AppCategory.entertainment).first;
      state.addBackfill(
        event: ent,
        start: date.add(const Duration(hours: 10)),
        end: date.add(const Duration(hours: 13)),
      );
      expect(state.reviewAnalysisHint(date), '今天娱乐时间偏多，注意劳逸结合');
    });

    test('其他模式或无记录不输出提示', () {
      final state = makeState();
      final date = DateTime(2026, 9, 1);
      state.setDayModeOverride(date, DayMode.emergency);
      expect(state.reviewAnalysisHint(date), isNull);
      expect(state.reviewAnalysisHint(DateTime(2026, 9, 2)), isNull);
    });
  });

  group('睡觉提醒设置', () {
    test('默认 23:00 且开关关闭', () {
      final settings = AppSettings.createDefault();
      expect(settings.sleepReminderEnabled, isFalse);
      expect(settings.sleepReminderHour, 23);
      expect(settings.sleepReminderMinute, 0);
    });

    test('JSON 往返一致', () {
      final data = AppData.createDefault();
      data.settings.sleepReminderEnabled = true;
      data.settings.sleepReminderHour = 22;
      data.settings.sleepReminderMinute = 30;
      final restored = AppData.fromJson(
        jsonDecode(jsonEncode(data.toJson())) as Map<String, dynamic>,
      );
      expect(restored.settings.sleepReminderEnabled, isTrue);
      expect(restored.settings.sleepReminderHour, 22);
      expect(restored.settings.sleepReminderMinute, 30);
    });

    test('setSleepReminderEnabled 同步开关状态', () {
      final state = makeState();
      state.setSleepReminderEnabled(true);
      expect(state.data.settings.sleepReminderEnabled, isTrue);
    });
  });

  group('24小时时间轴', () {
    final day = DateTime(2026, 9, 1);

    test('空隙自动填充其他，0-24 小时完整覆盖', () {
      final dayStart = dateOnly(day).millisecondsSinceEpoch;
      final segments = buildTimelineSegments([
        makeRecord(
          startMs: dayStart + const Duration(hours: 10).inMilliseconds,
          endMs: dayStart + const Duration(hours: 11).inMilliseconds,
        ),
      ], day);
      expect(segments.first.isGap, isTrue);
      expect(segments.first.label, '其他');
      expect(segments.first.startMin, 0);
      expect(segments[1].isGap, isFalse);
      expect(segments[1].label, '学习');
      expect(segments[1].startMin, 600);
      expect(segments[1].endMin, 660);
      expect(segments.last.endMin, 1440);
      expect(segments.last.isGap, isTrue);
      expect(segments.first.startMin, 0);
      for (var i = 1; i < segments.length; i++) {
        expect(segments[i].startMin, segments[i - 1].endMin);
      }
    });

    test('跨零点计时在前后两天正确渲染', () {
      final dayStart = dateOnly(day).millisecondsSinceEpoch;
      final rec = makeRecord(
        startMs: dayStart + const Duration(hours: 23).inMilliseconds,
        endMs: dayStart + const Duration(hours: 25).inMilliseconds,
      );
      final segToday = buildTimelineSegments([rec], day);
      final segNext = buildTimelineSegments([
        rec,
      ], day.add(const Duration(days: 1)));
      final lastToday = segToday.lastWhere((s) => !s.isGap);
      expect(lastToday.startMin, 1380);
      expect(lastToday.endMin, 1440);
      final firstNext = segNext.firstWhere((s) => !s.isGap);
      expect(firstNext.startMin, 0);
      expect(firstNext.endMin, 60);
    });

    test('timelineLabelForRecord 优先标签，其次按分类映射', () {
      final rec = makeRecord(
        startMs: 0,
        endMs: 1000,
        categoryCode: AppCategory.workStudy.code,
        tags: const ['工作'],
      );
      expect(timelineLabelForRecord(rec), '工作');
      final rec2 = makeRecord(
        startMs: 0,
        endMs: 1000,
        categoryCode: AppCategory.workStudy.code,
      );
      expect(timelineLabelForRecord(rec2), '学习');
    });

    test('addTimelineRecord 生成真实记录参与统计', () {
      final state = makeState();
      final date = DateTime(2026, 9, 1);
      state.addTimelineRecord(date, 600, 660, '工作');
      expect(state.recordsOnDay(date).length, 1);
      final record = state.data.records.first;
      expect(record.tags, contains('工作'));
      expect(record.categoryCode, AppCategory.workStudy.code);
      expect(record.durationSec, 3600);
      expect(state.daySeconds(date, AppCategory.workStudy.code), 3600);
    });
  });
}
