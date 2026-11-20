import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../constants/storage_keys.dart';
import '../models/reading_preferences.dart';
import 'local_storage_service.dart';

/// 阅读偏好与阅读背景的本地读写。
///
/// 分工：
/// * 排版 / 操作参数 → 全局阅读偏好（[load] / [save]）；
/// * 背景图配置 → 每本书独立（[backgroundIdFor] / [setBackgroundFor]）；
/// * 用户上传的背景图片 → 全局公共背景库（[loadBackgrounds] / [importBackground]）。
class ReadingPreferencesRepository {
  const ReadingPreferencesRepository(this._storage);

  final LocalStorageService _storage;

  // ---------------- 阅读偏好 ----------------

  ReadingPreferences load() {
    final String? raw = _storage.getString(StorageKeys.readingPreferences);
    if (raw == null || raw.isEmpty) {
      return const ReadingPreferences();
    }
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return ReadingPreferences.fromJson(decoded);
      }
      if (decoded is Map) {
        return ReadingPreferences.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      // 脏数据不影响阅读：直接回落默认排版。
    }
    return const ReadingPreferences();
  }

  Future<void> save(ReadingPreferences preferences) {
    return _storage.setString(
      StorageKeys.readingPreferences,
      jsonEncode(preferences.toJson()),
    );
  }

  // ---------------- 每本书的背景 ----------------

  /// 读取某本书使用的背景 id。
  ///
  /// 优先级：本书单独配置 → 设置页选的默认背景 → 跟随主题（深色纯黑 / 浅色纯白）。
  String backgroundIdFor(int bookNumber, {bool darkTheme = false}) {
    final Map<String, dynamic> map = _loadBookBackgrounds();
    final String? id = map['$bookNumber'] as String?;
    if (id != null && id.isNotEmpty) {
      return id;
    }
    final String preferred = load().defaultBackgroundId;
    if (preferred.isNotEmpty) {
      return preferred;
    }
    return darkTheme ? ReadingBackground.blackId : ReadingBackground.lightId;
  }

  Future<void> setBackgroundFor(int bookNumber, String backgroundId) {
    final Map<String, dynamic> map = _loadBookBackgrounds();
    map['$bookNumber'] = backgroundId;
    return _storage.setString(
      StorageKeys.bookBackgrounds,
      jsonEncode(map),
    );
  }

  Map<String, dynamic> _loadBookBackgrounds() {
    final String? raw = _storage.getString(StorageKeys.bookBackgrounds);
    if (raw == null || raw.isEmpty) {
      return <String, dynamic>{};
    }
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return Map<String, dynamic>.from(decoded);
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // 忽略损坏的背景配置。
    }
    return <String, dynamic>{};
  }

  // ---------------- 全局背景库 ----------------

  /// 读取用户上传过的全部背景图（不含内置背景）。
  List<ReadingBackground> loadBackgrounds() {
    final String? raw = _storage.getString(StorageKeys.readingBackgrounds);
    if (raw == null || raw.isEmpty) {
      return <ReadingBackground>[];
    }
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <ReadingBackground>[];
      }
      final List<ReadingBackground> list = <ReadingBackground>[];
      for (final dynamic item in decoded) {
        if (item is Map<String, dynamic>) {
          list.add(ReadingBackground.fromJson(item));
        } else if (item is Map) {
          list.add(ReadingBackground.fromJson(Map<String, dynamic>.from(item)));
        }
      }
      return list;
    } catch (_) {
      return <ReadingBackground>[];
    }
  }

  /// 把用户选择的图片拷进应用私有目录，并登记到全局背景库。
  ///
  /// 返回登记后的背景对象；拷贝失败返回 null，由调用方给出柔和提示。
  Future<ReadingBackground?> importBackground(String sourcePath) async {
    try {
      final File source = File(sourcePath);
      if (!await source.exists()) {
        return null;
      }

      final Directory directory = await _backgroundDirectory();
      final String extension = _normalizedExtension(p.extension(sourcePath));
      final String fileName =
          'bg_${DateTime.now().microsecondsSinceEpoch}$extension';
      final File target = File(p.join(directory.path, fileName));
      await source.copy(target.path);

      final ReadingBackground background = ReadingBackground(
        id: 'custom-${DateTime.now().microsecondsSinceEpoch}',
        name: '自定义背景 ${_nextNameIndex()}',
        path: target.path,
      );

      final List<ReadingBackground> list = loadBackgrounds()..add(background);
      await _saveBackgrounds(list);
      return background;
    } catch (_) {
      return null;
    }
  }

  /// 从背景库移除一张图，并顺手删掉对应文件。
  Future<void> removeBackground(String id) async {
    final List<ReadingBackground> list = loadBackgrounds();
    final List<ReadingBackground> next = <ReadingBackground>[];
    for (final ReadingBackground background in list) {
      if (background.id == id) {
        final String? path = background.path;
        if (path != null && path.isNotEmpty) {
          try {
            final File file = File(path);
            if (await file.exists()) {
              await file.delete();
            }
          } catch (_) {
            // 文件被系统占用时忽略，避免影响列表更新。
          }
        }
      } else {
        next.add(background);
      }
    }
    await _saveBackgrounds(next);
  }

  /// 清空阅读偏好、每本书背景配置与全局背景库（删除账号时使用）。
  ///
  /// 背景图片文件一并删除，避免占用存储空间。
  Future<void> clearAll() async {
    final List<ReadingBackground> backgrounds = loadBackgrounds();
    for (final ReadingBackground background in backgrounds) {
      final String? path = background.path;
      if (path == null || path.isEmpty) {
        continue;
      }
      try {
        final File file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // 文件被占用时忽略，配置已经清掉即可。
      }
    }

    await _storage.remove(StorageKeys.readingPreferences);
    await _storage.remove(StorageKeys.bookBackgrounds);
    await _storage.remove(StorageKeys.readingBackgrounds);
  }

  Future<void> _saveBackgrounds(List<ReadingBackground> list) {
    final List<Map<String, dynamic>> payload =
        list.map((ReadingBackground item) => item.toJson()).toList();
    return _storage.setString(
      StorageKeys.readingBackgrounds,
      jsonEncode(payload),
    );
  }

  Future<Directory> _backgroundDirectory() async {
    final Directory support = await getApplicationSupportDirectory();
    final Directory directory =
        Directory(p.join(support.path, 'library', 'backgrounds'));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  String _normalizedExtension(String extension) {
    final String lower = extension.toLowerCase();
    if (lower == '.jpg' ||
        lower == '.jpeg' ||
        lower == '.png' ||
        lower == '.webp') {
      return lower;
    }
    return '.png';
  }

  int _nextNameIndex() {
    final int count = loadBackgrounds().length + 1;
    return count;
  }
}
