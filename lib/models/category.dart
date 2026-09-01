import 'package:flutter/material.dart';

/// 五个固定顶层分类：不可新增、不可删除、不可修改。
enum AppCategory {
  workStudy('workStudy', '工作学习', Icons.school_outlined, Color(0xFF3D7BFD)),
  freeRecovery(
    'freeRecovery',
    '自由恢复',
    Icons.self_improvement_outlined,
    Color(0xFF10B981),
  ),
  entertainment(
    'entertainment',
    '娱乐',
    Icons.sports_esports_outlined,
    Color(0xFFF5A524),
  ),
  sleep('sleep', '睡觉', Icons.bedtime_outlined, Color(0xFF8B5CF6)),
  other('other', '其他事件', Icons.category_outlined, Color(0xFF64748B));

  const AppCategory(this.code, this.label, this.icon, this.color);

  final String code;
  final String label;
  final IconData icon;
  final Color color;

  static AppCategory fromCode(String? code) {
    for (final c in AppCategory.values) {
      if (c.code == code) return c;
    }
    return AppCategory.freeRecovery;
  }
}
