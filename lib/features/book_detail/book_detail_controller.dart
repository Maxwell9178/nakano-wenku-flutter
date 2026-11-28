import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../../core/models/book.dart';
import '../../core/services/tag_repository.dart';
import '../../core/models/chapter.dart';
import '../../core/services/book_repository.dart';
import '../../core/services/chapter_repository.dart';

/// 书籍详情页的业务层：元数据编辑、封面替换、章节目录管理、阅读位置。
///
/// 所有写操作都会立即落盘（本地优先，不依赖任何网络），
/// 页面只需要调用方法并把返回值里的错误文案展示出来。
class BookDetailController extends ChangeNotifier {
  BookDetailController({
    required BookRepository books,
    required ChapterRepository chapters,
    required Book book,
  })  : _books = books,
        _chapterRepository = chapters,
        _book = book;

  final BookRepository _books;
  final ChapterRepository _chapterRepository;

  Book _book;
  List<Chapter> _chapters = const <Chapter>[];
  bool _loading = false;

  Book get book => _book;
  List<Chapter> get chapters => _chapters;
  bool get loading => _loading;
  bool get hasChapters => _chapters.isNotEmpty;
  int get chapterCount =>
      _chapters.isNotEmpty ? _chapters.length : _book.chapterCount;

  /// 目录里的真实字数优先；章节文件缺失时回落到书籍元数据。
  int get totalWords {
    if (_chapters.isEmpty) {
      return _book.wordCount;
    }
    return _chapters.fold<int>(
      0,
      (int sum, Chapter chapter) => sum + chapter.wordCount,
    );
  }

  String get totalWordsLabel {
    if (totalWords <= 0) {
      return '字数待解析';
    }
    if (totalWords >= 10000) {
      final double wan = totalWords / 10000;
      return '${wan.toStringAsFixed(wan >= 100 ? 0 : 1)} 万字';
    }
    return '$totalWords 字';
  }

  /// 上次阅读章节在目录里的下标；找不到时回落到第一章。
  int get lastChapterIndex {
    final String? title = _book.lastChapterTitle;
    if (title == null || title.isEmpty || _chapters.isEmpty) {
      return 0;
    }
    final int index =
        _chapters.indexWhere((Chapter chapter) => chapter.title == title);
    return index < 0 ? 0 : index;
  }

  String get lastChapterLabel {
    if (_chapters.isEmpty) {
      return '还没有开始阅读';
    }
    final String? title = _book.lastChapterTitle;
    if (title == null || title.isEmpty) {
      return '还没有开始阅读';
    }
    return '第 ${lastChapterIndex + 1} 章 · $title';
  }

  Future<void> load() async {
    _loading = true;
    notifyListeners();

    final List<Chapter> loaded = await _chapterRepository.load(_book.number);
    _chapters = loaded;

    // 章节数与字数以磁盘上的目录为准，顺手修正历史数据。
    if (loaded.isNotEmpty) {
      final int words = loaded.fold<int>(
        0,
        (int sum, Chapter chapter) => sum + chapter.wordCount,
      );
      if (_book.chapterCount != loaded.length ||
          (_book.wordCount != words && words > 0)) {
        _book = _book.copyWith(chapterCount: loaded.length, wordCount: words);
        await _persist();
      }
    }

    _loading = false;
    notifyListeners();
  }

  /// 编号是否已被别的书占用（自动校验，禁止重复）。
  bool isNumberTaken(int number) => _books.loadAll().any(
        (Book other) => other.number == number && other.number != _book.number,
      );

  // ---------------- 元数据编辑 ----------------

  Future<String?> rename(String rawTitle) async {
    final String title = rawTitle.trim();
    if (title.isEmpty) {
      return '书名不能为空';
    }
    if (title == _book.title) {
      return null;
    }
    _book = _book.copyWith(title: title);
    await _persist();
    notifyListeners();
    return null;
  }

  Future<String?> changeAuthor(String rawAuthor) async {
    final String author = rawAuthor.trim();
    if (author.isEmpty) {
      return '作者不能为空';
    }
    if (author == _book.author) {
      return null;
    }
    _book = _book.copyWith(author: author);
    await _persist();
    notifyListeners();
    return null;
  }

