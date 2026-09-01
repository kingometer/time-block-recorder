import '../utils/format.dart';

/// 每日日期模式：工作日、休息日、其他（特殊日期仅记录时间）。
enum DayMode {
  workday('workday', '工作日'),
  restday('restday', '休息日'),
  emergency('emergency', '其他');

  const DayMode(this.code, this.label);

  final String code;
  final String label;

  static DayMode fromCode(String? code) {
    for (final m in DayMode.values) {
      if (m.code == code) return m;
    }
    return DayMode.workday;
  }

  /// 默认周规则：周一至周五工作日，周六周日休息日。
  static DayMode defaultFor(DateTime date) =>
      isWorkday(date) ? DayMode.workday : DayMode.restday;
}
