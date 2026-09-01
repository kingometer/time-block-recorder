/// 运行中/暂停中计时器的持久化快照，用于应用被杀后台后恢复计时。
class TimerSnapshot {
  TimerSnapshot({
    required this.status,
    required this.eventId,
    required this.startedAtMs,
    required this.elapsedRunningMs,
    required this.pausedMs,
    required this.countdown,
    required this.estimateSec,
  });

  /// 'running' 或 'paused'。
  final String status;
  final String eventId;

  /// 本次计时原始开始时间戳（毫秒）。
  final int startedAtMs;

  /// 保存时刻已累计的计时毫秒数（不含当前运行段/当前暂停段）。
  final int elapsedRunningMs;

  /// 保存时刻已完成的暂停累计毫秒数。
  final int pausedMs;

  final bool countdown;
  final int estimateSec;

  bool get isRunning => status == 'running';

  Map<String, dynamic> toJson() => {
    'status': status,
    'eventId': eventId,
    'startedAtMs': startedAtMs,
    'elapsedRunningMs': elapsedRunningMs,
    'pausedMs': pausedMs,
    'countdown': countdown,
    'estimateSec': estimateSec,
  };

  factory TimerSnapshot.fromJson(Map<String, dynamic> json) => TimerSnapshot(
    status: (json['status'] ?? 'paused').toString(),
    eventId: (json['eventId'] ?? '').toString(),
    startedAtMs: (json['startedAtMs'] as num?)?.toInt() ?? 0,
    elapsedRunningMs: (json['elapsedRunningMs'] as num?)?.toInt() ?? 0,
    pausedMs: (json['pausedMs'] as num?)?.toInt() ?? 0,
    countdown: (json['countdown'] ?? false) == true,
    estimateSec: (json['estimateSec'] as num?)?.toInt() ?? 0,
  );
}
