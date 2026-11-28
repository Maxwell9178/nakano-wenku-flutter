import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../constants/storage_keys.dart';
import 'local_storage_service.dart';

/// 按「书 + 章节」记录章内阅读比例。
///
/// 书籍记录里只有一个整本书的 progress，退出后再进来只能回到章节开头；
/// 长章节用户要重新翻很久。这里单独存一份细粒度位置：
/// `{ "书的编号": { "章节序号": 0.42 } }`，与整体进度互不干扰。
class ReadingPositionRepository {
  const ReadingPositionRepository(this._storage);

  final LocalStorageService _storage;

  Future<Map<String, Map<int, double>>> _loadRaw() async {
    final String? raw = _storage.getString(StorageKeys.chapterPositions);
    if (raw == null || raw.isEmpty) {
      return <String, Map<int, double>>{};
    }
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return <String, Map<int, double>>{};
      }
      final Map<String, Map<int, double>> result = <String, Map<int, double>>{};
      decoded.forEach((dynamic key, dynamic value) {
        if (value is! Map) {
          return;
        }
        final Map<int, double> chapters = <int, double>{};
        value.forEach((dynamic ck, dynamic cv) {
          final int? index = int.tryParse('$ck');
          final double? ratio =
              cv is num ? cv.toDouble() : double.tryParse('$cv');
          if (index != null && ratio != null) {
            chapters[index] = ratio.clamp(0.0, 1.0).toDouble();
          }
        });
        if (chapters.isNotEmpty) {
          result['$key'] = chapters;
        }
      });
      return result;
    } catch (error) {
      debugPrint('[NakanoWenku][positions] 读取失败：$error');
      return <String, Map<int, double>>{};
    }
  }

  /// 某本书的全部章节位置。
  Future<Map<int, double>> loadForBook(int bookNumber) async {
    final Map<String, Map<int, double>> all = await _loadRaw();
    return all['$bookNumber'] ?? <int, double>{};
  }

  /// 记录一章读到的位置（比例 0~1）。
  Future<void> save(int bookNumber, int chapter, double ratio) async {
    if (chapter < 0) {
      return;
    }
    final double safe = ratio.clamp(0.0, 1.0).toDouble();
    final Map<String, Map<int, double>> all = await _loadRaw();
    final Map<int, double> chapters = all['$bookNumber'] ?? <int, double>{};
    // 只有明显移动才写盘，减少滚动时的 IO。
    final double? previous = chapters[chapter];
    if (previous != null && (previous - safe).abs() < 0.01) {
      return;
    }
    chapters[chapter] = safe;
    all['$bookNumber'] = chapters;
    final Map<String, Map<String, double>> encoded =
        <String, Map<String, double>>{};
    all.forEach((String key, Map<int, double> value) {
      encoded[key] = value.map(
        (int k, double v) => MapEntry<String, double>('$k', v),
      );
    });
    try {
      await _storage.setString(
        StorageKeys.chapterPositions,
        jsonEncode(encoded),
      );
    } catch (error) {
      debugPrint('[NakanoWenku][positions] 写入失败：$error');
    }
  }

  Future<void> clear() async {
    await _storage.remove(StorageKeys.chapterPositions);
  }
}
