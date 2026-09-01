import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/app_settings.dart';
import '../models/category.dart';
import '../models/day_mode.dart';
import '../state/app_state.dart';
import '../utils/format.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionTitle('主题'),
          const _ThemeCard(),
          const SizedBox(height: 20),
          _SectionTitle('每日目标（分钟）'),
          const _DailyTargetCard(mode: DayMode.workday),
          const SizedBox(height: 10),
          const _DailyTargetCard(mode: DayMode.restday),
          const SizedBox(height: 20),
          _SectionTitle('周目标（分钟/周）'),
          const _WeeklyGoalCard(),
          const SizedBox(height: 20),
          _SectionTitle('休息喝水提醒'),
          const _WaterReminderCard(),
          const SizedBox(height: 10),
          _SectionTitle('每日睡觉提醒'),
          const _SleepReminderCard(),
          const SizedBox(height: 20),
          _SectionTitle('工作时段娱乐提醒'),
          const _EntertainmentCard(),
          if (kIsWeb || (!Platform.isAndroid && !Platform.isWindows))
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('iOS 平台不提供前台应用监控模块', style: TextStyle(fontSize: 12)),
            ),
          const SizedBox(height: 20),
          _SectionTitle('数据管理'),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                _ActionTile(
                  icon: Icons.upload_file_outlined,
                  title: '导出 JSON 备份',
                  subtitle: '导出全部数据为一个 JSON 文件',
                  onTap: () =>
                      _runTask(context, context.read<AppState>().exportAllJson),
                ),
                const Divider(height: 1),
                _ActionTile(
                  icon: Icons.download_outlined,
                  title: '导入 JSON 合并',
                  subtitle: '选择备份文件，新时间戳记录覆盖旧记录',
                  onTap: () => _runTask(
                    context,
                    context.read<AppState>().importMergeJson,
                  ),
                ),
                const Divider(height: 1),
                _ActionTile(
                  icon: Icons.table_chart_outlined,
                  title: '导出 CSV 备份',
                  subtitle: '导出全部计时记录为 CSV（可用 Excel 打开）',
                  onTap: () =>
                      _runTask(context, context.read<AppState>().exportAllCsv),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle('关于'),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '时间区块记录器 v2.2（完整版）',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '· 数据全部保存在本机，无网络、无账号、无广告、无锁机\n'
                    '· 手机与电脑之间通过 JSON 文件手动拷贝同步\n'
                    '· 默认周规则：周一至周五工作日，周六周日休息日\n'
                    '· 娱乐提醒仅弹窗提示，不强制关闭、不拦截',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.6,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _runTask(
    BuildContext context,
    Future<String?> Function() task,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await task();
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(result ?? '已取消')));
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('操作失败：$e')));
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

// ---------------- 主题 ----------------

class _ThemeCard extends StatelessWidget {
  const _ThemeCard();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'light', label: Text('浅色')),
            ButtonSegment(value: 'dark', label: Text('深色')),
            ButtonSegment(value: 'system', label: Text('跟随系统')),
          ],
          selected: {state.data.settings.themeMode},
          onSelectionChanged: (s) => state.setThemeMode(s.first),
        ),
      ),
    );
  }
}

// ---------------- 每日目标 ----------------

class _DailyTargetCard extends StatelessWidget {
  const _DailyTargetCard({required this.mode});

