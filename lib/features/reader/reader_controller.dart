import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/models/book.dart';
import '../../core/models/chapter.dart';
import '../../core/models/excerpt.dart';
import '../../core/models/reading_preferences.dart';
import '../../core/services/book_repository.dart';
import '../../core/services/chapter_repository.dart';
import '../../core/services/excerpt_repository.dart';
import '../../core/services/quote_repository.dart';
import '../../core/services/reading_preferences_repository.dart';

/// 阅读页的数据与状态中枢。
///
/// 只负责「数据 + 偏好 + 进度落盘」，不碰任何布局：
/// * 章节正文与阅读偏好来自本地仓库；
/// * 阅读进度按章节粒度回写到书籍记录（书架、详情页共用）；
/// * 摘抄写入摘抄库时自动带上书名与章节信息。
class ReaderController extends ChangeNotifier {
  ReaderController({
    required BookRepository books,
    required ChapterRepository chapterRepository,
    required ReadingPreferencesRepository preferencesRepository,
    required ExcerptRepository excerptRepository,
    required QuoteRepository quoteRepository,
    required Book book,
    required int initialChapterIndex,
  })  : _books = books,
        _chapterRepository = chapterRepository,
        _preferencesRepository = preferencesRepository,
        _excerptRepository = excerptRepository,
        _quoteRepository = quoteRepository,
        _book = book,
        _initialChapterIndex = initialChapterIndex;

  final BookRepository _books;
  final ChapterRepository _chapterRepository;
  final ReadingPreferencesRepository _preferencesRepository;
  final ExcerptRepository _excerptRepository;
  final QuoteRepository _quoteRepository;

  Book _book;
  final int _initialChapterIndex;

  List<Chapter> _chapters = <Chapter>[];
  ReadingPreferences _preferences = const ReadingPreferences();
  String _backgroundId = ReadingBackground.lightId;
  List<ReadingBackground> _customBackgrounds = <ReadingBackground>[];
  List<String> _quotes = <String>[];
  String _quote = '';

  int _currentChapter = 0;
  double _progress = 0;
  bool _loading = true;

  Timer? _persistTimer;

  // ---------------- Getter ----------------

  Book get book => _book;
  List<Chapter> get chapters => List<Chapter>.unmodifiable(_chapters);
  ReadingPreferences get preferences => _preferences;
  String get backgroundId => _backgroundId;
  List<ReadingBackground> get customBackgrounds =>
      List<ReadingBackground>.unmodifiable(_customBackgrounds);
  String get quote => _quote;
  bool get loading => _loading;
  bool get hasChapters => _chapters.isNotEmpty;
  int get chapterCount => _chapters.length;
  int get currentChapter => _currentChapter;
  bool get isLastChapter =>
      _chapters.isNotEmpty && _currentChapter >= _chapters.length - 1;
  bool get isFinished => _book.isFinished;

  /// 当前章节标题（越界时给出兜底文案）。
  String get chapterTitle {
    if (_chapters.isEmpty) {
      return '正文';
    }
    final int index = _currentChapter.clamp(0, _chapters.length - 1);
    return _chapters[index].title;
  }

  /// 档位化进度：只出现 0% / 5% / 10% …… 100%。
  int get progressPercent {
    final int step = (_progress.clamp(0.0, 1.0) * 20).round();
    return (step * 5).clamp(0, 100);
  }

  /// 供渲染用的完整背景列表（内置 + 用户上传）。
  List<ReadingBackground> get allBackgrounds => <ReadingBackground>[
        ...ReadingBackground.builtIns,
        ..._customBackgrounds,
      ];

  // ---------------- 初始化 ----------------

  Future<void> load({bool darkTheme = false}) async {
    _loading = true;
    notifyListeners();

    _preferences = _preferencesRepository.load();
    _customBackgrounds = _preferencesRepository.loadBackgrounds();
    _backgroundId = _preferencesRepository.backgroundIdFor(
      _book.number,
      darkTheme: darkTheme,
    );

    try {
      _chapters = await _chapterRepository.load(_book.number);
    } catch (_) {
      _chapters = <Chapter>[];
    }

    _currentChapter = _resolveInitialChapter();
    _progress = _book.progress.clamp(0.0, 1.0).toDouble();

    try {
      _quotes = await _quoteRepository.load();
      _quote = _quoteRepository.pickRandom(_quotes);
    } catch (_) {
      _quotes = <String>[];
      _quote = '';
    }

    _loading = false;
    notifyListeners();
  }

  /// 优先使用传入的章节；传入 0 且有阅读记录时，续读上次读到的章节。
  int _resolveInitialChapter() {
    if (_chapters.isEmpty) {
      return 0;
    }
    if (_initialChapterIndex > 0) {
      return _initialChapterIndex.clamp(0, _chapters.length - 1);
    }
    final String? lastTitle = _book.lastChapterTitle;
    if (_book.progress > 0 && lastTitle != null && lastTitle.isNotEmpty) {
      for (int i = 0; i < _chapters.length; i++) {
        if (_chapters[i].title == lastTitle) {
          return i;
        }
      }
    }
    return 0;
  }

