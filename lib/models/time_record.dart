class TimeRecord {
  TimeRecord({
    required this.id,
    required this.eventId,
    required this.eventName,
    required this.categoryCode,
    required this.startMs,
    required this.endMs,
    required this.durationSec,
    this.pausedSec = 0,
    List<String>? tags,
    required this.modeCode,
    this.isBackfill = false,
    required this.createdAtMs,
  }) : tags = tags ?? [];

  final String id;
  final String eventId;
  final String eventName;
  final String categoryCode;
  final int startMs;
  final int endMs;

  /// 实际计时总秒数（不含暂停）。
  final int durationSec;

  /// 暂停累计秒数。
  final int pausedSec;

  /// 自定义标签。
  final List<String> tags;

  /// 记录所属日期模式（工作日/休息日/突发情况）。
  final String modeCode;

  /// true 表示手动补录。
  final bool isBackfill;
  final int createdAtMs;

  DateTime get start => DateTime.fromMillisecondsSinceEpoch(startMs);
  DateTime get end => DateTime.fromMillisecondsSinceEpoch(endMs);
  bool get isWorkday => modeCode == 'workday';

  TimeRecord copyWith({
    String? eventId,
    String? eventName,
    String? categoryCode,
    int? startMs,
    int? endMs,
    int? durationSec,
    int? pausedSec,
    List<String>? tags,
    String? modeCode,
  }) => TimeRecord(
    id: id,
    eventId: eventId ?? this.eventId,
    eventName: eventName ?? this.eventName,
    categoryCode: categoryCode ?? this.categoryCode,
    startMs: startMs ?? this.startMs,
    endMs: endMs ?? this.endMs,
    durationSec: durationSec ?? this.durationSec,
    pausedSec: pausedSec ?? this.pausedSec,
    tags: tags ?? this.tags,
    modeCode: modeCode ?? this.modeCode,
    isBackfill: isBackfill,
    createdAtMs: createdAtMs,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'eventId': eventId,
    'eventName': eventName,
    'category': categoryCode,
    'startMs': startMs,
    'endMs': endMs,
    'durationSec': durationSec,
    'pausedSec': pausedSec,
    'tags': tags,
    'modeCode': modeCode,
    'isBackfill': isBackfill,
    'createdAtMs': createdAtMs,
  };

  factory TimeRecord.fromJson(Map<String, dynamic> json) {
    // 兼容旧版本数据：isWorkday 布尔迁移为 modeCode
    var modeCode = (json['modeCode'] ?? '').toString();
    if (modeCode.isEmpty) {
      modeCode = (json['isWorkday'] ?? true) == true ? 'workday' : 'restday';
    }
    return TimeRecord(
      id: (json['id'] ?? '').toString(),
      eventId: (json['eventId'] ?? '').toString(),
      eventName: (json['eventName'] ?? '').toString(),
      categoryCode: (json['category'] ?? 'freeRecovery').toString(),
      startMs: (json['startMs'] as num?)?.toInt() ?? 0,
      endMs: (json['endMs'] as num?)?.toInt() ?? 0,
      durationSec: (json['durationSec'] as num?)?.toInt() ?? 0,
      pausedSec: (json['pausedSec'] as num?)?.toInt() ?? 0,
      tags: ((json['tags'] as List?) ?? const [])
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList(),
      modeCode: modeCode,
      isBackfill: (json['isBackfill'] ?? false) == true,
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
    );
  }
}
