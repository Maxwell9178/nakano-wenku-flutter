import 'package:flutter/foundation.dart';

import '../../core/models/book.dart';
import '../../core/services/book_repository.dart';

/// 搜索页的查询与联想逻辑。
///
/// 只做本地匹配，不联网、不请求任何接口：
/// 匹配范围是书名、作者、标签与 NW 编号，按「前缀 > 包含 > 作者 > 标签」
/// 的优先级排序，命中越靠前越符合用户预期。
class LibrarySearchController extends ChangeNotifier {
  LibrarySearchController(this._books);

  final BookRepository _books;

  List<Book> _all = const <Book>[];
  String _query = '';

  String get query => _query;

  bool get hasQuery => _query.trim().isNotEmpty;

  /// 全部藏书数量，用于空态提示。
  int get totalBooks => _all.length;

  /// 进入页面时读一次本地书籍；切换标签回来可再次调用。
  void loadBooks() {
    _all = _books.loadAll();
    notifyListeners();
  }

  void updateQuery(String value) {
    if (_query == value) {
      return;
    }
    _query = value;
    notifyListeners();
  }

  void clear() {
    if (_query.isEmpty) {
      return;
    }
    _query = '';
    notifyListeners();
  }

  /// 联想结果：最多 40 条，够用且不会一次性构建过多条目。
  List<Book> get results {
    final String keyword = _query.trim().toLowerCase();
    if (keyword.isEmpty) {
      return const <Book>[];
    }

    final List<Book> matches = <Book>[];
    for (final Book book in _all) {
      if (_rank(book, keyword) >= 0) {
        matches.add(book);
      }
    }
    matches.sort((Book a, Book b) {
      final int rankA = _rank(a, keyword);
      final int rankB = _rank(b, keyword);
      if (rankA != rankB) {
        return rankA.compareTo(rankB);
      }
      return a.number.compareTo(b.number);
    });

    return matches.take(40).toList(growable: false);
  }

  /// 返回匹配优先级，-1 表示不匹配。
  static int _rank(Book book, String keyword) {
    final String title = book.title.toLowerCase();
    final String author = book.author.toLowerCase();

    if (title.startsWith(keyword)) {
      return 0;
    }
    if (title.contains(keyword)) {
      return 1;
    }
    if (author.contains(keyword)) {
      return 2;
    }
    for (final String tag in book.tags) {
      if (tag.toLowerCase().contains(keyword)) {
        return 3;
      }
    }
    if (book.id.toLowerCase().contains(keyword)) {
      return 4;
    }
    return -1;
  }
}