  /// 修改编号；返回 null 表示成功，否则是给用户看的错误文案。
  Future<String?> changeNumber(int rawNumber) async {
    final int number =
        rawNumber.clamp(AppConstants.bookIdMin, AppConstants.bookIdMax).toInt();
    if (number == _book.number) {
      return null;
    }
    if (isNumberTaken(number)) {
      return '编号 ${AppConstants.formatBookId(number)} 已被其他书籍使用';
    }

    final int previousNumber = _book.number;
    final String? previousCover = _book.coverPath;

    // 章节与封面文件都以书号命名，改号必须一起迁移，否则会丢内容。
    await _chapterRepository.move(previousNumber, number);
    final String? movedCover =
        await _chapterRepository.moveCover(previousCover, number);

    _book = _book.copyWith(
      number: number,
      coverPath: movedCover ?? previousCover,
    );
    await _persist(previousNumber: previousNumber);
    notifyListeners();
    return null;
  }

  /// 替换封面；返回 false 表示图片读取失败。
  Future<bool> changeCover(String sourcePath) async {
    final String? saved =
        await _chapterRepository.saveCoverFile(_book.number, sourcePath);
    if (saved == null) {
      return false;
    }
    _book = _book.copyWith(coverPath: saved);
    await _persist();
    notifyListeners();
    return true;
  }

  // ---------------- 标签 ----------------

  Future<String?> addTag(String rawTag) async {
    final String tag = rawTag.trim();
    if (tag.isEmpty) {
      return '标签不能为空';
    }
    if (_book.tags.contains(tag)) {
      return '这本书已经有「$tag」标签了';
    }
    if (_book.tags.length >= TagRepository.maxTagsPerBook) {
      return '每本书最多 ${TagRepository.maxTagsPerBook} 个标签，先去掉一个吧';
    }
    _book = _book.copyWith(tags: <String>[..._book.tags, tag]);
    await _persist();
    notifyListeners();
    return null;
  }

  Future<void> removeTag(String tag) async {
    if (!_book.tags.contains(tag)) {
      return;
    }
    _book = _book.copyWith(
      tags: _book.tags.where((String item) => item != tag).toList(),
    );
    await _persist();
    notifyListeners();
  }

  // ---------------- 目录与整本删除 ----------------

  /// 删除若干章节（多选删除），自动重算字数与阅读进度。
  Future<void> deleteChapters(Set<int> indexes) async {
    if (indexes.isEmpty || _chapters.isEmpty) {
      return;
    }

    final List<Chapter> kept = <Chapter>[];
    for (int i = 0; i < _chapters.length; i++) {
      if (!indexes.contains(i)) {
        kept.add(_chapters[i]);
      }
    }
    if (kept.length == _chapters.length) {
      return;
    }

    _chapters = kept;
    await _chapterRepository.save(_book.number, kept);

    final int words = kept.fold<int>(
      0,
      (int sum, Chapter chapter) => sum + chapter.wordCount,
    );

    String? lastTitle = _book.lastChapterTitle;
    if (lastTitle != null &&
        !kept.any((Chapter chapter) => chapter.title == lastTitle)) {
      lastTitle = kept.isEmpty ? null : kept.first.title;
    }

    _book = _book.copyWith(
      chapterCount: kept.length,
      wordCount: words,
      progress: kept.isEmpty ? 0 : _book.progress,
      lastChapterTitle: lastTitle,
      clearLastChapterTitle: lastTitle == null,
    );
    await _persist();
    notifyListeners();
  }

  /// 移除整本书：章节文件、封面文件与书架记录一起清理。
  Future<void> deleteBook() async {
    await _chapterRepository.delete(_book.number);
    await _chapterRepository.deleteCover(_book.coverPath);
    final List<Book> rest = _books
        .loadAll()
        .where((Book other) => other.number != _book.number)
        .toList();
    await _books.saveAll(rest);
    notifyListeners();
  }

  // ---------------- 阅读位置 ----------------

  /// 打开阅读页前记录「读到第几章」，进度按章节粒度持久化。
  Future<Book> markReadingPosition(int chapterIndex) async {
    if (_chapters.isEmpty) {
      return _book;
    }
    final int safeIndex = chapterIndex.clamp(0, _chapters.length - 1).toInt();
    final Chapter chapter = _chapters[safeIndex];
    _book = _book.copyWith(
      lastChapterTitle: chapter.title,
      progress: (safeIndex + 1) / _chapters.length,
      lastReadAt: DateTime.now(),
    );
    await _persist();
    notifyListeners();
    return _book;
  }

  Future<void> _persist({int? previousNumber}) async {
    final List<Book> all = _books.loadAll();
    final int key = previousNumber ?? _book.number;
    final int index = all.indexWhere((Book item) => item.number == key);
    if (index >= 0) {
      all[index] = _book;
    } else {
      all.add(_book);
    }
    all.sort((Book a, Book b) => a.number.compareTo(b.number));
    await _books.saveAll(all);
  }
}