  final DayMode mode;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final color = switch (mode) {
      DayMode.workday => const Color(0xFF3D7BFD),
      DayMode.restday => const Color(0xFF10B981),
      DayMode.emergency => const Color(0xFFEF4444),
    };
    final totalMin = state.data.settings.dailyTotalMin(mode);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        title: Text(
          '${mode.label}每日目标',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '合计 ${formatTargetMinutes(totalMin)}'
          '（上限 ${formatTargetMinutes(AppSettings.maxDailyTotalMin)}）',
          style: const TextStyle(fontSize: 12),
        ),
        shape: const Border(),
        collapsedShape: const Border(),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: [
          for (final c in AppCategory.values)
            _TargetRow(
              category: c,
              mode: mode,
              minutes: state.data.settings.targetMinutes(c.code, mode),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '提示：五大分类每日目标合计不能超过 24 小时（1440 分钟）',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TargetRow extends StatelessWidget {
  const _TargetRow({
    required this.category,
    required this.mode,
    required this.minutes,
  });

  final AppCategory category;
  final DayMode mode;
  final int minutes;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(category.icon, size: 18, color: category.color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(category.label, style: const TextStyle(fontSize: 14)),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove_circle_outline, size: 20),
            onPressed: () => state.setTarget(category.code, mode, minutes - 15),
          ),
          InkWell(
            onTap: () => _editExact(context, state),
            child: Text(
              '$minutes 分钟',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_circle_outline, size: 20),
            onPressed: () => state.setTarget(category.code, mode, minutes + 15),
          ),
        ],
      ),
    );
  }

  void _editExact(BuildContext context, AppState state) {
    final controller = TextEditingController(text: '$minutes');
    final maxAllowed = state.data.settings.maxDailyMinutes(category.code, mode);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${category.label} · ${mode.label}目标（分钟）'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                suffixText: '分钟',
                helperText: '剩余可分配：${formatTargetMinutes(maxAllowed)}',
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
              final value = int.tryParse(controller.text.trim());
              if (value == null) {
                ScaffoldMessenger.of(
                  ctx,
                ).showSnackBar(const SnackBar(content: Text('请输入有效数字')));
                return;
              }
              if (value > maxAllowed) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text(
                      '超出上限：该分类最多可设 ${formatTargetMinutes(maxAllowed)}'
                      '（每日合计不能超过 24 小时）',
                    ),
                  ),
                );
                return;
              }
              state.setTarget(category.code, mode, value);
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}

// ---------------- 周目标 ----------------

class _WeeklyGoalCard extends StatelessWidget {
  const _WeeklyGoalCard();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final totalMin = state.data.settings.weeklyTotalMin();
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: const Icon(Icons.calendar_view_week_outlined, size: 20),
        title: const Text(
          '周目标',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '合计 ${formatTargetMinutes(totalMin)}'
          '（上限 ${formatTargetMinutes(AppSettings.maxWeeklyTotalMin)}）',
          style: const TextStyle(fontSize: 12),
        ),
        shape: const Border(),
        collapsedShape: const Border(),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: [
          for (final c in AppCategory.values)
            _WeekGoalRow(
              category: c,
              minutes: state.data.settings.weeklyGoals[c.code] ?? 0,
            ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '提示：五大分类每周目标合计不能超过 168 小时（10080 分钟）',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekGoalRow extends StatelessWidget {
  const _WeekGoalRow({required this.category, required this.minutes});

  final AppCategory category;
  final int minutes;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(category.icon, size: 18, color: category.color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(category.label, style: const TextStyle(fontSize: 14)),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove_circle_outline, size: 20),
            onPressed: () => state.setWeeklyGoal(category.code, minutes - 60),
          ),
          InkWell(
            onTap: () => _editExact(context, state),
            child: Text(
              '$minutes 分钟',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_circle_outline, size: 20),
            onPressed: () => state.setWeeklyGoal(category.code, minutes + 60),
          ),
        ],
      ),
    );
  }

  void _editExact(BuildContext context, AppState state) {
    final controller = TextEditingController(text: '$minutes');
    final maxAllowed = state.data.settings.maxWeeklyMinutes(category.code);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${category.label} 周目标（分钟）'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                suffixText: '分钟/周',
                helperText: '剩余可分配：${formatTargetMinutes(maxAllowed)}',
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
              final value = int.tryParse(controller.text.trim());
              if (value == null) {
                ScaffoldMessenger.of(
                  ctx,
                ).showSnackBar(const SnackBar(content: Text('请输入有效数字')));
                return;
              }
              if (value > maxAllowed) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text(
                      '超出上限：该分类最多可设 ${formatTargetMinutes(maxAllowed)}'
                      '（每周合计不能超过 168 小时）',
                    ),
                  ),
                );
                return;
              }
              state.setWeeklyGoal(category.code, value);
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}

// ---------------- 喝水提醒 ----------------

