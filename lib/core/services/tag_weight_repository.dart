import 'dart:convert';

import '../constants/storage_keys.dart';
import '../models/book.dart';
import 'local_storage_service.dart';

/// 阅读兴趣标签统计（雷达图数据源）。
///
/// 规则：
/// 1. 维度就是书架上真实存在的六个标签（文学/热血/科幻/恋爱/运动/悬疑）；
/// 2. 计分权重 = 该书累计阅读分钟数 + 1；
/// 3. 没有命中任何维度的书不计分；
/// 4. 结果归一化到 0~1，供雷达图直接取用。
class TagWeightRepository {
  const TagWeightRepository(this._storage);

  final LocalStorageService _storage;

  /// 雷达图的六个维度（顺序固定，界面据此绘制轴）。
  ///
  /// 直接复用导入时的预设标签，避免出现书架上根本没有的分类，
  /// 也避免两处清单各自演化后对不上。
  static const List<String> dimensions = <String>[
    '文学',
    '热血',
    '科幻',
    '恋爱',
    '运动',
    '悬疑',
  ];

  /// 读取已持久化的分值（标签 → 原始分钟权重）。
  Map<String, int> loadRaw() {
    final String? raw = _storage.getString(StorageKeys.tagScores);
    if (raw == null || raw.isEmpty) {
      return <String, int>{};
    }
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return <String, int>{};
      }
      final Map<String, int> result = <String, int>{};
      decoded.forEach((dynamic key, dynamic value) {
        if (key is String && value is num) {
          result[key] = value.toInt();
        }
      });
      return result;
    } catch (_) {
      return <String, int>{};
    }
  }

  Future<void> saveRaw(Map<String, int> scores) {
    return _storage.setString(StorageKeys.tagScores, jsonEncode(scores));
  }

  /// 根据当前书籍列表重算权重并持久化。
  ///
  /// [books] 传入完整书架数据：只有带标签的书参与统计。
  Future<Map<String, int>> recompute(List<Book> books) async {
    final Map<String, int> scores = <String, int>{
      for (final String dim in dimensions) dim: 0,
    };

    for (final Book book in books) {
      if (book.tags.isEmpty) {
        continue;
      }
      final int minutes = book.totalReadMs <= 0
          ? 1
          : (book.totalReadMs / 60000).ceil().clamp(1, 100000);
      for (final String tag in book.tags) {
        final String trimmed = tag.trim();
        if (trimmed.isEmpty) {
          continue;
        }
        // 精确命中维度之一才计入，其它自定义标签保持沉默，避免图形失真。
        if (!scores.containsKey(trimmed)) {
          continue;
        }
        scores[trimmed] = (scores[trimmed] ?? 0) + minutes;
      }
    }

    await saveRaw(scores);
    return scores;
  }

  /// 归一化后的 0~1 分值，顺序与 [dimensions] 一致。
  List<double> normalized(Map<String, int> raw) {
    final int maxValue = raw.values.fold<int>(
        0,
        (
          int previous,
          int value,
        ) =>
            value > previous ? value : previous);
    if (maxValue <= 0) {
      return List<double>.filled(dimensions.length, 0);
    }
    return dimensions
        .map((String dim) => ((raw[dim] ?? 0) / maxValue).clamp(0.0, 1.0))
        .toList();
  }

  Future<void> clear() => _storage.remove(StorageKeys.tagScores);
}
