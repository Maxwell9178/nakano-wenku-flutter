import 'dart:convert';

import '../constants/storage_keys.dart';
import '../models/bookmark.dart';
import 'local_storage_service.dart';

/// 书签库的本地读写。
///
/// 存储结构与阅读进度完全分离：进度只保存「上次读到的章节」，
/// 书签是用户主动标记的列表，可多条、可带备注、可删除。
class BookmarkRepository {
  const BookmarkRepository(this._storage);

  final LocalStorageService _storage;

  List<Bookmark> loadAll() {
    final String? raw = _storage.getString(StorageKeys.bookmarks);
    if (raw == null || raw.isEmpty) {
      return <Bookmark>[];
    }
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <Bookmark>[];
      }
      final List<Bookmark> list = <Bookmark>[];
      for (final dynamic item in decoded) {
        if (item is Map<String, dynamic>) {
          list.add(Bookmark.fromJson(item));
        } else if (item is Map) {
          list.add(Bookmark.fromJson(Map<String, dynamic>.from(item)));
        }
      }
      list.sort((
        Bookmark a,
        Bookmark b,
      ) =>
          b.createdAt?.compareTo(a.createdAt ?? DateTime(0)) ?? 0);
      return list;
    } catch (_) {
      return <Bookmark>[];
    }
  }

  /// 指定书籍的书签，按章节顺序排列（阅读页查看更符合直觉）。
  List<Bookmark> loadForBook(int bookNumber) {
    final List<Bookmark> list = loadAll()
        .where((Bookmark item) => item.bookNumber == bookNumber)
        .toList();
    list.sort((Bookmark a, Bookmark b) {
      final int byChapter = a.chapterIndex.compareTo(b.chapterIndex);
      if (byChapter != 0) {
        return byChapter;
      }
      return a.ratio.compareTo(b.ratio);
    });
    return list;
  }

  Future<void> saveAll(List<Bookmark> bookmarks) {
    final List<Map<String, dynamic>> payload =
        bookmarks.map((Bookmark item) => item.toJson()).toList();
    return _storage.setString(StorageKeys.bookmarks, jsonEncode(payload));
  }

  Future<Bookmark> add({
    required int bookNumber,
    required int chapterIndex,
    required String chapterTitle,
    double ratio = 0,
    String note = '',
  }) async {
    final Bookmark bookmark = Bookmark(
      id: 'bookmark-${DateTime.now().microsecondsSinceEpoch}',
      bookNumber: bookNumber,
      chapterIndex: chapterIndex,
      chapterTitle: chapterTitle,
      ratio: ratio.clamp(0.0, 1.0).toDouble(),
      note: note.trim(),
      createdAt: DateTime.now(),
    );
    final List<Bookmark> list = loadAll()..insert(0, bookmark);
    await saveAll(list);
    return bookmark;
  }

  Future<void> remove(String id) async {
    final List<Bookmark> list = loadAll();
    list.removeWhere((Bookmark item) => item.id == id);
    await saveAll(list);
  }

  Future<void> removeForBook(int bookNumber) async {
    final List<Bookmark> list = loadAll();
    list.removeWhere((Bookmark item) => item.bookNumber == bookNumber);
    await saveAll(list);
  }

  Future<void> clear() => _storage.remove(StorageKeys.bookmarks);
}
