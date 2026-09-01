import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../models/day_mode.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/category_progress_card.dart';
import 'events_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.onGoTimer});

  final VoidCallback onGoTimer;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final today = DateTime.now();
    final mode = state.modeForToday;
    final totals = state.dayTotals(today);

    return Scaffold(
      appBar: AppBar(
        title: const Text('时间区块记录器'),
        actions: [
          IconButton(
            tooltip: '事件管理',
            icon: const Icon(Icons.playlist_add_check_outlined),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const EventsPage())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DateModeCard(today: today, mode: mode, state: state),
          const SizedBox(height: 16),
          _NoteReviewCard(today: today, state: state),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              '今日各大类目标进度',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          for (final c in AppCategory.values) ...[
            CategoryProgressCard(
              category: c,
              totalSec: totals[c.code] ?? 0,
              targetSec: state.dayTargetSec(c.code),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onGoTimer,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('开始计时'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _DateModeCard extends StatelessWidget {
  const _DateModeCard({
    required this.today,
    required this.mode,
    required this.state,
  });

  final DateTime today;
  final DayMode mode;
  final AppState state;

  Color get _color => switch (mode) {
    DayMode.workday => const Color(0xFF3D7BFD),
    DayMode.restday => const Color(0xFF10B981),
    DayMode.emergency => const Color(0xFFEF4444),
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasOverride = state.metaFor(today)?.modeOverride != null;
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
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${today.month}/${today.day}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _color,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${today.year}年${today.month}月${today.day}日 ${weekdayName(today.weekday)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasOverride ? '已手动修改今日模式' : '默认：周一至周五·工作日，周六周日·休息日',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    mode.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('修改今日模式', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final m in DayMode.values)
                  ChoiceChip(
                    label: Text(m.label),
                    selected: mode == m,
                    onSelected: (_) {
                      if (mode == m) return;
                      state.setDayModeOverride(today, m);
                    },
                  ),
                if (hasOverride)
                  ActionChip(
                    label: const Text('恢复默认'),
                    onPressed: () => state.clearDayModeOverride(today),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 首页每日备注卡片：只保留简短备注；复盘仅在统计-日视图与睡觉提醒弹窗编辑。
class _NoteReviewCard extends StatelessWidget {
  const _NoteReviewCard({required this.today, required this.state});

  final DateTime today;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final meta = state.metaFor(today);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '今日备注',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            _NoteField(
              hint: '今天有什么安排/注意事项…',
              initial: meta?.note ?? '',
              onSave: (v) => state.setDayNote(today, v),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteField extends StatelessWidget {
  const _NoteField({
    required this.hint,
    required this.initial,
    required this.onSave,
  });

  final String hint;
  final String initial;
  final ValueChanged<String> onSave;

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(text: initial);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            maxLines: null,
            minLines: 1,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: () => onSave(controller.text),
          child: const Text('保存'),
        ),
      ],
    );
  }
}
