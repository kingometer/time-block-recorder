import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/app_data.dart';
import '../models/timer_snapshot.dart';

/// 本地 JSON 文件存储（两端一致：Android 应用目录 / Windows 用户文档目录）。
class StorageService {
  Future<File> _dataFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'time_block_data.json'));
  }

  Future<AppData?> load() async {
    try {
      final file = await _dataFile();
      if (!await file.exists()) return null;
      final text = await file.readAsString();
      if (text.trim().isEmpty) return null;
      final json = jsonDecode(text) as Map<String, dynamic>;
      return AppData.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  Future<void> save(AppData data) async {
    try {
      final file = await _dataFile();
      final content = const JsonEncoder.withIndent('  ').convert(data.toJson());
      await file.writeAsString(content, flush: true);
    } catch (_) {
      // 本地写入失败时静默处理，避免打断计时流程
    }
  }

  Future<File> _timerStateFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'time_block_timer_state.json'));
  }

  Future<TimerSnapshot?> loadTimerState() async {
    try {
      final file = await _timerStateFile();
      if (!await file.exists()) return null;
      final text = await file.readAsString();
      if (text.trim().isEmpty) return null;
      final json = jsonDecode(text) as Map<String, dynamic>;
      return TimerSnapshot.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveTimerState(TimerSnapshot snap) async {
    try {
      final file = await _timerStateFile();
      final content = const JsonEncoder.withIndent('  ').convert(snap.toJson());
      await file.writeAsString(content, flush: true);
    } catch (_) {
      // 静默处理，避免打断计时流程
    }
  }

  Future<void> clearTimerState() async {
    try {
      final file = await _timerStateFile();
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
