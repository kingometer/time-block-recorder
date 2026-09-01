class EventItem {
  EventItem({
    required this.id,
    required this.name,
    required this.categoryCode,
    this.note = '',
    this.favorite = false,
    required this.createdAt,
  });

  final String id;
  String name;
  String categoryCode;

  /// 事件备注：可在开始计时前、计时中或计时结束后编辑。
  String note;

  /// 收藏：收藏事件在选择列表中置顶展示。
  bool favorite;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': categoryCode,
    'note': note,
    'favorite': favorite,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory EventItem.fromJson(Map<String, dynamic> json) => EventItem(
    id: (json['id'] ?? '').toString(),
    name: (json['name'] ?? '').toString(),
    categoryCode: (json['category'] ?? 'freeRecovery').toString(),
    note: (json['note'] ?? '').toString(),
    favorite: (json['favorite'] ?? false) == true,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      (json['createdAt'] as num?)?.toInt() ?? 0,
    ),
  );
}
