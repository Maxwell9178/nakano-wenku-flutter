import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../../core/models/book.dart';
import '../../core/services/book_repository.dart';

/// 书架状态控制器。
///
/// 只负责「书籍集合 + 当前居中书籍 + 列表筛选标签」这一层的状态，
/// 书籍解析、导入、阅读进度写入都由各自的模块负责，保持低耦合。
class BookshelfController extends ChangeNotifier {
  BookshelfController(this._repository);

  final BookRepository _repository;

  final List<Book> _books = <Book>[];

  /// 当前列表筛选标签，null 表示「全部」。
  String? _activeTag;

  /// 轮播当前居中书籍在 [_books] 中的下标。
  int _currentIndex = 0;

  bool _loaded = false;

  bool get isLoaded => _loaded;

  bool get hasBooks => _books.isNotEmpty;

  /// 全部书籍，始终按 NW 编号升序。
  List<Book> get books => List<Book>.unmodifiable(_books);

  String? get activeTag => _activeTag;

  int get currentIndex => _currentIndex;

  /// 当前居中高亮的书籍。
  Book? get currentBook {
    if (_books.isEmpty) {
      return null;
    }
    final int index = _currentIndex.clamp(0, _books.length - 1).toInt();
    return _books[index];
  }

  /// 筛选栏可选标签：内置 6 类在前，自定义标签按出现顺序追加。
  List<String> get availableTags {
    final List<String> result = List<String>.of(AppConstants.presetTags);
    for (final Book book in _books) {
      for (final String tag in book.tags) {
        if (!result.contains(tag)) {
          result.add(tag);
        }
      }
    }
    return result;
  }

  /// 列表区展示的书籍（已应用标签筛选）。
  List<Book> get visibleBooks {
    final String? tag = _activeTag;
    if (tag == null) {
      return List<Book>.unmodifiable(_books);
    }
    return List<Book>.unmodifiable(
      _books.where((Book book) => book.tags.contains(tag)),
    );
  }

  /// 启动时读取一次本地书籍数据。
  ///
  /// 仓库读取是同步的（SharedPreferences 已在启动时加载完成），
  /// 因此这里不需要异步，界面不会出现多余的 loading 闪烁。
  void load() {
    _books
      ..clear()
      ..addAll(_repository.loadAll());
    _loaded = true;
    _currentIndex = _initialIndex();
    notifyListeners();
  }

  /// 轮播居中书籍变化时调用，供信息区实时刷新。
  void selectIndex(int index) {
    if (_books.isEmpty) {
      return;
    }
    final int safe = index.clamp(0, _books.length - 1).toInt();
    if (safe == _currentIndex) {
      return;
    }
    _currentIndex = safe;
    notifyListeners();
  }

  /// 切换列表筛选标签；传 null 表示「全部」。
  void selectTag(String? tag) {
    if (_activeTag == tag) {
      return;
    }
    _activeTag = tag;
    notifyListeners();
  }

  /// 初始定位：上一次阅读过的书；没有阅读记录时定位到第一本。
  int _initialIndex() {
    if (_books.isEmpty) {
      return 0;
    }
    int bestIndex = 0;
    DateTime? latest;
    for (int i = 0; i < _books.length; i++) {
      final DateTime? readAt = _books[i].lastReadAt;
      if (readAt != null && (latest == null || readAt.isAfter(latest))) {
        latest = readAt;
        bestIndex = i;
      }
    }
    return bestIndex;
  }
}
