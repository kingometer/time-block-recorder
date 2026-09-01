import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../models/time_record.dart';
import '../state/app_state.dart';
import '../utils/format.dart';

/// 时间轴分类（学习-蓝 / 工作-绿 / 娱乐-橙 / 其他-灰）。
const List<String> kTimelineLabels = ['学习', '工作', '娱乐', '其他'];

Color timelineColor(String label) => switch (label) {
  '学习' => const Color(0xFF3D7BFD),
  '工作' => const Color(0xFF10B981),
  '娱乐' => const Color(0xFFF5A524),
  _ => const Color(0xFF9CA3AF),
};

/// 记录在时间轴上的默认分类（优先取标签，其次按事件分类映射）。
String timelineLabelForRecord(TimeRecord r) {
  for (final t in r.tags) {
    if (kTimelineLabels.contains(t)) return t;
  }
  return switch (AppCategory.fromCode(r.categoryCode)) {
    AppCategory.workStudy => '学习',
    AppCategory.entertainment => '娱乐',
    _ => '其他',
  };
}

/// 时间轴中的一个时间块：真实计时块或系统填充的空白「其他」块。
class TimelineSegment {
  TimelineSegment({
    required this.startMin,
    required this.endMin,
    required this.isGap,
    required this.label,
    required this.records,
  });

  /// 距当日 0 点的分钟数（0-1440）。
  final int startMin;
  final int endMin;
  final bool isGap;
  final String label;
  final List<TimeRecord> records;

  int get durationMin => endMin - startMin;
  int get centerMin => (startMin + endMin) ~/ 2;
}

/// 生成某天 0-24 小时完整覆盖的时间块序列（空隙自动填充「其他」）。
List<TimelineSegment> buildTimelineSegments(
  List<TimeRecord> dayRecords,
  DateTime date,
) {
  final dayStart = dateOnly(date).millisecondsSinceEpoch;
  final dayEndMs = dayStart + const Duration(days: 1).inMilliseconds;
  final records = [...dayRecords]
    ..sort((a, b) => a.startMs.compareTo(b.startMs));
  final segments = <TimelineSegment>[];
  var cursor = 0;
  for (final r in records) {
    final s = math.max(r.startMs, dayStart);
    final e = math.min(r.endMs, dayEndMs);
    if (e <= s) continue;
    final sMin = ((s - dayStart) / 60000).floor().clamp(0, 1440);
    final eMin = ((e - dayStart) / 60000).ceil().clamp(0, 1440);
    if (sMin > cursor) {
      segments.add(
        TimelineSegment(
          startMin: cursor,
          endMin: sMin,
          isGap: true,
          label: '其他',
          records: const [],
        ),
      );
    }
    final segStart = math.max(cursor, sMin);
    final segEnd = math.min(1440, math.max(segStart + 1, eMin));
    if (segEnd > segStart) {
      segments.add(
        TimelineSegment(
          startMin: segStart,
          endMin: segEnd,
          isGap: false,
          label: timelineLabelForRecord(r),
          records: [r],
        ),
      );
      cursor = segEnd;
    }
  }
  if (cursor < 1440) {
    segments.add(
      TimelineSegment(
        startMin: cursor,
        endMin: 1440,
        isGap: true,
        label: '其他',
        records: const [],
      ),
    );
  }
  return segments;
}

/// 选择时间轴分类的弹窗。
Future<String?> showTimelineCategoryPicker(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('选择时间轴分类'),
      children: [
        for (final label in kTimelineLabels)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, label),
            child: Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: timelineColor(label),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(label),
              ],
            ),
          ),
      ],
    ),
  );
}

/// 统计-日视图的 24 小时纵向时间轴：顶部缩略总览 + 下方详细可滚动时间轴。
class DayTimeline extends StatefulWidget {
  const DayTimeline({super.key, required this.date, required this.onJumpDate});

  final DateTime date;

  /// 跨日期联动：切换到目标日期并定位到指定分钟。
  final void Function(DateTime date, int minuteOfDay) onJumpDate;

  @override
  State<DayTimeline> createState() => DayTimelineState();
}

class DayTimelineState extends State<DayTimeline> {
  static const double _defaultPixelsPerHour = 72;
  static const double _minPixelsPerHour = 40;
  static const double _maxPixelsPerHour = 140;
  static const double _pixelsPerHourStep = 8;
  static const double _miniHeight = 56;

  final ScrollController _controller = ScrollController();
  double _pixelsPerHour = _defaultPixelsPerHour;

  double get _totalHeight => 24 * _pixelsPerHour;

  void _zoomIn() {
    setState(() {
      _pixelsPerHour = math.min(
        _maxPixelsPerHour,
        _pixelsPerHour + _pixelsPerHourStep,
      );
    });
  }

  void _zoomOut() {
    setState(() {
      _pixelsPerHour = math.max(
        _minPixelsPerHour,
        _pixelsPerHour - _pixelsPerHourStep,
      );
    });
  }

