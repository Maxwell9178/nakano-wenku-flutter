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
import '../../core/services/reading_position_repository.dart';
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
    required ReadingPositionRepository positions,
    required Book book,
    required int initialChapterIndex,
  })  : _books = books,
        _chapterRepository = chapterRepository,
        _preferencesRepository = preferencesRepository,
        _excerptRepository = excerptRepository,
        _quoteRepository = quoteRepository,
        _positions = positions,
        _book = book,
        _initialChapterIndex = initialChapterIndex;

  final BookRepository _books;
  final ChapterRepository _chapterRepository;
  final ReadingPreferencesRepository _preferencesRepository;
  final ExcerptRepository _excerptRepository;
  final QuoteRepository _quoteRepository;
  final ReadingPositionRepository _positions;

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

  /// 每一章读到的位置（章内比例 0~1），用于「从目录进入也回到原处」。
  Map<int, double> _chapterPositions = <int, double>{};

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

  /// 精确进度：0% / 1% / … / 100%。
  ///
  /// 早期版本进位到 5% 档位，一本长书读了大半屏百分比都还停在原处，
  /// 看起来像「进度不动」；这里改成逐 1% 显示，读数与滚动位置一一对应。
  int get progressPercent {
    return (_progress.clamp(0.0, 1.0) * 100).round().clamp(0, 100);
  }

  /// 某一章上次读到的章内比例；没有记录返回 null。
  double? chapterPosition(int chapter) => _chapterPositions[chapter];

  /// 记录某一章读到的位置（异步落盘，不触发重建）。
  void recordChapterPosition(int chapter, double ratio) {
    if (chapter < 0) {
      return;
    }
    final double safe = ratio.clamp(0.0, 1.0).toDouble();
    final double? previous = _chapterPositions[chapter];
    if (previous != null && (previous - safe).abs() < 0.01) {
      return;
    }
    _chapterPositions[chapter] = safe;
    unawaited(_positions.save(_book.number, chapter, safe));
  }

  /// 精确进度（0~1），续读定位与进度条共用。
  double get progress => _progress.clamp(0.0, 1.0).toDouble();

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

    try {
      _chapterPositions = await _positions.loadForBook(_book.number);
    } catch (_) {
      _chapterPositions = <int, double>{};
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

  /// 名言只在打开阅读页时随机取一条，之后不再变化。
  ///
  /// 需求：底部名言固定展示，点击无响应，不允许手动或自动切换到下一条。
  /// 因此这里不再提供 rotateQuote，只在 [load] 里取一次。

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
