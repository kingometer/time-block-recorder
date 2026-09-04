import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../models/event_item.dart';
import '../state/app_state.dart';
import '../utils/format.dart';

class EventsPage extends StatelessWidget {
  const EventsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('事件管理')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditDialog(context, state, null),
        icon: const Icon(Icons.add),
        label: const Text('新建事件'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          for (final c in AppCategory.values) ...[
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Row(
                children: [
                  Icon(c.icon, size: 18, color: c.color),
                  const SizedBox(width: 6),
                  Text(
                    '${c.label}（${state.eventsOf(c).length}）',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            for (final e in state.eventsOf(c))
              _EventTile(
                event: e,
                favorite: e.favorite,
                onToggleFavorite: () => state.toggleFavorite(e),
                onEdit: () => _showEditDialog(context, state, e),
                onDelete: () => _confirmDelete(context, state, e),
              ),
          ],
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, AppState state, EventItem? event) {
    final nameController = TextEditingController(text: event?.name ?? '');
    final noteController = TextEditingController(text: event?.note ?? '');
    AppCategory category = event != null
        ? AppCategory.fromCode(event.categoryCode)
        : AppCategory.workStudy;
    var planTomorrow = false;
    final tomorrow = dateOnly(DateTime.now().add(const Duration(days: 1)));
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(event == null ? '新建事件' : '编辑事件'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: '事件名称'),
                ),
                if (event == null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text(
                        '归属日期',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SegmentedButton<bool>(
                          showSelectedIcon: false,
                          style: const ButtonStyle(
                            visualDensity: VisualDensity.compact,
                          ),
                          segments: const [
                            ButtonSegment(value: false, label: Text('今天')),
                            ButtonSegment(value: true, label: Text('明天')),
                          ],
                          selected: {planTomorrow},
                          onSelectionChanged: (s) =>
                              setState(() => planTomorrow = s.first),
                        ),
                      ),
                    ],
                  ),
                  if (planTomorrow)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '同时创建事件并预录到明天（${tomorrow.month}月${tomorrow.day}日），'
                        '届时可在 统计-日视图 查看该事件与备注',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  maxLines: 3,
                  minLines: 2,
                  decoration: const InputDecoration(
                    labelText: '备注（可选）',
                    hintText: '例如：本周要复习的章节、健身计划…',
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<AppCategory>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: '归属分类'),
                  items: [
                    for (final c in AppCategory.values)
                      DropdownMenuItem(value: c, child: Text(c.label)),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => category = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                if (event == null) {
                  final created = state.addEvent(
                    name,
                    category,
                    note: noteController.text,
                  );
                  if (planTomorrow && created != null) {
                    state.addPlan(tomorrow, event: created);
                  }
                } else {
                  state.updateEvent(event, name, category);
                  state.updateEventNote(event, noteController.text);
                }
                Navigator.pop(ctx);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppState state, EventItem event) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除事件'),
        content: Text('确定删除「${event.name}」吗？历史计时记录会保留。'),
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
              state.deleteEvent(event);
              Navigator.pop(ctx);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.event,
    required this.favorite,
    required this.onToggleFavorite,
    required this.onEdit,
    required this.onDelete,
  });

  final EventItem event;
  final bool favorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(event.name),
            if (event.note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  event.note,
                  softWrap: true,
                  maxLines: null,
                  overflow: TextOverflow.visible,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: favorite ? '取消收藏' : '收藏（选择列表置顶）',
              icon: Icon(
                favorite ? Icons.star : Icons.star_border,
                size: 20,
                color: favorite ? const Color(0xFFF5A524) : null,
              ),
              onPressed: onToggleFavorite,
            ),
            IconButton(
              tooltip: '编辑',
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: onEdit,
            ),
            IconButton(
              tooltip: '删除',
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
