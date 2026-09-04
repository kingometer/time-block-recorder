import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:time_block_recorder/models/app_data.dart';
import 'package:time_block_recorder/models/category.dart';
import 'package:time_block_recorder/models/planned_entry.dart';
import 'package:time_block_recorder/services/storage_service.dart';
import 'package:time_block_recorder/state/app_state.dart';
import 'package:time_block_recorder/utils/format.dart';

class _FakeStorage extends StorageService {
  @override
  Future<void> save(AppData data) async {}
}

void main() {
  AppState makeState() =>
      AppState(initialData: AppData.createDefault(), storage: _FakeStorage());

  PlannedEntry makePlan({
    String id = 'p1',
    String date = '2026-09-05',
    int createdAtMs = 100,
    String note = '复习指针',
  }) => PlannedEntry(
    id: id,
    eventId: 'e1',
    eventName: '学C语言',
    categoryCode: AppCategory.workStudy.code,
    date: date,
    note: note,
    createdAtMs: createdAtMs,
  );

  test('JSON 序列化往返保留预录计划', () {
    final data = AppData.createDefault();
    data.plans['2026-09-05'] = [makePlan()];
    final json = jsonDecode(jsonEncode(data.toJson())) as Map<String, dynamic>;
    final restored = AppData.fromJson(json);
    final plans = restored.plans['2026-09-05'];
    expect(plans, isNotNull);
    expect(plans!.length, 1);
    expect(plans.first.eventName, '学C语言');
    expect(plans.first.note, '复习指针');
    expect(plans.first.date, '2026-09-05');
    expect(restored.plans['2026-09-06'], isNull);
  });

  test('旧备份无 plans 字段可正常加载', () {
    final data = AppData.createDefault();
    final json = data.toJson()..remove('plans');
    final restored = AppData.fromJson(json);
    expect(restored.plans, isEmpty);
  });

  test('合并导入：预录计划同 id 以更新时间戳较新者覆盖', () {
    final local = AppData.createDefault();
    final incoming = AppData.createDefault();
    local.plans['2026-09-05'] = [makePlan(createdAtMs: 100)];
    incoming.plans['2026-09-05'] = [
      makePlan(id: 'p1', createdAtMs: 200, note: '更新备注'),
    ];
    local.mergeFrom(incoming);
    final plans = local.plans['2026-09-05']!;
    expect(plans.length, 1);
    expect(plans.first.createdAtMs, 200);
    expect(plans.first.note, '更新备注');
  });

  test('合并导入：不同日期与不同 id 预录均保留', () {
    final local = AppData.createDefault();
    final incoming = AppData.createDefault();
    local.plans['2026-09-05'] = [makePlan(id: 'p1')];
    incoming.plans['2026-09-06'] = [makePlan(id: 'p2', date: '2026-09-06')];
    local.mergeFrom(incoming);
    expect(local.plans['2026-09-05']!.length, 1);
    expect(local.plans['2026-09-06']!.length, 1);
  });

  test('addPlan 仅登记计划，不产生计时记录，不影响当天统计', () {
    final state = makeState();
    final today = DateTime.now();
    final tomorrow = dateOnly(today.add(const Duration(days: 1)));
    final event = state.data.events.first;
    state.addPlan(tomorrow, event: event, note: '准备实验报告');

    expect(state.plansOnDate(tomorrow).length, 1);
    expect(state.plansOnDate(tomorrow).first.eventName, event.name);
    expect(state.plansOnDate(tomorrow).first.note, '准备实验报告');
    // 预录不产生计时记录
    expect(state.data.records, isEmpty);
    // 不影响今天统计
    expect(state.dayTotals(today).values.fold<int>(0, (a, b) => a + b), 0);
  });

  test('updatePlanNote / deletePlan 更新并移除预录', () {
    final state = makeState();
    final tomorrow = dateOnly(DateTime.now().add(const Duration(days: 1)));
    final event = state.data.events.first;
    state.addPlan(tomorrow, event: event, note: '旧备注');
    final plan = state.plansOnDate(tomorrow).first;

    state.updatePlanNote(plan, '新备注');
    expect(state.plansOnDate(tomorrow).first.note, '新备注');

    state.deletePlan(plan);
    expect(state.plansOnDate(tomorrow), isEmpty);
    expect(state.data.plans.containsKey(dateKey(tomorrow)), isFalse);
  });

  test('plansOnDate 按创建时间先后排序', () {
    final data = AppData.createDefault();
    data.plans['2026-09-05'] = [
      makePlan(id: 'p2', createdAtMs: 200),
      makePlan(id: 'p1', createdAtMs: 100),
    ];
    final state = AppState(initialData: data, storage: _FakeStorage());
    final plans = state.plansOnDate(DateTime(2026, 9, 5));
    expect(plans.map((p) => p.id).toList(), ['p1', 'p2']);
  });

  test('删除事件后预录快照仍可展示', () {
    final state = makeState();
    final tomorrow = dateOnly(DateTime.now().add(const Duration(days: 1)));
    final event = state.data.events.first;
    state.addPlan(tomorrow, event: event);
    state.deleteEvent(event);
    expect(state.plansOnDate(tomorrow).first.eventName, event.name);
  });
}
