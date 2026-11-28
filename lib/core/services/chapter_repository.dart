import 'dart:convert';
import 'dart:typed_data';

import '../constants/app_constants.dart';
import '../models/chapter.dart';
import '../platform/platform_store.dart';

/// 章节正文与封面文件的读写。
///
/// 设计取舍：
/// * 书籍元数据量小，放在 SharedPreferences（见 BookRepository）；
/// * 章节正文可能几十 MB，按「一本书一个 JSON」单独存放，
///   避免 SharedPreferences 被撑爆，也方便单本删除。
///
/// 存储位置由 `PlatformStore` 决定：
/// * Android：应用私有目录 `nwstore/chapters/NW-0001.json`；
/// * 网页：浏览器 IndexedDB（浏览器里没有文件系统）。
class ChapterRepository {
  ChapterRepository();

  String _fileStem(int bookNumber) => AppConstants.formatBookId(bookNumber);

  String _chapterKey(int bookNumber) =>
      'chapters/${_fileStem(bookNumber)}.json';

  String _coverKey(int bookNumber, String extension) =>
      'covers/${_fileStem(bookNumber)}$extension';

  // ---------------- 章节 ----------------

  /// 读取一本书的全部章节；数据缺失或损坏时返回空列表，不抛异常。
  Future<List<Chapter>> load(int bookNumber) async {
    try {
      final String? raw = await PlatformStore.readText(_chapterKey(bookNumber));
      if (raw == null || raw.isEmpty) {
        return <Chapter>[];
      }
      final dynamic decoded = jsonDecode(raw);
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
    final Map<String, dynamic> payload = <String, dynamic>{
      'number': bookNumber,
      'chapters': chapters.map((Chapter chapter) => chapter.toJson()).toList(),
    };
    await PlatformStore.writeText(_chapterKey(bookNumber), jsonEncode(payload));
  }

  /// 删除一本书的全部章节（移除书籍时调用）。
  Future<void> delete(int bookNumber) async {
    await PlatformStore.deleteKey(_chapterKey(bookNumber));
  }

  /// 修改书号时迁移章节：复制到新书号后再删除旧记录。
  Future<void> move(int fromNumber, int toNumber) async {
    if (fromNumber == toNumber) {
      return;
    }
    await PlatformStore.moveKey(_chapterKey(fromNumber), _chapterKey(toNumber));
  }

  // ---------------- 封面 ----------------

  /// 把用户选择的图片保存为本书封面，返回存储 token。
  Future<String?> saveCoverFile(int bookNumber, String sourcePath) async {
    try {
      Uint8List? bytes = await PlatformStore.readLocalFile(sourcePath);
      bytes ??= await PlatformStore.readBytes(sourcePath);
      if (bytes == null || bytes.isEmpty) {
        return null;
      }
      return saveCoverBytes(bookNumber, bytes, _extensionOfPath(sourcePath));
    } catch (_) {
      return null;
    }
  }

  /// 把解析出的封面字节写入存储（导入 EPUB 时使用）。
  Future<String?> saveCoverBytes(
    int bookNumber,
    Uint8List bytes,
    String extension,
  ) async {
    if (bytes.isEmpty) {
      return null;
    }
    final String safeExtension = _normalizedImageExtension(extension);
    // 同书号的旧封面可能是别的后缀，先清掉再写新的。
    for (final String candidate in <String>['.png', '.jpg', '.jpeg', '.webp']) {
      if (candidate != safeExtension) {
        await PlatformStore.deleteToken(
          PlatformStore.tokenFor(_coverKey(bookNumber, candidate)),
        );
      }
    }
    return PlatformStore.writeBytes(
      _coverKey(bookNumber, safeExtension),
      bytes,
    );
  }

  /// 删除封面（换书号或移除书籍时回收空间）。
  Future<void> deleteCover(String? path) async {
    await PlatformStore.deleteToken(path);
  }

  /// 修改书号时迁移封面：旧图另存为新书号的封面，再删旧数据。
  Future<String?> moveCover(String? coverPath, int toNumber) async {
    if (coverPath == null || coverPath.isEmpty) {
      return null;
    }
    try {
      final Uint8List? bytes = await PlatformStore.readBytes(coverPath);
      if (bytes == null) {
        return null;
      }
      final String? saved = await saveCoverBytes(toNumber, bytes, coverPath);
      if (saved != null) {
        await deleteCover(coverPath);
      }
      return saved;
    } catch (_) {
      return null;
    }
  }

  String _extensionOfPath(String path) {
    final int dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) {
      return '.png';
    }
    final String tail = path.substring(dot);
    // blob: 链接后面可能带查询串，只取前几个字符判断
    if (tail.contains('?')) {
      return tail.substring(0, tail.indexOf('?'));
    }
    return tail.length > 6 ? '.png' : tail;
  }

  /// 统一图片扩展名，非图片后缀一律按 png 处理。
  String _normalizedImageExtension(String raw) {
    String extension = raw.toLowerCase();
    final int dot = extension.lastIndexOf('.');
    if (dot >= 0) {
      extension = extension.substring(dot + 1);
    }
    if (extension.contains('?')) {
      extension = extension.substring(0, extension.indexOf('?'));
    }
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
