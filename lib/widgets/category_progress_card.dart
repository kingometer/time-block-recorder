import 'package:flutter/material.dart';

import '../models/category.dart';
import '../utils/format.dart';

class CategoryProgressCard extends StatelessWidget {
  const CategoryProgressCard({
    super.key,
    required this.category,
    required this.totalSec,
    required this.targetSec,
  });

  final AppCategory category;
  final int totalSec;

  /// null 表示该模式不设目标（突发情况）。
  final int? targetSec;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = category.color;
    final target = targetSec ?? 0;
    final progress = target > 0 ? (totalSec / target).clamp(0.0, 1.0) : 0.0;
    final over = target > 0 && totalSec > target;
    final targetText = targetSec == null
        ? '其他模式'
        : (target > 0 ? formatTargetMinutes(target ~/ 60) : '未设置目标');

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.14),
              child: Icon(category.icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        category.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${formatDuration(totalSec)} / $targetText',
                        style: TextStyle(
                          fontSize: 12,
                          color: targetSec == null
                              ? scheme.onSurfaceVariant
                              : (over ? scheme.error : scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: color.withValues(alpha: 0.12),
                      color: over ? scheme.error : color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
