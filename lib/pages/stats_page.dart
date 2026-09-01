import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../models/day_mode.dart';
import '../models/event_item.dart';
import '../models/time_record.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/category_pie_chart.dart';
import '../widgets/day_meta_dialogs.dart';
import '../widgets/day_timeline.dart';

class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('统计'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '日视图'),
              Tab(text: '周视图'),
              Tab(text: '记录'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_DayView(), _WeekView(), _RecordsView()],
        ),
      ),
    );
  }
}

// ---------------- 日视图 ----------------

class _DayView extends StatefulWidget {
  const _DayView();

  @override
  State<_DayView> createState() => _DayViewState();
}

class _DayViewState extends State<_DayView> {
  DateTime _date = DateTime.now();
  final GlobalKey<DayTimelineState> _timelineKey =
      GlobalKey<DayTimelineState>();

  void _changeDate(DateTime date, {int? minute}) {
    final state = context.read<AppState>();
    state.dayMetaFor(date);
    setState(() => _date = dateOnly(date));
    if (minute != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _timelineKey.currentState?.scrollToMinute(minute);
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) _changeDate(picked);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final mode = state.modeForDate(_date);
    final totals = state.dayTotals(_date);
    final meta = state.metaFor(_date);
    final dayRecords = state.recordsOnDay(_date);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: '上一天',
              onPressed: () =>
                  _changeDate(_date.subtract(const Duration(days: 1))),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    '${_date.year}年${_date.month}月${_date.day}日 ${weekdayName(_date.weekday)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    mode.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: _modeColor(mode),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '下一天',
              onPressed: () => _changeDate(_date.add(const Duration(days: 1))),
              icon: const Icon(Icons.chevron_right),
            ),
            IconButton(
              tooltip: '选择日期',
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_month_outlined),
            ),
          ],
        ),
        if (mode == DayMode.emergency)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Center(
              child: Text(
                '其他模式：仅记录时间，不做目标对比',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        const SizedBox(height: 10),
        DayTimeline(
          key: _timelineKey,
          date: _date,
          onJumpDate: (d, m) => _changeDate(d, minute: m),
        ),
        const SizedBox(height: 10),
        _DayMetaCard(
          title: '备注',
          icon: Icons.sticky_note_2_outlined,
          text: meta?.note ?? '',
          onTap: () => showNoteEditDialog(context, state, _date),
        ),
        const SizedBox(height: 10),
        _DayMetaCard(
          title: '复盘',
          icon: Icons.rate_review_outlined,
          text: meta?.review ?? '',
          onTap: () => showReviewEditDialog(context, state, _date),
        ),
        const SizedBox(height: 12),
        CategoryPieChart(totals: totals, title: '当日分类占比'),
        const SizedBox(height: 12),
        for (final c in AppCategory.values) ...[
          _CategoryBreakdownCard(
            category: c,
            totalSec: totals[c.code] ?? 0,
            breakdown: _breakdown(state, c),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 4),
        _DayRecordsSection(records: dayRecords),
        const SizedBox(height: 24),
      ],
    );
  }

  List<(String, int)> _breakdown(AppState state, AppCategory category) {
    final map = <String, int>{};
    for (final r in state.recordsOnDay(_date)) {
      if (r.categoryCode != category.code) continue;
      final sec = state.recordSecondsOnDay(r, _date);
      map[r.eventName] = (map[r.eventName] ?? 0) + sec;
    }
    final list = map.entries.map((e) => (e.key, e.value)).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    return list;
  }
}

Color _modeColor(DayMode mode) => switch (mode) {
  DayMode.workday => const Color(0xFF3D7BFD),
  DayMode.restday => const Color(0xFF10B981),
  DayMode.emergency => const Color(0xFFEF4444),
};

