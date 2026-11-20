import 'dart:convert';

import '../constants/app_constants.dart';
import '../constants/storage_keys.dart';
import '../models/book.dart';
import 'local_storage_service.dart';

/// 书籍数据的本地读写。
///
/// 纯本地优先：全部书籍记录以 JSON 数组字符串的形式存在
/// SharedPreferences 里，导入轮次再补上章节正文的落盘方式。
/// 读写都做异常兜底，任何一条脏数据都不允许让书架白屏。
class BookRepository {
  const BookRepository(this._storage);

  final LocalStorageService _storage;

  /// 读取全部书籍，按 NW 编号升序返回。
  List<Book> loadAll() {
    final String? raw = _storage.getString(StorageKeys.books);
    if (raw == null || raw.isEmpty) {
      return <Book>[];
    }

    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <Book>[];
      }

      final List<Book> books = <Book>[];
      for (final dynamic item in decoded) {
        if (item is Map<String, dynamic>) {
          books.add(Book.fromJson(item));
        } else if (item is Map) {
          books.add(Book.fromJson(Map<String, dynamic>.from(item)));
        }
      }
      books.sort((Book a, Book b) => a.number.compareTo(b.number));
      return books;
    } catch (_) {
      // 数据损坏时返回空书架，而不是让应用启动失败。
      return <Book>[];
    }
  }

  /// 覆盖写入全部书籍。
  Future<void> saveAll(List<Book> books) async {
    final List<Map<String, dynamic>> payload = books
        .map((Book book) => book.toJson())
        .toList();
    await _storage.setString(StorageKeys.books, jsonEncode(payload));
  }

  /// 分配下一个可用编号（0001 → 9999）。
  ///
  /// 优先取「最大编号 + 1」，这样删除中间某本后新书不会回填旧号；
  /// 但最大编号已经顶到 9999 时就改为找当前最小空闲号，
  /// 避免 `clamp` 之后永远返回 9999 从而覆盖已有书籍。
  int nextNumber(List<Book> books) {
    final Set<int> used = <int>{
      for (final Book book in books) book.number,
    };
    int max = 0;
    for (final int number in used) {
      if (number > max) {
        max = number;
      }
    }
    if (max < AppConstants.bookIdMax) {
      return (max + 1).clamp(AppConstants.bookIdMin, AppConstants.bookIdMax)
          .toInt();
    }
    for (int candidate = AppConstants.bookIdMin;
        candidate <= AppConstants.bookIdMax;
        candidate++) {
      if (!used.contains(candidate)) {
        return candidate;
      }
    }
    // 0001–9999 全部被占用：返回最大编号，由调用方决定如何提示。
    return AppConstants.bookIdMax;
  }
}
