import 'dart:convert';

import '../constants/storage_keys.dart';
import '../models/excerpt.dart';
import 'local_storage_service.dart';

/// 摘抄库的本地读写。
///
/// 摘抄按时间倒序返回：最近收藏的排在最前面，方便阅读页快速回看。
class ExcerptRepository {
  const ExcerptRepository(this._storage);

  final LocalStorageService _storage;

  List<Excerpt> loadAll() {
    final String? raw = _storage.getString(StorageKeys.excerpts);
    if (raw == null || raw.isEmpty) {
      return <Excerpt>[];
    }
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <Excerpt>[];
      }
      final List<Excerpt> list = <Excerpt>[];
      for (final dynamic item in decoded) {
        if (item is Map<String, dynamic>) {
          list.add(Excerpt.fromJson(item));
        } else if (item is Map) {
          list.add(Excerpt.fromJson(Map<String, dynamic>.from(item)));
        }
      }
      list.sort((Excerpt a, Excerpt b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (_) {
      // 脏数据不阻断阅读，返回空摘抄库即可。
      return <Excerpt>[];
    }
  }

  Future<void> saveAll(List<Excerpt> excerpts) {
    final List<Map<String, dynamic>> payload =
        excerpts.map((Excerpt item) => item.toJson()).toList();
    return _storage.setString(StorageKeys.excerpts, jsonEncode(payload));
  }

  /// 追加一条摘抄，返回写入后的记录。
  Future<Excerpt> add({
    required int bookNumber,
    required String bookTitle,
    required int chapterIndex,
    required String chapterTitle,
    required String text,
  }) async {
    final String trimmed = text.trim();
    final Excerpt excerpt = Excerpt(
      id: 'excerpt-${DateTime.now().microsecondsSinceEpoch}',
      bookNumber: bookNumber,
      bookTitle: bookTitle,
      chapterIndex: chapterIndex,
      chapterTitle: chapterTitle,
      text: trimmed,
      createdAt: DateTime.now(),
    );
    final List<Excerpt> list = loadAll()..insert(0, excerpt);
    await saveAll(list);
    return excerpt;
  }

  Future<void> remove(String id) async {
    final List<Excerpt> list = loadAll();
    list.removeWhere((Excerpt item) => item.id == id);
    await saveAll(list);
  }

  /// 清空摘抄库（删除账号时使用）。
  Future<void> clear() => _storage.remove(StorageKeys.excerpts);
}
