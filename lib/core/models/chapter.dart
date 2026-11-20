/// 章节数据模型。
///
/// 导入阶段解析出的正文按章节切分后落盘，阅读页只按索引取用；
/// 字数在导入时一次算好，避免阅读时反复统计长文本。
class Chapter {
  const Chapter({
    required this.title,
    required this.content,
    this.wordCount = 0,
  });

  final String title;
  final String content;

  /// 章节字数（非空白字符数），用于全书字数与阅读进度换算。
  final int wordCount;

  factory Chapter.fromText(String title, String content) {
    final String safeTitle = title.trim();
    return Chapter(
      title: safeTitle.isEmpty ? '未命名章节' : safeTitle,
      content: content,
      wordCount: countWords(content),
    );
  }

  Chapter copyWith({String? title, String? content}) {
    final String nextContent = content ?? this.content;
    return Chapter(
      title: title ?? this.title,
      content: nextContent,
      wordCount: content == null ? wordCount : countWords(nextContent),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': title,
      'content': content,
      'wordCount': wordCount,
    };
  }

  factory Chapter.fromJson(Map<String, dynamic> json) {
    final dynamic rawContent = json['content'];
    final String content = rawContent is String ? rawContent : '';
    final dynamic rawTitle = json['title'];
    final String title =
        rawTitle is String && rawTitle.trim().isNotEmpty ? rawTitle.trim() : '未命名章节';
    final dynamic rawCount = json['wordCount'];

    return Chapter(
      title: title,
      content: content,
      wordCount: rawCount is num ? rawCount.toInt() : countWords(content),
    );
  }

  /// 统计可读字数：忽略空白与零宽字符，与中文阅读器的习惯一致。
  static int countWords(String text) {
    if (text.isEmpty) {
      return 0;
    }

    int count = 0;
    for (final int rune in text.runes) {
      if (rune == 0x20 ||
          rune == 0x09 ||
          rune == 0x0A ||
          rune == 0x0D ||
          rune == 0x3000 ||
          rune == 0xFEFF) {
        continue;
      }
      count++;
    }
    return count;
  }
}
