import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:time_block_recorder/models/app_data.dart';
import 'package:time_block_recorder/models/category.dart';
import 'package:time_block_recorder/models/day_meta.dart';
import 'package:time_block_recorder/models/day_mode.dart';
import 'package:time_block_recorder/models/event_item.dart';
import 'package:time_block_recorder/models/time_record.dart';
import 'package:time_block_recorder/utils/format.dart';

TimeRecord makeRecord({
  String id = 'r1',
  String modeCode = 'workday',
  int createdAtMs = 1000,
}) => TimeRecord(
  id: id,
  eventId: 'e1',
  eventName: '上课',
  categoryCode: AppCategory.workStudy.code,
  startMs: 100,
  endMs: 400,
  durationSec: 3,
  pausedSec: 1,
  tags: ['专注'],
  modeCode: modeCode,
  createdAtMs: createdAtMs,
);

void main() {
  test('默认数据包含内置初始事件', () {
    final data = AppData.createDefault();
    expect(data.events.length, 11);
    expect(
      data.events
          .where((e) => e.categoryCode == AppCategory.workStudy.code)
          .length,
      4,
    );
    expect(
      data.events
          .where((e) => e.categoryCode == AppCategory.freeRecovery.code)
          .length,
      4,
    );
    expect(
      data.events
          .where((e) => e.categoryCode == AppCategory.entertainment.code)
          .length,
      2,
    );
    expect(
      data.events.where((e) => e.categoryCode == AppCategory.sleep.code).length,
      1,
    );
    expect(data.settings.workdayTargets[AppCategory.sleep.code], 480);
    expect(data.settings.weeklyGoals[AppCategory.workStudy.code], 2400);
    expect(data.settings.waterIntervalMin, 60);
  });

  test('JSON 序列化往返一致（含标签/模式/每日附加信息）', () {
    final data = AppData.createDefault();
    data.records.add(makeRecord());
    data.dayMetas['2026-08-31'] = DayMeta(
      date: '2026-08-31',
      modeOverride: DayMode.emergency.code,
      note: '临时出差',
      review: '很充实',
    );
    final json = jsonDecode(jsonEncode(data.toJson())) as Map<String, dynamic>;
    final restored = AppData.fromJson(json);
    expect(restored.events.length, data.events.length);
    expect(restored.records.length, 1);
    expect(restored.records.first.tags, ['专注']);
    expect(restored.records.first.modeCode, 'workday');
    final meta = restored.dayMetas['2026-08-31']!;
    expect(meta.resolve(), DayMode.emergency);
    expect(meta.note, '临时出差');
    expect(restored.settings.workdayTargets, data.settings.workdayTargets);
    expect(restored.settings.weeklyGoals, data.settings.weeklyGoals);
  });

  test('旧版 isWorkday 布尔字段可迁移为 modeCode', () {
    final json = {
      'id': 'r-old',
      'eventId': 'e1',
      'eventName': '上课',
      'category': 'workStudy',
      'startMs': 1,
      'endMs': 2,
      'durationSec': 1,
      'isWorkday': false,
      'createdAtMs': 1,
    };
    final record = TimeRecord.fromJson(json);
    expect(record.modeCode, 'restday');
  });

  test('合并导入：同一 id 记录以更新时间戳更新者为准', () {
    final local = AppData.createDefault();
    final incoming = AppData.createDefault();
    local.records.add(makeRecord(createdAtMs: 1000));
    incoming.records.add(makeRecord(createdAtMs: 2000));
    local.mergeFrom(incoming);
    expect(local.records.length, 1);
    expect(local.records.first.createdAtMs, 2000);
  });

  test('合并导入：事件按 id 覆盖', () {
    final local = AppData.createDefault();
    final incoming = AppData.createDefault();
    final oldEvent = local.events.first;
    incoming.events.removeAt(0);
    incoming.events.insert(
      0,
      EventItem(
        id: oldEvent.id,
        name: '新名称',
        categoryCode: oldEvent.categoryCode,
        createdAt: oldEvent.createdAt,
      ),
    );
    local.mergeFrom(incoming);
    final merged = local.events.firstWhere((e) => e.id == oldEvent.id);
    expect(merged.name, '新名称');
  });

  test('合并导入：每日备注/复盘按日期合并且导入非空字段优先', () {
    final local = AppData.createDefault();
    final incoming = AppData.createDefault();
    local.dayMetas['2026-08-31'] = DayMeta(
      date: '2026-08-31',
      note: '本地备注',
      review: '本地复盘',
    );
    incoming.dayMetas['2026-08-31'] = DayMeta(
      date: '2026-08-31',
      modeOverride: DayMode.emergency.code,
      review: '导入复盘',
    );
    local.mergeFrom(incoming);
    final meta = local.dayMetas['2026-08-31']!;
    expect(meta.note, '本地备注');
    expect(meta.review, '导入复盘');
    expect(meta.resolve(), DayMode.emergency);
  });

  test('编辑已完成记录：copyWith 更新事件与时长', () {
    final updated = makeRecord().copyWith(
      eventId: 'e2',
      eventName: '学C语言',
      startMs: 100,
      endMs: 900,
      durationSec: 8,
      tags: const ['学习'],
    );
    expect(updated.eventName, '学C语言');
    expect(updated.durationSec, 8);
    expect(updated.tags, ['学习']);
    expect(updated.modeCode, 'workday');
  });

  test('默认周规则：周一至周五工作日，周六周日休息日', () {
    expect(isWorkday(DateTime(2026, 8, 31)), true); // 周一
    expect(isWorkday(DateTime(2026, 9, 4)), true); // 周五
    expect(isWorkday(DateTime(2026, 9, 5)), false); // 周六
    expect(isWorkday(DateTime(2026, 9, 6)), false); // 周日
  });
}