class _WaterReminderCard extends StatelessWidget {
  const _WaterReminderCard();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('休息喝水定时提醒'),
              subtitle: const Text('所有日期模式均生效'),
              value: state.data.settings.waterEnabled,
              onChanged: state.setWaterEnabled,
            ),
            Row(
              children: [
                const Text('间隔', style: TextStyle(fontSize: 14)),
                Expanded(
                  child: Slider(
                    min: 30,
                    max: 120,
                    divisions: 18,
                    value: state.data.settings.waterIntervalMin.toDouble(),
                    label: '${state.data.settings.waterIntervalMin} 分钟',
                    onChanged: state.data.settings.waterEnabled
                        ? (v) => state.setWaterInterval(v.round())
                        : null,
                  ),
                ),
                Text(
                  '${state.data.settings.waterIntervalMin} 分钟',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- 娱乐提醒 ----------------

// ---------------- 每日睡觉提醒 ----------------

class _SleepReminderCard extends StatelessWidget {
  const _SleepReminderCard();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final settings = state.data.settings;
    final timeText =
        '${two(settings.sleepReminderHour)}:${two(settings.sleepReminderMinute)}';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('每日睡觉提醒'),
              subtitle: const Text('默认 23:00，到点提醒完成今日复盘'),
              value: settings.sleepReminderEnabled,
              onChanged: state.setSleepReminderEnabled,
            ),
            Row(
              children: [
                const Text('提醒时间', style: TextStyle(fontSize: 14)),
                const Spacer(),
                TextButton.icon(
                  onPressed: settings.sleepReminderEnabled
                      ? () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(
                              hour: settings.sleepReminderHour,
                              minute: settings.sleepReminderMinute,
                            ),
                          );
                          if (picked != null) {
                            state.setSleepReminderTime(
                              picked.hour,
                              picked.minute,
                            );
                          }
                        }
                      : null,
                  icon: const Icon(Icons.access_time, size: 18),
                  label: Text(
                    timeText,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EntertainmentCard extends StatelessWidget {
  const _EntertainmentCard();

  static const _channel = MethodChannel('time_block_recorder/app_monitor');

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('娱乐提醒总开关'),
              subtitle: const Text('工作学习计时时检测娱乐应用/窗口，其他模式自动关闭'),
              value: state.data.settings.entertainmentEnabled,
              onChanged: state.setEntertainmentEnabled,
            ),
            if (!kIsWeb && Platform.isAndroid)
              _AndroidUsageAccessTile(channel: _channel),
            if (!kIsWeb && Platform.isWindows)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'Windows：检测当前前台窗口标题，无需额外权限',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            const Divider(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '娱乐应用/软件列表',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: '新增',
                  icon: const Icon(Icons.add),
                  onPressed: () => _addApp(context, state),
                ),
              ],
            ),
            if (state.data.settings.entertainmentApps.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('列表为空，监控不生效', style: TextStyle(fontSize: 12)),
              )
            else
              for (final app in state.data.settings.entertainmentApps)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.apps, size: 18),
                  title: Text(app, style: const TextStyle(fontSize: 13)),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => state.removeEntertainmentApp(app),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  void _addApp(BuildContext context, AppState state) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新增娱乐应用'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '应用名 / 包名 / 窗口标题关键词'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              state.addEntertainmentApp(controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}

class _AndroidUsageAccessTile extends StatefulWidget {
  const _AndroidUsageAccessTile({required this.channel});

  final MethodChannel channel;

  @override
  State<_AndroidUsageAccessTile> createState() =>
      _AndroidUsageAccessTileState();
}

class _AndroidUsageAccessTileState extends State<_AndroidUsageAccessTile> {
  bool? _granted;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final ok =
          await widget.channel.invokeMethod<bool>('hasUsageAccess') ?? false;
      if (mounted) setState(() => _granted = ok);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            _granted == true ? Icons.check_circle_outline : Icons.info_outline,
            size: 18,
            color: _granted == true ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _granted == true
                  ? '已授予“使用情况访问”权限'
                  : 'Android 需要“使用情况访问”权限才能检测前台 App',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          if (_granted != true)
            TextButton(
              onPressed: () async {
                await widget.channel.invokeMethod('openUsageAccessSettings');
                await Future.delayed(const Duration(milliseconds: 800));
                await _check();
              },
              child: const Text('去授权'),
            ),
        ],
      ),
    );
  }
}
