import '../constants/app_constants.dart';

/// 书籍连载状态。
enum BookSeriesStatus { ongoing, completed }

extension BookSeriesStatusX on BookSeriesStatus {
  /// 界面展示文案。需求要求信息区直接显示「已完结 / 连载中」。
  String get label => this == BookSeriesStatus.completed ? '已完结' : '连载中';
}

/// 从本地存储的字符串还原连载状态，异常值一律回落到「连载中」。
BookSeriesStatus bookSeriesStatusFromValue(String? value) {
  return value == BookSeriesStatus.completed.name
      ? BookSeriesStatus.completed
      : BookSeriesStatus.ongoing;
}

/// 书籍数据模型。
///
/// 第 2 轮只承载书架需要展示的字段（书名、作者、封面、标签、连载状态、
/// 已读状态、阅读进度、上次阅读章节）。导入轮次会填充章节正文、真实
/// 封面与字数；阅读轮次只更新 [progress] / [lastReadAt] 等字段，
/// 因此这里一次性把字段预留完整，避免后续反复改模型。
class Book {
  const Book({
    required this.number,
    required this.title,
    required this.author,
    this.coverPath,
    this.wordCount = 0,
    this.chapterCount = 0,
    this.tags = const <String>[],
    this.seriesStatus = BookSeriesStatus.ongoing,
    this.isFinished = false,
    this.progress = 0,
    this.lastChapterTitle,
    this.lastReadAt,
    this.addedAt,
    this.totalReadMs = 0,
    this.group,
    this.isComic = false,
  });

  /// 书籍编号数字部分，界面统一展示为 NW-XXXX。
  final int number;

  final String title;
  final String author;

  /// 书籍封面在应用私有目录中的绝对路径；为空时书架绘制占位封面。
  final String? coverPath;

  /// 全书总字数，导入阶段解析后写入。
  final int wordCount;

  /// 章节数量。
  final int chapterCount;

  /// 标签（内置 6 类 + 用户自定义）。
  final List<String> tags;

  final BookSeriesStatus seriesStatus;

  /// 是否已读完（最后一章手动标记）。
  final bool isFinished;

  /// 阅读进度 0~1。
  final double progress;

  /// 上次阅读停留的章节名，详情页用于标注「上次读到的卷 / 章节」。
  final String? lastChapterTitle;

  /// 上次阅读时间，书架初始定位到最近阅读的书籍。
  final DateTime? lastReadAt;

  /// 入库时间。
  final DateTime? addedAt;

  /// 本书累计阅读时长（毫秒）。第 2 轮新增，参与阅读榜单排序与备份。
  final int totalReadMs;

  /// 导入分组标签（用户自定义，可为空）。
  final String? group;

  /// 是否为漫画（CBX / CBZ 图片压缩包）。
  final bool isComic;

  /// 累计阅读时长文案：不足 1 分钟按 1 分钟计，超过 1 小时显示小时。
  String get totalReadLabel {
    if (totalReadMs <= 0) {
      return '未开始阅读';
    }
    final int totalMinutes = totalReadMs < 60000 ? 1 : totalReadMs ~/ 60000;
    if (totalMinutes < 60) {
      return '$totalMinutes 分钟';
    }
    final int hours = totalMinutes ~/ 60;
    final int minutes = totalMinutes % 60;
    return minutes == 0 ? '$hours 小时' : '$hours 小时 $minutes 分钟';
  }

  /// 完整编号，例如 NW-0007。
  String get id => AppConstants.formatBookId(number);

  /// 总字数的展示文案。
  String get wordCountLabel {
    if (isComic) {
      return chapterCount > 0 ? '$chapterCount 页' : '页数待解析';
    }
    if (wordCount <= 0) {
      return '字数待解析';
    }
    if (wordCount >= 10000) {
      final double wan = wordCount / 10000;
      return '${wan.toStringAsFixed(wan >= 100 ? 0 : 1)} 万字';
    }
    return '$wordCount 字';
  }

