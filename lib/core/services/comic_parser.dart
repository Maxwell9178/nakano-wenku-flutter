import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';

import '../models/chapter.dart';

/// CBX / CBZ 漫画解析结果。
///
/// 漫画没有「文字章节」，这里把压缩包里的每一张图片当成一页：
/// 图片被解压到应用私有目录 `library/comics/comic_<时间戳>/`，
/// 页面路径写入 [Chapter.content]，后续阅读器直接按路径加载。
class ParsedComic {
  const ParsedComic({
    required this.title,
    required this.pages,
    required this.directory,
    this.coverBytes,
    this.coverExtension = 'jpg',
  });

  final String title;

  /// 每一页的绝对路径，顺序即阅读顺序。
  final List<String> pages;

  /// 图片解压目录。
  final String directory;

  final List<int>? coverBytes;
  final String coverExtension;

  int get pageCount => pages.length;

  List<Chapter> toChapters() {
    return List<Chapter>.generate(pages.length, (int index) {
      return Chapter(
        title: '第 ${index + 1} 页',
        content: pages[index],
        wordCount: 1,
      );
    });
  }
}

/// 漫画压缩包解析器。
///
/// 只支持「zip 里全是图片」的 CBX/CBZ；遇到非图片条目直接跳过，
/// 一张图都没有时抛出 [ComicParseException]，由导入页提示用户。
class ComicParser {
  static const Set<String> comicExtensions = <String>{'cbx', 'cbz'};

  static const Set<String> _imageExtensions = <String>{
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
    'bmp',
  };

  Future<ParsedComic> parseFile(
    String path, {
    String? fallbackTitle,
  }) async {
    final File file = File(path);
    if (!await file.exists()) {
      throw const ComicParseException('文件不存在');
    }

    List<int> bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      throw const ComicParseException('文件读取失败，请检查存储权限');
    }

    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: false);
    } catch (_) {
      throw const ComicParseException('漫画包已损坏，无法解压');
    }

    final List<_ComicEntry> entries = <_ComicEntry>[];
    for (final ArchiveFile item in archive) {
      if (!item.isFile) {
        continue;
      }
      final String name = item.name;
      if (name.startsWith('__MACOSX/') || name.contains('/._')) {
        continue;
      }
      final String extension = _extensionOf(name);
      if (!_imageExtensions.contains(extension)) {
        continue;
      }
      entries.add(
        _ComicEntry(name: name, bytes: _readEntry(item), extension: extension),
      );
    }

    if (entries.isEmpty) {
      throw const ComicParseException('漫画包里没有图片，无法解析');
    }

    entries.sort(
      (_ComicEntry a, _ComicEntry b) => _naturalCompare(a.name, b.name),
    );

    final Directory root = await getApplicationSupportDirectory();
    final Directory target = Directory(
      '${root.path}/library/comics/comic_${DateTime.now().microsecondsSinceEpoch}',
    );
    await target.create(recursive: true);

    final List<String> pages = <String>[];
    for (int index = 0; index < entries.length; index++) {
      final _ComicEntry entry = entries[index];
      final String pageName =
          '${(index + 1).toString().padLeft(4, '0')}.${entry.extension}';
      final File pageFile = File('${target.path}/$pageName');
      try {
        await pageFile.writeAsBytes(entry.bytes, flush: true);
      } catch (_) {
        throw const ComicParseException('漫画图片写入失败，请检查存储空间');
      }
      pages.add(pageFile.path);
    }

    final String baseName =
        file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : '未命名漫画';
    final String title = fallbackTitle?.trim().isNotEmpty == true
        ? fallbackTitle!.trim()
        : _stripExtension(baseName);

    return ParsedComic(
      title: title,
      pages: pages,
      directory: target.path,
      coverBytes: entries.first.bytes,
      coverExtension: entries.first.extension,
    );
  }

  List<int> _readEntry(ArchiveFile item) {
    try {
      final dynamic content = item.content;
      if (content is List<int>) {
        return content;
      }
    } catch (_) {
      // 继续尝试 readBytes。
    }
    try {
      // archive 3.x / 4.x 的读取入口不同，这里用 dynamic 兜住两种实现。
      final dynamic dynamicItem = item;
      final dynamic read = dynamicItem.readBytes();
      if (read is List<int>) {
        return read;
      }
    } catch (_) {
      // 读取失败按空内容处理。
    }
    return <int>[];
  }

  static String _extensionOf(String name) {
    final int dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) {
      return '';
    }
    return name.substring(dot + 1).toLowerCase();
  }

  static String _stripExtension(String name) {
    final int dot = name.lastIndexOf('.');
    return dot <= 0 ? name : name.substring(0, dot);
  }

  /// 自然排序：`p2.jpg` 排在 `p10.jpg` 之前。
  static int _naturalCompare(String a, String b) {
    final RegExp digitGroup = RegExp(r'\d+|\D+');
    final List<String> aParts = a.toLowerCase().split('/').last.isEmpty
        ? <String>[a]
        : digitGroup
            .allMatches(a.toLowerCase().split('/').last)
            .map((
              RegExpMatch m,
            ) =>
                m.group(0)!)
            .toList();
    final List<String> bParts = digitGroup
        .allMatches(b.toLowerCase().split('/').last)
        .map((RegExpMatch m) => m.group(0)!)
        .toList();

    final int length =
        aParts.length < bParts.length ? aParts.length : bParts.length;
    for (int index = 0; index < length; index++) {
      final String aPart = aParts[index];
      final String bPart = bParts[index];
      final int? aNumber = int.tryParse(aPart);
      final int? bNumber = int.tryParse(bPart);
      if (aNumber != null && bNumber != null) {
        if (aNumber != bNumber) {
          return aNumber.compareTo(bNumber);
        }
        continue;
      }
      final int compare = aPart.compareTo(bPart);
      if (compare != 0) {
        return compare;
      }
    }
    return aParts.length.compareTo(bParts.length);
  }
}

class _ComicEntry {
  _ComicEntry({
    required this.name,
    required this.bytes,
    required this.extension,
  });

  final String name;
  final List<int> bytes;
  final String extension;
}

class ComicParseException implements Exception {
  const ComicParseException(this.message);

  final String message;

  @override
  String toString() => message;
}