/// 备注/复盘展示卡片：完整展示不截断，点击弹出独立编辑弹窗。
class _DayMetaCard extends StatelessWidget {
  const _DayMetaCard({
    required this.title,
    required this.icon,
    required this.text,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: scheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '点击编辑',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              if (text.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        text,
                        softWrap: true,
                        style: const TextStyle(fontSize: 13, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 当日计时记录列表：点击编辑、删除。
class _DayRecordsSection extends StatelessWidget {
  const _DayRecordsSection({required this.records});

  final List<TimeRecord> records;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '当日记录（${records.length}）',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
        if (records.isEmpty)
          Text(
            '暂无记录',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          )
        else
          for (final r in records)
            _RecordTile(
              record: r,
              note: state.eventById(r.eventId)?.note ?? '',
              onTap: () => _showEditRecordDialog(context, state, r),
            ),
      ],
    );
  }
}

class _CategoryBreakdownCard extends StatelessWidget {
  const _CategoryBreakdownCard({
    required this.category,
    required this.totalSec,
    required this.breakdown,
  });

  final AppCategory category;
  final int totalSec;
  final List<(String, int)> breakdown;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(category.icon, size: 18, color: category.color),
                const SizedBox(width: 8),
                Text(
                  category.label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  formatDuration(totalSec),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (breakdown.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '当日无记录',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (final (name, sec) in breakdown)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        formatDuration(sec),
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

// ---------------- 周视图 ----------------

class _WeekView extends StatefulWidget {
  const _WeekView();

  @override
  State<_WeekView> createState() => _WeekViewState();
}

class _WeekViewState extends State<_WeekView> {
  DateTime _base = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final stats = state.computeWeekStats(_base);
    final start = stats.weekStart;
    final end = start.add(const Duration(days: 6));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => setState(
                () => _base = start.subtract(const Duration(days: 7)),
              ),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Center(
                child: Text(
                  '${start.month}月${start.day}日 - ${end.month}月${end.day}日',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: () =>
                  setState(() => _base = start.add(const Duration(days: 7))),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 12),
        CategoryPieChart(totals: stats.weekTotals, title: '本周分类占比'),
        const SizedBox(height: 10),
        _ModeAverageCard(
          title: '工作日平均时长',
          subtitle: '共 ${stats.workdayCount} 个工作日',
          color: const Color(0xFF3D7BFD),
          totals: stats.workdayTotals,
          count: stats.workdayCount,
        ),
        const SizedBox(height: 10),
        _ModeAverageCard(
          title: '休息日平均时长',
          subtitle: '共 ${stats.restdayCount} 个休息日',
          color: const Color(0xFF10B981),
          totals: stats.restdayTotals,
          count: stats.restdayCount,
        ),
        if (stats.emergencyDays.isNotEmpty) ...[
          const SizedBox(height: 10),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '其他日期（不计入平均）',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  for (final d in stats.emergencyDays)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_outlined,
                            size: 15,
                            color: Color(0xFFEF4444),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${d.month}月${d.day}日 ${weekdayName(d.weekday)}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        _WeeklyGoalCard(stats: stats),
        const SizedBox(height: 10),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '本周累计',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                for (final c in AppCategory.values)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        Icon(c.icon, size: 16, color: c.color),
                        const SizedBox(width: 6),
                        Text(c.label, style: const TextStyle(fontSize: 13)),
                        const Spacer(),
                        Text(
                          formatDuration(stats.weekTotals[c.code] ?? 0),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WeeklyGoalCard extends StatelessWidget {
  const _WeeklyGoalCard({required this.stats});

  final WeekStats stats;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '周目标完成情况',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (final c in AppCategory.values) ...[
              _GoalRow(
                category: c,
                usedSec: stats.weekTotals[c.code] ?? 0,
                goalSec: state.weekGoalSec(c.code),
              ),
              if (c != AppCategory.values.last) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({
    required this.category,
    required this.usedSec,
    required this.goalSec,
  });

  final AppCategory category;
  final int usedSec;
  final int goalSec;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = goalSec > 0 ? (usedSec / goalSec).clamp(0.0, 1.0) : 0.0;
    final over = goalSec > 0 && usedSec > goalSec;
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Row(
            children: [
              Icon(category.icon, size: 15, color: category.color),
              const SizedBox(width: 4),
              Text(category.label, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: category.color.withValues(alpha: 0.12),
              color: over ? scheme.error : category.color,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 118,
          child: Text(
            goalSec > 0
                ? '${formatDuration(usedSec)} / ${formatTargetMinutes(goalSec ~/ 60)}'
                : formatDuration(usedSec),
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _ModeAverageCard extends StatelessWidget {
  const _ModeAverageCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.totals,
    required this.count,
  });

  final String title;
  final String subtitle;
  final Color color;
  final Map<String, int> totals;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final c in AppCategory.values)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Icon(c.icon, size: 16, color: c.color),
                    const SizedBox(width: 6),
                    Text(c.label, style: const TextStyle(fontSize: 13)),
                    const Spacer(),
                    Text(
                      count > 0
                          ? '平均 ${formatDuration((totals[c.code] ?? 0) ~/ count)}'
                          : '无数据',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------- 记录（标签筛选 + 编辑已完成计时） ----------------

class _RecordsView extends StatefulWidget {
  const _RecordsView();

  @override
  State<_RecordsView> createState() => _RecordsViewState();
}

class _RecordsViewState extends State<_RecordsView> {
  String? _selectedTag;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tags = state.allTags.toList()..sort();
    var records = [...state.data.records]
      ..sort((a, b) => b.startMs.compareTo(a.startMs));
    if (_selectedTag != null) {
      records = records.where((r) => r.tags.contains(_selectedTag)).toList();
    }

    return Column(
      children: [
        if (tags.isNotEmpty)
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                FilterChip(
                  label: const Text('全部'),
                  selected: _selectedTag == null,
                  onSelected: (_) => setState(() => _selectedTag = null),
                ),
                for (final t in tags) ...[
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text(t),
                    selected: _selectedTag == t,
                    onSelected: (_) => setState(() => _selectedTag = t),
                  ),
                ],
              ],
            ),
          ),
        Expanded(
          child: records.isEmpty
              ? Center(
                  child: Text(
                    '暂无记录',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  itemCount: records.length,
                  itemBuilder: (context, i) => _RecordTile(
                    record: records[i],
                    note: state.eventById(records[i].eventId)?.note ?? '',
                    onTap: () =>
                        _showEditRecordDialog(context, state, records[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({
    required this.record,
    required this.note,
    required this.onTap,
  });

  final TimeRecord record;
  final String note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final category = AppCategory.fromCode(record.categoryCode);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: category.color.withValues(alpha: 0.14),
          child: Icon(category.icon, size: 18, color: category.color),
        ),
        title: Text(
          '${record.eventName}'
          '${record.isBackfill ? "（补录）" : ""}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${formatDateTime(record.start)} · ${DayMode.fromCode(record.modeCode).label}'
                '${record.pausedSec > 0 ? " · 暂停 ${formatDuration(record.pausedSec)}" : ""}',
                style: const TextStyle(fontSize: 12),
              ),
              if (note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '备注：$note',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatDuration(record.durationSec),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            if (record.tags.isNotEmpty)
              Text(
                record.tags.map((t) => '#$t').join(' '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: scheme.primary),
              ),
          ],
        ),
      ),
    );
  }
}

void _showEditRecordDialog(
  BuildContext context,
  AppState state,
  TimeRecord record,
) {
  final events = state.sortedEvents();
  if (events.isEmpty) return;
  var selected = state.eventById(record.eventId) ?? events.first;
  var start = record.start;
  var end = record.end;
  final tagsController = TextEditingController(text: record.tags.join(', '));
  final noteController = TextEditingController(text: selected.note);

  showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('编辑计时记录'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<EventItem>(
                initialValue: selected,
                decoration: const InputDecoration(labelText: '事件'),
                items: [
                  for (final e in events)
                    DropdownMenuItem(
                      value: e,
                      child: Text(
                        '${AppCategory.fromCode(e.categoryCode).label} · ${e.name}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      selected = v;
                      noteController.text = v.note;
                    });
                  }
                },
              ),
              const SizedBox(height: 4),
              Text(
                '日期模式：${DayMode.fromCode(record.modeCode).label}'
                '${record.pausedSec > 0 ? " · 暂停累计 ${formatDuration(record.pausedSec)}" : ""}',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 4),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('开始时间'),
                trailing: Text(formatDateTime(start)),
                onTap: () async {
                  final picked = await _pickDateTime(ctx, start);
                  if (picked != null) setState(() => start = picked);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('结束时间'),
                trailing: Text(formatDateTime(end)),
                onTap: () async {
                  final picked = await _pickDateTime(ctx, end);
                  if (picked != null) setState(() => end = picked);
                },
              ),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: '事件备注（保存后同步到事件）',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: tagsController,
                decoration: const InputDecoration(
                  labelText: '标签（逗号分隔）',
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _confirmDeleteRecord(context, state, record);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              state.updateEventNote(selected, noteController.text);
              state.updateRecord(
                record,
                event: selected,
                start: start,
                end: end,
                tags: _parseTags(tagsController.text),
              );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('记录已更新')));
            },
            child: const Text('保存'),
          ),
        ],
      ),
    ),
  );
}

void _confirmDeleteRecord(
  BuildContext context,
  AppState state,
  TimeRecord record,
) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('删除记录'),
      content: Text('确定删除「${record.eventName}」的这条记录吗？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
          ),
          onPressed: () {
            state.deleteRecord(record);
            Navigator.pop(ctx);
          },
          child: const Text('删除'),
        ),
      ],
    ),
  );
}

List<String> _parseTags(String text) => text
    .split(RegExp(r'[,，]'))
    .map((e) => e.trim())
    .where((e) => e.isNotEmpty)
    .toList();

Future<DateTime?> _pickDateTime(BuildContext context, DateTime initial) async {
  final now = DateTime.now();
  final date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2020),
    lastDate: DateTime(now.year + 1),
  );
  if (date == null) return null;
  if (!context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}
