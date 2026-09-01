import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:time_block_recorder/models/app_data.dart';
import 'package:time_block_recorder/models/app_settings.dart';
import 'package:time_block_recorder/models/category.dart';
import 'package:time_block_recorder/models/day_mode.dart';
import 'package:time_block_recorder/models/event_item.dart';
import 'package:time_block_recorder/services/storage_service.dart';
import 'package:time_block_recorder/state/app_state.dart';

class _FakeStorage extends StorageService {
  @override
  Future<void> save(AppData data) async {}
}

void main() {
  AppState makeState() =>
      AppState(initialData: AppData.createDefault(), storage: _FakeStorage());

  group('暂停计时修复', () {
    test('暂停后继续：实际计时累计正确、暂停时长正确', () {
      var now = DateTime(2026, 1, 1, 10);
      final event = EventItem(
        id: 'e1',
        name: '上课',
        categoryCode: AppCategory.workStudy.code,
        createdAt: now,
      );
      final session = TimerSession(
        event: event,
        countdown: false,
        estimateSec: 0,
        startedAt: now,
        now: () => now,
      );

      session.start();
      now = now.add(const Duration(seconds: 10));
      session.pause();
      expect(session.elapsedRunningSec, 10, reason: '暂停时应保留已运行时长');

      now = now.add(const Duration(seconds: 5));
      expect(session.pausedTotalMs ~/ 1000, 5, reason: '暂停期间暂停时长累计');
      expect(session.elapsedRunningSec, 10);

      now = now.add(const Duration(seconds: 3));
      session.resume();
      now = now.add(const Duration(seconds: 7));
      expect(session.elapsedRunningSec, 17, reason: '恢复后实际时长继续累计');
      expect(session.pausedTotalMs ~/ 1000, 8, reason: '暂停累计=5秒+3秒');
    });

    test('暂停状态下结束计时：保存实际时长而不是暂停时长', () {
      final state = makeState();
      final event = state.data.events.first;
      state.startTimer(event);
      final session = state.session!;
      state.pauseTimer();
      expect(session.running, isFalse);
      state.endTimer();
      final record = state.data.records.last;
      expect(record.durationSec, greaterThanOrEqualTo(1));
      expect(record.eventId, event.id);
    });
  });

  group('目标上限校验', () {
    test('每日目标合计自动钳制在 24 小时内', () {
      final state = makeState();
      final settings = state.data.settings;
      final maxAllowed = settings.maxDailyMinutes(
        AppCategory.workStudy.code,
        DayMode.workday,
      );
      expect(maxAllowed, 1440 - 120 - 90 - 480 - 30);
      state.setTarget(AppCategory.workStudy.code, DayMode.workday, 9999);
      expect(settings.workdayTargets[AppCategory.workStudy.code], maxAllowed);
      expect(
        settings.dailyTotalMin(DayMode.workday),
        lessThanOrEqualTo(AppSettings.maxDailyTotalMin),
      );
    });

    test('每周目标合计自动钳制在 168 小时内', () {
      final state = makeState();
      final settings = state.data.settings;
      final maxAllowed = settings.maxWeeklyMinutes(AppCategory.workStudy.code);
      state.setWeeklyGoal(AppCategory.workStudy.code, 99999);
      expect(settings.weeklyGoals[AppCategory.workStudy.code], maxAllowed);
      expect(
        settings.weeklyTotalMin(),
        lessThanOrEqualTo(AppSettings.maxWeeklyTotalMin),
      );
    });
  });

  group('事件备注', () {
    test('备注字段 JSON 往返一致', () {
      final e = EventItem(
        id: 'e1',
        name: '上课',
        categoryCode: AppCategory.workStudy.code,
        note: '复习第三章',
        createdAt: DateTime(2026),
      );
      final restored = EventItem.fromJson(jsonDecode(jsonEncode(e.toJson())));
      expect(restored.note, '复习第三章');
    });

    test('updateEventNote 更新事件备注', () {
      final state = makeState();
      final event = state.data.events.first;
      state.updateEventNote(event, '  新备注  ');
      expect(event.note, '新备注');
    });

    test('addEvent 支持备注', () {
      final state = makeState();
      state.addEvent('背单词', AppCategory.workStudy, note: '每天 30 个');
      final created = state.data.events.last;
      expect(created.name, '背单词');
      expect(created.note, '每天 30 个');
    });
  });

  group('分类与日期模式', () {
    test('AppCategory 包含“其他事件”分类', () {
      expect(AppCategory.values.map((c) => c.code), contains('other'));
      expect(AppCategory.other.label, '其他事件');
    });

    test('日期模式：突发情况更名为“其他”', () {
      expect(DayMode.emergency.label, '其他');
    });
  });
}
