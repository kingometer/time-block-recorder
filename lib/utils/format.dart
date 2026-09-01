import 'dart:math';

/// 两位数字补零。
String two(int n) => n.toString().padLeft(2, '0');

/// 日期键：yyyy-MM-dd。
String dateKey(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

/// 解析 yyyy-MM-dd 为当天零点。
DateTime parseDate(String key) {
  final parts = key.split('-');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

/// 取当天零点。
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String formatDateTime(DateTime d) =>
    '${dateKey(d)} ${two(d.hour)}:${two(d.minute)}';

String formatHM(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

/// HH:MM:SS 时钟文本。
String formatClock(int totalSeconds) {
  final s = totalSeconds % 60;
  final m = (totalSeconds ~/ 60) % 60;
  final h = totalSeconds ~/ 3600;
  return '${two(h)}:${two(m)}:${two(s)}';
}

/// 时长文本：如 "2小时05分" / "45分20秒" / "30秒"。
String formatDuration(int totalSeconds) {
  if (totalSeconds < 0) totalSeconds = 0;
  final s = totalSeconds % 60;
  final m = (totalSeconds ~/ 60) % 60;
  final h = totalSeconds ~/ 3600;
  if (h > 0) return '$h小时${two(m)}分';
  if (m > 0) return '$m分${two(s)}秒';
  return '$s秒';
}

/// 目标时长文本（输入为分钟）。
String formatTargetMinutes(int minutes) {
  if (minutes <= 0) return '未设置';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h > 0 && m > 0) return '$h小时$m分';
  if (h > 0) return '$h小时';
  return '$m分钟';
}

/// 默认周规则：周一至周五为工作日，周六周日为休息日。
bool isWorkday(DateTime date) =>
    date.weekday >= DateTime.monday && date.weekday <= DateTime.friday;

/// 所在周的周一。
DateTime startOfWeek(DateTime d) =>
    dateOnly(d).subtract(Duration(days: d.weekday - 1));

String weekdayName(int weekday) {
  const names = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  return names[weekday - 1];
}

final Random _random = Random();

/// 生成本地唯一 id。
String newId() =>
    '${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(0xFFFFFF)}';