  // ---------------- 进度 ----------------

  /// 滚动 / 翻页时更新进度（0~1 的连续值，展示时再落档位）。
  ///
  /// 阅读页每一帧都在滚动，这里刻意不 notifyListeners：
  /// 百分比由页面里的 ValueNotifier 单独驱动，避免整页重建。
  void updateProgress(double ratio) {
    final double next = ratio.clamp(0.0, 1.0).toDouble();
    if ((next - _progress).abs() < 0.0005) {
      return;
    }
    _progress = next;
    _schedulePersist();
  }

  /// 章节切换时同步「上次读到」信息。
  void setCurrentChapter(int index) {
    if (_chapters.isEmpty) {
      return;
    }
    final int next = index.clamp(0, _chapters.length - 1);
    if (next == _currentChapter) {
      return;
    }
    _currentChapter = next;
    // 换章时顺带换一条名言（只读取本地名言名句.txt，不提供手动切换入口）。
    rotateQuote();
    notifyListeners();
    _schedulePersist();
  }

  void nextChapter() => setCurrentChapter(_currentChapter + 1);

  void previousChapter() => setCurrentChapter(_currentChapter - 1);

  // ---------------- 偏好 ----------------

  Future<void> applyPreferences(ReadingPreferences preferences) async {
    _preferences = preferences;
    notifyListeners();
    await _preferencesRepository.save(preferences);
  }

  Future<void> selectBackground(String id) async {
    if (id == _backgroundId) {
      return;
    }
    _backgroundId = id;
    notifyListeners();
    await _preferencesRepository.setBackgroundFor(_book.number, id);
  }

  /// 上传新背景：写入全局背景库，并立即应用到当前书。
  Future<ReadingBackground?> importBackground(String sourcePath) async {
    final ReadingBackground? background =
        await _preferencesRepository.importBackground(sourcePath);
    if (background == null) {
      return null;
    }
    _customBackgrounds = _preferencesRepository.loadBackgrounds();
    await selectBackground(background.id);
    notifyListeners();
    return background;
  }

  Future<void> removeBackground(String id) async {
    await _preferencesRepository.removeBackground(id);
    _customBackgrounds = _preferencesRepository.loadBackgrounds();
    if (_backgroundId == id) {
      await selectBackground(ReadingBackground.lightId);
    }
    notifyListeners();
  }

  // ---------------- 摘抄 ----------------

  /// 保存一段摘抄；[chapterIndex] 缺省时取当前章节。
  Future<Excerpt?> saveExcerpt(String text, {int? chapterIndex}) async {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final int index = (chapterIndex ?? _currentChapter)
        .clamp(0, _chapters.isEmpty ? 0 : _chapters.length - 1);
    final String title = _chapters.isEmpty ? '正文' : _chapters[index].title;
    return _excerptRepository.add(
      bookNumber: _book.number,
      bookTitle: _book.title,
      chapterIndex: index,
      chapterTitle: title,
      text: trimmed,
    );
  }

  // ---------------- 名言 ----------------

  /// 沉浸模式底部长条换一条名言。
  void rotateQuote() {
    if (_quotes.isEmpty) {
      return;
    }
    _quote = _quoteRepository.pickRandom(_quotes, previous: _quote);
    notifyListeners();
  }

  // ---------------- 读完 ----------------

  /// 标记本书为已读完；进度拉到 100%，并立即落盘。
  Future<void> markFinished() async {
    if (_chapters.isEmpty) {
      return;
    }
    _progress = 1;
    _currentChapter = _chapters.length - 1;
    _book = _book.copyWith(
      isFinished: true,
      progress: 1,
      lastChapterTitle: _chapters.last.title,
      lastReadAt: DateTime.now(),
    );
    notifyListeners();
    await _persist();
  }

  // ---------------- 落盘 ----------------

  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 900), () {
      _persist();
    });
  }

  Future<void> _persist() async {
    final String title = _chapters.isEmpty
        ? (_book.lastChapterTitle ?? '')
        : _chapters[_currentChapter.clamp(0, _chapters.length - 1)].title;

    _book = _book.copyWith(
      progress: _progress,
      lastChapterTitle: title,
      lastReadAt: DateTime.now(),
    );

    try {
      final List<Book> all = _books.loadAll();
      final List<Book> next = <Book>[];
      bool replaced = false;
      for (final Book item in all) {
        if (item.number == _book.number) {
          next.add(_book);
          replaced = true;
        } else {
          next.add(item);
        }
      }
      if (!replaced) {
        next.add(_book);
      }
      next.sort((Book a, Book b) => a.number.compareTo(b.number));
      await _books.saveAll(next);
    } catch (_) {
      // 写盘失败不打断阅读，下次滚动会再试一次。
    }
  }

  /// 离开阅读页前调用，确保最后一次进度不丢。
  Future<void> flushProgress() async {
    _persistTimer?.cancel();
    await _persist();
  }

  @override
  void dispose() {
    _persistTimer?.cancel();
    super.dispose();
  }
}
