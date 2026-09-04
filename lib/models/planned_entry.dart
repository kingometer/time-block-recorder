/// 某一天的「预录入」计划条目：仅登记事件与备注，不产生计时时长。
/// 不直接参与统计/时间轴渲染，只在所属日期（到达后）的日视图中展示，
/// 用户当天按计划开始计时后才生成真实计时记录。
class PlannedEntry {
  PlannedEntry({
    required this.id,
    required this.eventId,
    required this.eventName,
    required this.categoryCode,
    required this.date,
    this.note = '',
    required this.createdAtMs,
  });

  final String id;

  /// 关联事件 id；事件被删除后仍保留名称快照用于展示。
  final String eventId;

  /// 事件名称快照。
  final String eventName;
  final String categoryCode;

  /// 归属日期键：yyyy-MM-dd。
  final String date;

  /// 预录备注（可编辑）。
  String note;
  final int createdAtMs;

  Map<String, dynamic> toJson() => {
    'id': id,
    'eventId': eventId,
    'eventName': eventName,
    'category': categoryCode,
    'date': date,
    'note': note,
    'createdAtMs': createdAtMs,
  };

  factory PlannedEntry.fromJson(Map<String, dynamic> json) => PlannedEntry(
    id: (json['id'] ?? '').toString(),
    eventId: (json['eventId'] ?? '').toString(),
    eventName: (json['eventName'] ?? '').toString(),
    categoryCode: (json['category'] ?? 'freeRecovery').toString(),
    date: (json['date'] ?? '').toString(),
    note: (json['note'] ?? '').toString(),
    createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
  );
}