  /// 详细时间轴可视高度：按屏幕高度自适应，避免超出可视区被底部导航遮挡。
  double _detailHeight(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final topInset = MediaQuery.paddingOf(context).top;
    // 依次扣除状态栏、AppBar+TabBar、底部导航、页面上下边距与卡片除详情区
    // 外的固定高度（约 158px），并额外保留 40px 余量，保证卡片初始位置就
    // 整体落在可视区内，底部 23:00 之后的内容不被裁切。
    return (size.height - topInset - 400).clamp(260.0, 620.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 将详细时间轴滚动定位到指定分钟（0-1440）。
  void scrollToMinute(BuildContext context, int minute) {
    if (!_controller.hasClients) return;
    final m = minute.clamp(0, 1440);
    final target = m / 1440 * _totalHeight - _detailHeight(context) * 0.3;
    _controller.jumpTo(target.clamp(0.0, _controller.position.maxScrollExtent));
  }

  Future<void> _onBlockTap(
    BuildContext context,
    AppState state,
    TimelineSegment segment,
  ) async {
    final picked = await showTimelineCategoryPicker(context);
    if (picked == null || !mounted) return;
    if (segment.isGap) {
      state.addTimelineRecord(
        widget.date,
        segment.startMin,
        segment.endMin,
        picked,
      );
    } else {
      for (final r in segment.records) {
        state.setRecordTimelineLabel(r, picked);
      }
    }
  }

  void _onBlockLongPress(BuildContext context, TimelineSegment segment) {
    final minute = segment.centerMin;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.chevron_left),
              title: const Text('查看前一天同一时刻'),
              onTap: () {
                Navigator.pop(ctx);
                widget.onJumpDate(
                  widget.date.subtract(const Duration(days: 1)),
                  minute,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.chevron_right),
              title: const Text('查看后一天同一时刻'),
              onTap: () {
                Navigator.pop(ctx);
                widget.onJumpDate(
                  widget.date.add(const Duration(days: 1)),
                  minute,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = context.watch<AppState>();
    final detailHeight = _detailHeight(context);
    final now = DateTime.now();
    final isToday = dateOnly(widget.date) == dateOnly(now);
    final nowMinute = now.hour * 60 + now.minute;
    final segments = buildTimelineSegments(
      state.recordsOnDay(widget.date),
      widget.date,
    );

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '24小时时间轴',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  tooltip: '缩小',
                  visualDensity: VisualDensity.compact,
                  onPressed: _zoomOut,
                  icon: const Icon(Icons.zoom_out, size: 20),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    '${(_pixelsPerHour / _defaultPixelsPerHour).toStringAsFixed(1)}×',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '放大',
                  visualDensity: VisualDensity.compact,
                  onPressed: _zoomIn,
                  icon: const Icon(Icons.zoom_in, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 顶部缩略总览：仅色块，点击定位
            GestureDetector(
              onTapUp: (d) {
                final minute = (d.localPosition.dy / _miniHeight * 1440)
                    .round();
                scrollToMinute(context, minute);
              },
              child: Container(
                height: _miniHeight,
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  border: Border.all(color: scheme.outlineVariant),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  children: [
                    for (final s in segments)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: s.startMin / 1440 * _miniHeight,
                        height: math.max(
                          2.0,
                          s.durationMin / 1440 * _miniHeight,
                        ),
                        child: ColoredBox(color: timelineColor(s.label)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // 下方详细时间轴
            SizedBox(
              height: detailHeight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SingleChildScrollView(
                  controller: _controller,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: SizedBox(
                      height: _totalHeight,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ColoredBox(
                              color: scheme.surfaceContainerHighest.withValues(
                                alpha: 0.35,
                              ),
                            ),
                          ),
                          for (var h = 0; h <= 24; h++) ...[
                            Positioned(
                              top: h * _pixelsPerHour,
                              left: 0,
                              right: 0,
                              child: const Divider(height: 1),
                            ),
                            if (h < 24)
                              Positioned(
                                top: h * _pixelsPerHour + 2,
                                left: 6,
                                child: Text(
                                  two(h),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                          ],
                          for (final s in segments)
                            Positioned(
                              left: 40,
                              right: 10,
                              top: s.startMin / 60 * _pixelsPerHour,
                              height: math.max(
                                4.0,
                                s.durationMin / 60 * _pixelsPerHour,
                              ),
                              child: _TimelineBlock(
                                segment: s,
                                onTap: () => _onBlockTap(context, state, s),
                                onLongPress: () =>
                                    _onBlockLongPress(context, s),
                              ),
                            ),
                          if (isToday)
                            Positioned(
                              left: 40,
                              right: 10,
                              top: nowMinute / 60 * _pixelsPerHour - 1,
                              child: Container(
                                height: 2,
                                color: const Color(0xFFEF4444),
                              ),
                            ),
                          if (isToday)
                            Positioned(
                              left: 4,
                              top: nowMinute / 60 * _pixelsPerHour - 6,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEF4444),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '点击色块修改分类；长按可查看相邻日期同一时刻',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineBlock extends StatelessWidget {
  const _TimelineBlock({
    required this.segment,
    required this.onTap,
    required this.onLongPress,
  });

  final TimelineSegment segment;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final color = timelineColor(segment.label);
    final isGap = segment.isGap;
    final background = isGap
        ? color.withValues(alpha: 0.16)
        : color.withValues(alpha: 0.9);
    final foreground = isGap
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : (segment.label == '娱乐' ? Colors.black87 : Colors.white);
    final startText =
        '${two(segment.startMin ~/ 60)}:${two(segment.startMin % 60)}';
    final endText = '${two(segment.endMin ~/ 60)}:${two(segment.endMin % 60)}';
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Text(
            '${segment.label} $startText-$endText',
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: foreground,
              shadows: isGap
                  ? null
                  : const [
                      Shadow(
                        color: Colors.black26,
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
            ),
          ),
        ),
      ),
    );
  }
}
