import 'day_mode.dart';
import '../utils/format.dart';

/// 某一天的附加信息：手动模式、备注、每日复盘。
class DayMeta {
  DayMeta({
    required this.date,
    this.modeOverride,
    this.note = '',
    this.review = '',
  });

  final String date;

  /// 手动修改的日期模式；null/空表示跟随默认周规则。
  String? modeOverride;
  String note;
  String review;

  DayMode resolve() {
    if (modeOverride != null && modeOverride!.isNotEmpty) {
      return DayMode.fromCode(modeOverride);
    }
    return DayMode.defaultFor(parseDate(date));
  }

  Map<String, dynamic> toJson() => {
    'date': date,
    'modeOverride': modeOverride,
    'note': note,
    'review': review,
  };

  factory DayMeta.fromJson(Map<String, dynamic> json) => DayMeta(
    date: (json['date'] ?? '').toString(),
    modeOverride: (json['modeOverride'] as String?)?.isNotEmpty == true
        ? (json['modeOverride'] as String)
        : null,
    note: (json['note'] ?? '').toString(),
    review: (json['review'] ?? '').toString(),
  );
}
