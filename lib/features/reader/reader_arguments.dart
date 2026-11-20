import '../../core/models/book.dart';

/// 跳转阅读页时携带的参数。
///
/// [chapterIndex] 为章节下标，[chapterTitle] 用于按标题精准定位
/// （分卷合并后的目录可能重新编号，标题比下标更稳）。
class ReaderArguments {
  const ReaderArguments({
    required this.book,
    this.chapterIndex = 0,
    this.chapterTitle,
  });

  final Book book;
  final int chapterIndex;
  final String? chapterTitle;
}