  Book copyWith({
    int? number,
    String? title,
    String? author,
    String? coverPath,
    int? wordCount,
    int? chapterCount,
    List<String>? tags,
    BookSeriesStatus? seriesStatus,
    bool? isFinished,
    double? progress,
    String? lastChapterTitle,
    DateTime? lastReadAt,
    DateTime? addedAt,
    int? totalReadMs,
    String? group,
    bool? isComic,
    bool clearCoverPath = false,
    bool clearLastChapterTitle = false,
    bool clearGroup = false,
  }) {
    return Book(
      number: number ?? this.number,
      title: title ?? this.title,
      author: author ?? this.author,
      coverPath: clearCoverPath ? null : (coverPath ?? this.coverPath),
      wordCount: wordCount ?? this.wordCount,
      chapterCount: chapterCount ?? this.chapterCount,
      tags: tags ?? this.tags,
      seriesStatus: seriesStatus ?? this.seriesStatus,
      isFinished: isFinished ?? this.isFinished,
      progress: progress ?? this.progress,
      lastChapterTitle: clearLastChapterTitle
          ? null
          : (lastChapterTitle ?? this.lastChapterTitle),
      lastReadAt: lastReadAt ?? this.lastReadAt,
      addedAt: addedAt ?? this.addedAt,
      totalReadMs: totalReadMs ?? this.totalReadMs,
      group: clearGroup ? null : (group ?? this.group),
      isComic: isComic ?? this.isComic,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'number': number,
      'title': title,
      'author': author,
      'coverPath': coverPath,
      'wordCount': wordCount,
      'chapterCount': chapterCount,
      'tags': tags,
      'seriesStatus': seriesStatus.name,
      'isFinished': isFinished,
      'progress': progress,
      'lastChapterTitle': lastChapterTitle,
      'lastReadAt': lastReadAt?.millisecondsSinceEpoch,
      'addedAt': addedAt?.millisecondsSinceEpoch,
      'totalReadMs': totalReadMs,
      'group': group,
      'isComic': isComic,
    };
  }

  /// 反序列化：对字段缺失、类型异常都做兜底，坏数据不能拖垮书架。
  factory Book.fromJson(Map<String, dynamic> json) {
    final List<String> parsedTags = <String>[];
    final dynamic rawTags = json['tags'];
    if (rawTags is List) {
      for (final dynamic tag in rawTags) {
        if (tag is String && tag.trim().isNotEmpty) {
          parsedTags.add(tag.trim());
        }
      }
    }

    return Book(
      number: _asInt(json['number'], AppConstants.bookIdMin),
      title: _asString(json['title'], '未命名书籍'),
      author: _asString(json['author'], '佚名'),
      coverPath: _asNullableString(json['coverPath']),
      wordCount: _asInt(json['wordCount'], 0),
      chapterCount: _asInt(json['chapterCount'], 0),
      tags: parsedTags,
      seriesStatus: bookSeriesStatusFromValue(_asNullableString(
        json['seriesStatus'],
      )),
      isFinished: json['isFinished'] == true,
      progress: _asDouble(json['progress']),
      lastChapterTitle: _asNullableString(json['lastChapterTitle']),
      lastReadAt: _asDateTime(json['lastReadAt']),
      addedAt: _asDateTime(json['addedAt']),
      totalReadMs: _asInt(json['totalReadMs'], 0),
      group: _asNullableString(json['group']),
      isComic: json['isComic'] == true,
    );
  }

  // ---------------- 反序列化辅助 ----------------

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

  static double _asDouble(dynamic value) {
    if (value is double) {
      return value.clamp(0.0, 1.0).toDouble();
    }
    if (value is num) {
      return value.toDouble().clamp(0.0, 1.0).toDouble();
    }
    return 0;
  }

  static String _asString(dynamic value, String fallback) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return fallback;
  }

  static String? _asNullableString(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
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
