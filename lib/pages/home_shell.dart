import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_monitor.dart';
import '../services/notification_service.dart';
import '../services/reminder_engine.dart';
import '../state/app_state.dart';
import '../widgets/day_meta_dialogs.dart';
import 'home_page.dart';
import 'settings_page.dart';
import 'stats_page.dart';
import 'timer_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  ReminderEngine? _reminderEngine;
  AppMonitor? _appMonitor;
  AppState? _state;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _state = state;
    _reminderEngine = ReminderEngine(state)..start();
    _appMonitor = AppMonitor(state)..start();
    state.scheduleWaterAlarm();
    state.scheduleSleepReminder();
    NotificationService.instance.onNotificationTap = _handleNotificationTap;
    _handleLaunchPayload();
  }

  /// 睡觉提醒通知点击：唤起当日复盘编辑弹窗（含时间分析提示）。
  Future<void> _handleNotificationTap(String? payload) async {
    if (payload == null || !payload.startsWith('sleep_review')) return;
    final ctx = navigatorKey.currentContext;
    final state = _state;
    if (ctx == null || state == null) return;
    await showReviewEditDialog(ctx, state, DateTime.now());
  }

  /// 冷启动时若由睡觉提醒通知拉起，同样打开复盘编辑弹窗。
  Future<void> _handleLaunchPayload() async {
    final payload = await NotificationService.instance.launchPayload();
    if (payload == null || !payload.startsWith('sleep_review')) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleNotificationTap(payload);
    });
  }

  @override
  void dispose() {
    _reminderEngine?.dispose();
    _appMonitor?.dispose();
    if (NotificationService.instance.onNotificationTap ==
        _handleNotificationTap) {
      NotificationService.instance.onNotificationTap = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomePage(onGoTimer: () => setState(() => _index = 1)),
          const TimerPage(),
          const StatsPage(),
          const SettingsPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer),
            label: '计时',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: '统计',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
