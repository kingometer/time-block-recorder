import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../models/event_item.dart';
import '../state/app_state.dart';
import '../utils/format.dart';

class TimerPage extends StatelessWidget {
  const TimerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final session = state.session;
    return Scaffold(
      appBar: AppBar(title: const Text('计时器')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showBackfillDialog(context),
        icon: const Icon(Icons.edit_calendar_outlined),
        label: const Text('补录记录'),
      ),
      body: session == null
          ? _EventPicker(
              onStart: (event) => _openStartSheet(context, state, event),
            )
          : _RunningTimerCard(session: session),
    );
  }

  void _openStartSheet(BuildContext context, AppState state, EventItem event) {
    var countdown = false;
    var estimateMin = 60;
    final estimateController = TextEditingController(text: '60');
    final noteController = TextEditingController(text: event.note);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '开始「${event.name}」',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '分类：${AppCategory.fromCode(event.categoryCode).label}',
                  style: const TextStyle(fontSize: 13),
                ),
                if (event.note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '备注：${event.note}',
                    softWrap: true,
                    maxLines: null,
                    overflow: TextOverflow.visible,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  maxLines: 2,
                  minLines: 1,
                  decoration: const InputDecoration(
                    labelText: '本次备注（可选，保存到事件）',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 16),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('正计时')),
                    ButtonSegment(value: true, label: Text('倒计时')),
                  ],
                  selected: {countdown},
                  onSelectionChanged: (s) =>
                      setState(() => countdown = s.first),
                ),
                if (countdown) ...[
                  const SizedBox(height: 14),
                  const Text('预估时长', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final m in [15, 30, 45, 60, 90, 120, 180])
                        ChoiceChip(
                          label: Text('$m 分钟'),
                          selected: estimateMin == m,
                          onSelected: (_) => setState(() {
                            estimateMin = m;
                            estimateController.text = '$m';
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: estimateController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '自定义分钟数',
                      suffixText: '分钟',
                      isDense: true,
                    ),
                    onChanged: (v) {
                      final n = int.tryParse(v.trim());
                      if (n != null && n > 0) estimateMin = n;
                    },
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetCtx),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(sheetCtx);
                          state.updateEventNote(event, noteController.text);
                          state.startTimer(
                            event,
                            countdown: countdown,
                            estimateSec: estimateMin * 60,
                          );
                        },
                        child: const Text('开始计时'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showBackfillDialog(BuildContext context) async {
    final state = context.read<AppState>();
    if (state.data.events.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先在「事件管理」中创建事件')));
      return;
    }
    final events = state.sortedEvents();
    var selected = events.first;
    var start = DateTime.now().subtract(const Duration(hours: 1));
    var end = DateTime.now();
    final tagsController = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('补录历史记录'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<EventItem>(
                  initialValue: selected,
                  decoration: const InputDecoration(labelText: '事件'),
                  items: [
                    for (final e in events)
                      DropdownMenuItem(
                        value: e,
                        child: Text(
                          '${e.favorite ? "★ " : ""}${AppCategory.fromCode(e.categoryCode).label} · ${e.name}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => selected = v);
                  },
                ),
                const SizedBox(height: 8),
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
                  controller: tagsController,
                  decoration: const InputDecoration(
                    labelText: '标签（逗号分隔，可选）',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '时长：${formatDuration(end.difference(start).inSeconds)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                state.addBackfill(
                  event: selected,
                  start: start,
                  end: end,
                  tags: _parseTags(tagsController.text),
                );
                Navigator.pop(ctx, true);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('补录记录已保存')));
    }
  }
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

class _EventPicker extends StatelessWidget {
  const _EventPicker({required this.onStart});

  final ValueChanged<EventItem> onStart;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final favorites = state.sortedEvents().where((e) => e.favorite).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        if (favorites.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(top: 6, bottom: 6),
            child: Row(
              children: [
                Icon(Icons.star, size: 16, color: Color(0xFFF5A524)),
                SizedBox(width: 6),
                Text(
                  '收藏（置顶）',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          for (final e in favorites) _EventTile(event: e, onStart: onStart),
        ],
        for (final c in AppCategory.values) ...[
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Row(
              children: [
                Icon(c.icon, size: 18, color: c.color),
                const SizedBox(width: 6),
                Text(
                  c.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          for (final e in state.eventsOf(c))
            if (!e.favorite) _EventTile(event: e, onStart: onStart),
        ],
        const SizedBox(height: 8),
        Center(
          child: Text(
            '选择事件开始计时；支持正计时与倒计时，结束自动保存记录',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event, required this.onStart});

  final EventItem event;
  final ValueChanged<EventItem> onStart;

  @override
  Widget build(BuildContext context) {
    final category = AppCategory.fromCode(event.categoryCode);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: category.color.withValues(alpha: 0.14),
          child: Icon(category.icon, size: 18, color: category.color),
        ),
        title: Text(event.name),
        trailing: const Icon(Icons.play_circle_outline),
        onTap: () => onStart(event),
      ),
    );
  }
}

class _RunningTimerCard extends StatefulWidget {
  const _RunningTimerCard({required this.session});

  final TimerSession session;

  @override
  State<_RunningTimerCard> createState() => _RunningTimerCardState();
}

class _RunningTimerCardState extends State<_RunningTimerCard> {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final session = state.session;
    if (session == null) return const SizedBox.shrink();
    final category = AppCategory.fromCode(session.event.categoryCode);
    final scheme = Theme.of(context).colorScheme;
    final displaySec = session.countdown
        ? session.remainingSec
        : session.elapsedRunningSec;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: category.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${category.label} · ${session.event.name}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: category.color,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  session.countdown ? '倒计时' : '正计时',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  formatClock(displaySec),
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  session.running ? '计时中' : '已暂停',
                  style: TextStyle(
                    fontSize: 14,
                    color: session.running
                        ? const Color(0xFF10B981)
                        : scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '暂停累计：${formatDuration(session.pausedTotalMs ~/ 1000)}　'
                  '开始于 ${formatHM(session.startedAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (session.event.note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '备注：${session.event.note}',
                      softWrap: true,
                      maxLines: null,
                      overflow: TextOverflow.visible,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (session.countdown)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '预估 ${formatTargetMinutes(session.estimateSec ~/ 60)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => _editRunningNote(context, state, session.event),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
          icon: const Icon(Icons.sticky_note_2_outlined),
          label: const Text('编辑备注'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: session.running
                    ? state.pauseTimer
                    : state.resumeTimer,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                icon: Icon(session.running ? Icons.pause : Icons.play_arrow),
                label: Text(session.running ? '暂停' : '继续'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _confirmEnd(context, state),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                ),
                icon: const Icon(Icons.stop),
                label: const Text('结束'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => _confirmDiscard(context, state),
          child: const Text('放弃本次计时（不保存）'),
        ),
      ],
    );
  }

  void _confirmEnd(BuildContext context, AppState state) {
    final session = state.session;
    if (session == null) return;
    final tagsController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('结束计时'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '确定结束「${session.event.name}」吗？\n'
              '本次${session.countdown ? "倒计时" : "实际计时"} ${formatDuration(session.elapsedRunningSec)}。',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: tagsController,
              decoration: const InputDecoration(
                labelText: '标签（逗号分隔，可选）',
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              state.endTimer(tags: _parseTags(tagsController.text));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('记录已保存')));
            },
            child: const Text('结束并保存'),
          ),
        ],
      ),
    );
  }

  void _editRunningNote(BuildContext context, AppState state, EventItem event) {
    final controller = TextEditingController(text: event.note);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑备注'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          minLines: 2,
          decoration: const InputDecoration(
            labelText: '事件备注',
            hintText: '记录要点、想法或计划…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              state.updateEventNote(event, controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _confirmDiscard(BuildContext context, AppState state) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('放弃计时'),
        content: const Text('确定放弃本次计时吗？本次记录不会保存。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              state.discardTimer();
              Navigator.pop(ctx);
            },
            child: const Text('放弃'),
          ),
        ],
      ),
    );
  }
}
