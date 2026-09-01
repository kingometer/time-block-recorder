import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/category.dart';
import '../models/day_mode.dart';
import '../state/app_state.dart';
import 'notification_service.dart';

/// 工作时段娱乐提醒监控：
/// - 仅在工作学习计时运行、且当日非其他模式、总开关开启时轮询；
/// - Android 检测前台 App（需要“使用情况访问”权限），Windows 检测前台窗口标题；
/// - iOS 不启用该模块；只做提醒，不强制关闭、不锁机。
class AppMonitor {
  AppMonitor(this._state);

  final AppState _state;
  static const MethodChannel _channel = MethodChannel(
    'time_block_recorder/app_monitor',
  );

  Timer? _timer;
  String? _lastHit;

  void start() {
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
  }

  bool get _active {
    if (kIsWeb) return false;
    if (!_state.data.settings.entertainmentEnabled) return false;
    if (_state.modeForToday == DayMode.emergency) return false;
    final t = _state.session;
    if (t == null || !t.running) return false;
    return t.event.categoryCode == AppCategory.workStudy.code;
  }

  Future<void> _poll() async {
    if (!_active) {
      _lastHit = null;
      return;
    }
    if (!Platform.isAndroid && !Platform.isWindows) return;
    String? foreground;
    try {
      foreground = await _channel.invokeMethod<String>('getForegroundApp');
    } catch (_) {
      return;
    }
    if (foreground == null || foreground.trim().isEmpty) return;
    final hit = _match(foreground);
    if (hit == null) {
      _lastHit = null;
      return;
    }
    if (hit == _lastHit) return; // 避免同一应用重复提醒
    _lastHit = hit;
    await NotificationService.instance.show(
      NotificationService.idEntertainment,
      '娱乐提醒',
      '当前处于工作学习计时，请勿使用娱乐应用（$hit）',
    );
    _state.showEntertainmentAlert(hit);
  }

  String? _match(String foreground) {
    final fg = _normalize(foreground);
    if (fg.isEmpty) return null;
    for (final app in _state.data.settings.entertainmentApps) {
      final a = _normalize(app);
      if (a.isNotEmpty && (fg.contains(a) || a.contains(fg))) return app;
    }
    return null;
  }

  String _normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[\s.\-_（）()\[\]【】]'), '');

  void dispose() {
    _timer?.cancel();
  }
}
