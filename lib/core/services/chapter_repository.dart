import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../constants/app_constants.dart';
import '../models/chapter.dart';

/// 章节正文与封面文件的本地磁盘读写。
///
/// 设计取舍：
/// * 书籍元数据量小，放在 SharedPreferences（见 BookRepository）；
/// * 章节正文可能几十 MB，按「一本书一个 JSON 文件」落在应用私有目录，
///   避免 SharedPreferences 被撑爆，也方便单本删除。
///
/// 目录结构（应用私有目录内，卸载 App 时自动清除）：
/// ```
/// library/
/// ├── chapters/NW-0001.json
/// └── covers/NW-0001.png
/// ```
class ChapterRepository {
  ChapterRepository();

  Directory? _cachedRoot;

  Future<Directory> _root() async {
    final Directory? cached = _cachedRoot;
    if (cached != null) {
      return cached;
    }
    final Directory support = await getApplicationSupportDirectory();
    final Directory root = Directory(p.join(support.path, 'library'));
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    _cachedRoot = root;
    return root;
  }

  Future<Directory> _subDirectory(String name) async {
    final Directory root = await _root();
    final Directory dir = Directory(p.join(root.path, name));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _fileStem(int bookNumber) => AppConstants.formatBookId(bookNumber);

  // ---------------- 章节 ----------------

  /// 读取一本书的全部章节；文件缺失或损坏时返回空列表，不抛异常。
  Future<List<Chapter>> load(int bookNumber) async {
    try {
      final Directory dir = await _subDirectory('chapters');
      final File file = File(p.join(dir.path, '${_fileStem(bookNumber)}.json'));
      if (!await file.exists()) {
        return <Chapter>[];
      }

      final dynamic decoded = jsonDecode(await file.readAsString());
      final dynamic rawChapters =
          decoded is Map<String, dynamic> ? decoded['chapters'] : decoded;
      if (rawChapters is! List) {
        return <Chapter>[];
      }

      return rawChapters
          .whereType<Map>()
          .map((Map<dynamic, dynamic> item) =>
              Chapter.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return <Chapter>[];
    }
  }

  /// 覆盖写入一本书的全部章节。
  Future<void> save(int bookNumber, List<Chapter> chapters) async {
    final Directory dir = await _subDirectory('chapters');
    final File file = File(p.join(dir.path, '${_fileStem(bookNumber)}.json'));
    final Map<String, dynamic> payload = <String, dynamic>{
      'number': bookNumber,
      'chapters': chapters.map((Chapter chapter) => chapter.toJson()).toList(),
    };
    await file.writeAsString(jsonEncode(payload), flush: true);
  }

  /// 删除一本书的全部章节文件（移除书籍时调用）。
  Future<void> delete(int bookNumber) async {
    try {
      final Directory dir = await _subDirectory('chapters');
      final File file = File(p.join(dir.path, '${_fileStem(bookNumber)}.json'));
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // 删除失败不阻断主流程：元数据已从书架移除即可。
    }
  }

  /// 修改书号时迁移章节文件：复制到新书号后再删除旧文件。
  Future<void> move(int fromNumber, int toNumber) async {
    if (fromNumber == toNumber) {
      return;
    }
    try {
      final Directory dir = await _subDirectory('chapters');
      final File source = File(p.join(dir.path, '${_fileStem(fromNumber)}.json'));
      if (!await source.exists()) {
        return;
      }
      final File target = File(p.join(dir.path, '${_fileStem(toNumber)}.json'));
      await source.copy(target.path);
      await source.delete();
    } catch (_) {
      // 迁移失败时保留原文件，章节仍可通过旧书号找回。
    }
  }

  // ---------------- 封面 ----------------

  /// 把用户选择的图片复制为本书封面，返回新路径。
  Future<String?> saveCoverFile(int bookNumber, String sourcePath) async {
    try {
      final File source = File(sourcePath);
      if (!await source.exists()) {
        return null;
      }
      final String extension = _normalizedImageExtension(p.extension(sourcePath));
      final Directory dir = await _subDirectory('covers');
      final File target =
          File(p.join(dir.path, '${_fileStem(bookNumber)}$extension'));
      await _removeExistingCovers(dir.path, bookNumber);
      final File copied = await source.copy(target.path);
      return copied.path;
    } catch (_) {
      return null;
    }
  }

  /// 把压缩包内解析出的封面字节写入磁盘（导入 EPUB 时使用）。
  Future<String?> saveCoverBytes(
    int bookNumber,
    Uint8List bytes,
    String extension,
  ) async {
    try {
      if (bytes.isEmpty) {
        return null;
      }
      final String safeExtension = _normalizedImageExtension('.$extension');
      final Directory dir = await _subDirectory('covers');
      final File target =
          File(p.join(dir.path, '${_fileStem(bookNumber)}$safeExtension'));
      await _removeExistingCovers(dir.path, bookNumber);
      await target.writeAsBytes(bytes, flush: true);
      return target.path;
    } catch (_) {
      return null;
    }
  }

  /// 删除封面文件（换书号或移除书籍时回收磁盘）。
  Future<void> deleteCover(String? path) async {
    if (path == null || path.isEmpty) {
      return;
    }
    try {
      final File file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // 忽略：图片可能被系统缓存占用，下次启动清理即可。
    }
  }

  /// 修改书号时迁移封面：旧图另存为新书号的封面，再删旧文件。
  Future<String?> moveCover(String? coverPath, int toNumber) async {
    if (coverPath == null || coverPath.isEmpty) {
      return null;
    }
    try {
      final File source = File(coverPath);
      if (!await source.exists()) {
        return null;
      }
      final Uint8List bytes = await source.readAsBytes();
      final String? saved = await saveCoverBytes(
        toNumber,
        bytes,
        p.extension(coverPath),
      );
      await deleteCover(coverPath);
      return saved;
    } catch (_) {
      return null;
    }
  }

  /// 同书号的旧封面可能是 .png/.jpg 两种后缀，换图前先清掉。
  Future<void> _removeExistingCovers(String directoryPath, int bookNumber) async {
    final String stem = _fileStem(bookNumber);
    for (final String extension in <String>['.png', '.jpg', '.jpeg', '.webp']) {
      final File file = File(p.join(directoryPath, '$stem$extension'));
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // 单个后缀删除失败不影响新封面写入。
      }
    }
  }

  /// 统一图片扩展名，非图片后缀一律按 png 处理。
  String _normalizedImageExtension(String raw) {
    final String extension = raw.toLowerCase().replaceAll('.', '');
    if (extension == 'jpg' || extension == 'jpeg') {
      return '.jpg';
    }
    if (extension == 'webp') {
      return '.webp';
    }
    if (extension == 'png') {
      return '.png';
    }
    return '.png';
  }
}
