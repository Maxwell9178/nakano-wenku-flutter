import 'dart:convert';

import '../constants/app_constants.dart';
import '../constants/storage_keys.dart';
import 'local_storage_service.dart';

/// 标签体系：系统预设 + 自定义，最多 10 个，系统标签也可以删。
///
/// 只负责「有哪些标签」，不负责「哪些书带哪些标签」——
/// 后者仍然写在书籍记录里（每本最多两个）。
class TagRepository {
  TagRepository(this._storage);

  final LocalStorageService _storage;

  /// 总上限（系统 + 自定义一起算）。
  static const int maxTags = 10;

  /// 每本书最多能选的标签数。
  static const int maxTagsPerBook = 2;

  List<String> get _custom => _stringList(StorageKeys.customTags);

  List<String> get _removed => _stringList(StorageKeys.removedTags);

  /// 当前生效的标签（顺序：系统标签在前，自定义在后）。
  List<String> get effectiveTags {
    final List<String> removed = _removed;
    final List<String> result = <String>[];
    for (final String tag in <String>[
      ...AppConstants.presetTags,
      ..._custom,
    ]) {
      if (removed.contains(tag) || result.contains(tag)) {
        continue;
      }
      result.add(tag);
    }
    return result.take(maxTags).toList(growable: false);
  }

  bool get isFull => effectiveTags.length >= maxTags;

  bool isPreset(String tag) => AppConstants.presetTags.contains(tag);

  /// 新增一个自定义标签；已存在或已满返回 false。
  Future<bool> add(String name) async {
    final String tag = name.trim();
    if (tag.isEmpty || tag.length > 8) {
      return false;
    }
    if (effectiveTags.contains(tag) || isFull) {
      return false;
    }
    final List<String> custom = <String>[..._custom, tag];
    // 之前被删掉了同名系统标签，这里顺手恢复。
    final List<String> removed = _removed..remove(tag);
    await _storage.setString(StorageKeys.customTags, jsonEncode(custom));
    await _storage.setString(StorageKeys.removedTags, jsonEncode(removed));
    return true;
  }

  /// 删除一个标签（系统标签同样可删）。
  Future<void> remove(String tag) async {
    if (isPreset(tag)) {
      final List<String> removed = <String>[..._removed, tag];
      await _storage.setString(StorageKeys.removedTags, jsonEncode(removed));
      return;
    }
    final List<String> custom = _custom..remove(tag);
    await _storage.setString(StorageKeys.customTags, jsonEncode(custom));
  }

  List<String> _stringList(String key) {
    final String? raw = _storage.getString(key);
    if (raw == null || raw.isEmpty) {
      return <String>[];
    }
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<String>().toList();
      }
    } catch (_) {}
    return <String>[];
  }
}
