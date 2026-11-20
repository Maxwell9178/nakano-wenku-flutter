/// 一条摘抄记录。
///
/// 需求约定：摘抄需要同步保存「书名」与「所属章节」，
/// 因此这里不只存正文，还存书籍编号与章节序号，方便后续
/// 「我的 - 摘抄库」按书 / 按章分组展示。
class Excerpt {
  const Excerpt({
    required this.id,
    required this.bookNumber,
    required this.bookTitle,
    required this.chapterIndex,
    required this.chapterTitle,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final int bookNumber;
  final String bookTitle;
  final int chapterIndex;
  final String chapterTitle;
  final String text;
  final DateTime createdAt;

  /// 列表副标题，例如「第三章 · 2026.11.19」。
  String get sourceLabel {
    final String date =
        '${createdAt.year}.${_two(createdAt.month)}.${_two(createdAt.day)}';
    return '$chapterTitle · $date';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'bookNumber': bookNumber,
        'bookTitle': bookTitle,
        'chapterIndex': chapterIndex,
        'chapterTitle': chapterTitle,
        'text': text,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory Excerpt.fromJson(Map<String, dynamic> json) {
    return Excerpt(
      id: (json['id'] as String?)?.trim().isNotEmpty == true
          ? json['id'] as String
          : 'excerpt-${DateTime.now().microsecondsSinceEpoch}',
      bookNumber: _asInt(json['bookNumber']),
      bookTitle: (json['bookTitle'] as String?)?.trim() ?? '未知书籍',
      chapterIndex: _asInt(json['chapterIndex']),
      chapterTitle: (json['chapterTitle'] as String?)?.trim() ?? '未知章节',
      text: (json['text'] as String?) ?? '',
      createdAt: _asDate(json['createdAt']),
    );
  }
}

String _two(int value) => value.toString().padLeft(2, '0');

int _asInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}

DateTime _asDate(dynamic value) {
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
  if (value is String) {
    final int? millis = int.tryParse(value);
    if (millis != null) {
      return DateTime.fromMillisecondsSinceEpoch(millis);
    }
  }
  return DateTime.now();
}
