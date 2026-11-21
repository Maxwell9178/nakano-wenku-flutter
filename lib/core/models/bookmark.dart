/// 书签数据模型（第 2 轮新增）。
///
/// 书签与阅读进度分开存储：进度只保留「上次读到哪」，书签是用户主动标记的
/// 位置集合，可以有多条、可带备注、可删除。
class Bookmark {
  const Bookmark({
    required this.id,
    required this.bookNumber,
    required this.chapterIndex,
    required this.chapterTitle,
    this.ratio = 0,
    this.note = '',
    this.createdAt,
  });

  final String id;

  /// 书籍编号数字部分（NW-XXXX 的 XXXX）。
  final int bookNumber;

  /// 所在章节下标。
  final int chapterIndex;

  final String chapterTitle;

  /// 章节内相对位置 0~1，用于跳转到书签时还原大致段落。
  final double ratio;

  /// 简短备注。
  final String note;

  final DateTime? createdAt;

  String get timeLabel {
    final DateTime time = createdAt ?? DateTime.now();
    final String month = time.month.toString().padLeft(2, '0');
    final String day = time.day.toString().padLeft(2, '0');
    final String hour = time.hour.toString().padLeft(2, '0');
    final String minute = time.minute.toString().padLeft(2, '0');
    return '${time.year}.$month.$day $hour:$minute';
  }

  Bookmark copyWith({
    String? id,
    int? bookNumber,
    int? chapterIndex,
    String? chapterTitle,
    double? ratio,
    String? note,
    DateTime? createdAt,
  }) {
    return Bookmark(
      id: id ?? this.id,
      bookNumber: bookNumber ?? this.bookNumber,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      ratio: ratio ?? this.ratio,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'bookNumber': bookNumber,
      'chapterIndex': chapterIndex,
      'chapterTitle': chapterTitle,
      'ratio': ratio,
      'note': note,
      'createdAt': createdAt?.millisecondsSinceEpoch,
    };
  }

  factory Bookmark.fromJson(Map<String, dynamic> json) {
    final dynamic rawRatio = json['ratio'];
    return Bookmark(
      id: (json['id'] as String?) ?? 'bookmark-unknown',
      bookNumber: _asInt(json['bookNumber'], 1),
      chapterIndex: _asInt(json['chapterIndex'], 0),
      chapterTitle: (json['chapterTitle'] as String?) ?? '',
      ratio: rawRatio is num ? rawRatio.toDouble().clamp(0.0, 1.0) : 0,
      note: (json['note'] as String?) ?? '',
      createdAt: _asDateTime(json['createdAt']),
    );
  }

  static int _asInt(dynamic value, int fallback) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
