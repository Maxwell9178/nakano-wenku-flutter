import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../models/chapter.dart';

/// 解析失败时抛出，`message` 直接用于界面提示。
class BookParseException implements Exception {
  BookParseException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 解析出的一本书（可能来自单个文件，也可能来自 ZIP 内的一个条目）。
class ParsedBook {
  ParsedBook({
    required this.title,
    required this.author,
    required this.chapters,
    required this.sourceName,
    this.coverBytes,
    this.coverExtension = 'png',
  });

  final String title;
  final String author;
  final List<Chapter> chapters;
  final String sourceName;

  /// EPUB 内嵌封面；为空时书架绘制灰色占位封面。
  final Uint8List? coverBytes;

  /// 封面扩展名（不带点）。
  final String coverExtension;

  int get wordCount =>
      chapters.fold<int>(0, (int sum, Chapter chapter) => sum + chapter.wordCount);
}

/// 纯 Dart 电子书解析器。
///
/// 支持情况（全部离线、不依赖原生插件）：
/// * **EPUB**：解析 container.xml → OPF → spine，按 spine 顺序取 XHTML 正文，
///   并读取 `dc:title` / `dc:creator` 与内嵌封面；
/// * **TXT / Markdown**：按「第 X 章 / Chapter N」等标题行切章，无标题则按长度分块；
/// * **DOCX**：读取 `word/document.xml` 的段落文本再切章；
/// * **ZIP**：展开压缩包，把内部可解析的书籍逐个当作一卷返回（对应多卷导入逻辑）；
/// * **PDF / DOC**：老格式或复杂排版暂不做正文提取，导入时给出明确提示而不是崩溃。
///
/// 依赖说明：archive 3.x / 4.x 的 `ArchiveFile.content` 类型略有差异，
/// 这里统一用 dynamic 读取，避免版本升级后编译不过。
class BookParser {
  const BookParser();

  /// 可解析正文的格式。
  static const Set<String> parseableExtensions = <String>{
    'epub',
    'txt',
    'md',
    'markdown',
    'docx',
    'zip',
  };

  // ---------------- 对外入口 ----------------

  /// 解析一个本地文件，返回其中包含的全部书籍（ZIP 可能返回多本）。
  Future<List<ParsedBook>> parseFile(String path) async {
    final String extension =
        p.extension(path).replaceFirst('.', '').toLowerCase();
    final String displayName = p.basename(path);

    switch (extension) {
      case 'epub':
        return <ParsedBook>[
          await _parseEpubBytes(await File(path).readAsBytes(), displayName),
        ];
      case 'txt':
      case 'md':
      case 'markdown':
        return <ParsedBook>[
          await _parseTextBytes(
            await File(path).readAsBytes(),
            displayName,
            extension,
          ),
        ];
      case 'docx':
        return <ParsedBook>[
          await _parseDocxBytes(await File(path).readAsBytes(), displayName),
        ];
      case 'zip':
        return _parseZipBytes(await File(path).readAsBytes(), displayName);
      case 'pdf':
        throw BookParseException(
          'PDF 正文解析暂未支持，请先转换为 TXT 或 EPUB 后再导入。',
        );
      case 'doc':
        throw BookParseException(
          'DOC 为旧版二进制格式，暂无法提取正文，请另存为 DOCX 后再导入。',
        );
      default:
        throw BookParseException('暂不支持 .$extension 格式');
    }
  }

  // ---------------- EPUB ----------------

  Future<ParsedBook> _parseEpubBytes(
    Uint8List bytes,
    String displayName,
  ) async {
    final Archive archive = _decodeZip(bytes);

    // 1. 从 META-INF/container.xml 找到 OPF 路径。
    String opfPath = '';
    final ArchiveFile? container = _findEntry(archive, 'META-INF/container.xml');
    if (container != null) {
      final String containerXml = _decodeText(_entryBytes(container));
      final RegExpMatch? match =
          RegExp(r'full-path\s*=\s*"([^"]+)"').firstMatch(containerXml);
      if (match != null) {
        opfPath = match.group(1)!.trim();
      }
    }
    if (opfPath.isEmpty) {
      for (final ArchiveFile file in archive.files) {
        if (file.name.toLowerCase().endsWith('.opf')) {
          opfPath = file.name;
          break;
        }
      }
    }
    if (opfPath.isEmpty) {
      throw BookParseException('EPUB 结构异常：缺少 OPF 描述文件');
    }

    final ArchiveFile? opf = _findEntry(archive, opfPath);
    if (opf == null) {
      throw BookParseException('EPUB 结构异常：OPF 文件不可读');
    }
    final String opfXml = _decodeText(_entryBytes(opf));
    final String opfDirectory = _directoryOf(opfPath);

    final String title =
        _firstTagText(opfXml, 'dc:title') ?? _stripExtension(displayName);
    final String author = _firstTagText(opfXml, 'dc:creator') ?? '佚名';

    // 2. 解析 manifest：id → href / media-type / properties。
    final Map<String, _ManifestItem> manifest = <String, _ManifestItem>{};
    for (final RegExpMatch match
        in RegExp(r'<item\b[^>]*>', caseSensitive: false).allMatches(opfXml)) {
      final String tag = match.group(0)!;
      final String? id = _attribute(tag, 'id');
      final String? href = _attribute(tag, 'href');
      if (id == null || href == null || href.isEmpty) {
        continue;
      }
      manifest[id] = _ManifestItem(
        href: href,
        mediaType: _attribute(tag, 'media-type') ?? '',
        properties: _attribute(tag, 'properties') ?? '',
      );
    }

    // 3. 按 spine 顺序取正文。
    final List<Chapter> chapters = <Chapter>[];
    for (final RegExpMatch match
        in RegExp(r'<itemref\b[^>]*>', caseSensitive: false).allMatches(opfXml)) {
      final String? idref = _attribute(match.group(0)!, 'idref');
      if (idref == null) {
        continue;
      }
      final _ManifestItem? item = manifest[idref];
      if (item == null || !_isHtmlDocument(item)) {
        continue;
      }

      final ArchiveFile? entry =
          _findEntry(archive, _resolvePath(opfDirectory, item.href));
      if (entry == null) {
        continue;
      }

      final String html = _decodeText(_entryBytes(entry));
      final String text = _htmlToText(html);
      if (text.trim().isEmpty) {
        continue;
      }

      final String heading = _htmlHeading(html) ?? '第 ${chapters.length + 1} 章';
      chapters.add(Chapter.fromText(heading, text));
    }

    if (chapters.isEmpty) {
      throw BookParseException('EPUB 中没有解析到正文内容');
    }

    // 4. 封面：优先 properties="cover-image"，其次 <meta name="cover">。
    Uint8List? coverBytes;
    String coverExtension = 'png';
    _ManifestItem? coverItem;
    for (final _ManifestItem item in manifest.values) {
      if (item.properties.split(' ').contains('cover-image')) {
        coverItem = item;
        break;
      }
    }
    if (coverItem == null) {
      final String? coverId = _coverIdFromMeta(opfXml);
      if (coverId != null) {
        coverItem = manifest[coverId];
      }
    }
    if (coverItem != null) {
      final ArchiveFile? coverEntry =
          _findEntry(archive, _resolvePath(opfDirectory, coverItem.href));
      if (coverEntry != null) {
        coverBytes = _entryBytes(coverEntry);
        coverExtension = _coverExtension(coverItem);
      }
    }

    return ParsedBook(
      title: title,
      author: author,
      chapters: chapters,
      sourceName: displayName,
      coverBytes: coverBytes,
      coverExtension: coverExtension,
    );
  }

  bool _isHtmlDocument(_ManifestItem item) {
    final String mediaType = item.mediaType.toLowerCase();
    if (mediaType.contains('html') || mediaType.contains('xml')) {
      return true;
    }
    final String href = item.href.toLowerCase();
    return href.endsWith('.xhtml') ||
        href.endsWith('.html') ||
        href.endsWith('.htm');
  }

  String _coverExtension(_ManifestItem item) {
    final String mediaType = item.mediaType.toLowerCase();
    if (mediaType.contains('jpeg') || mediaType.contains('jpg')) {
      return 'jpg';
    }
    if (mediaType.contains('webp')) {
      return 'webp';
    }
    return 'png';
  }

  String? _coverIdFromMeta(String opfXml) {
    final RegExpMatch? match = RegExp(
      r'<meta\b[^>]*name\s*=\s*"cover"[^>]*content\s*=\s*"([^"]+)"',
      caseSensitive: false,
    ).firstMatch(opfXml);
    return match?.group(1);
  }

  // ---------------- TXT / Markdown ----------------

  Future<ParsedBook> _parseTextBytes(
    Uint8List bytes,
    String displayName,
    String extension,
  ) async {
    final String raw = _decodeText(bytes);
    final String text = _stripBom(raw).replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    final List<Chapter> chapters =
        extension == 'md' || extension == 'markdown'
            ? _splitMarkdown(text)
            : _splitPlainChapters(text);

    if (chapters.isEmpty) {
      throw BookParseException('没有解析到正文内容');
    }

    return ParsedBook(
      title: _stripExtension(displayName),
      author: '佚名',
      chapters: chapters,
      sourceName: displayName,
    );
  }

  /// 章节标题行：第 X 章 / Chapter N / Prologue 等。
  static final RegExp _chapterHeading = RegExp(
    r'^[ \t　]*(第[0-9０-９零一二三四五六七八九十百千万两]{1,9}[章节回卷部篇][^\n]{0,30}'
    r'|[Cc]hapter\s+[0-9]{1,4}[^\n]{0,30}'
    r'|[Pp]rologue[^\n]{0,30}'
    r'|[Ee]pilogue[^\n]{0,30})[ \t　]*$',
    multiLine: true,
  );

  List<Chapter> _splitPlainChapters(String text) {
    final String content = text.trim();
    if (content.isEmpty) {
      return <Chapter>[];
    }

    final List<RegExpMatch> matches = _chapterHeading.allMatches(content).toList();
    if (matches.length < 2) {
      // 没有章节标记：按长度分块，避免一本书变成一条超长文本。
      return _splitByLength(content, '正文');
    }

    final List<Chapter> chapters = <Chapter>[];

    final String preface = content.substring(0, matches.first.start).trim();
    if (preface.length >= 40) {
      chapters.add(Chapter.fromText('前言', preface));
    }

    for (int index = 0; index < matches.length; index++) {
      final int end =
          index + 1 < matches.length ? matches[index + 1].start : content.length;
      final String body = content.substring(matches[index].end, end).trim();
      final String title = matches[index].group(1)!.trim();
      chapters.add(Chapter.fromText(title, body));
    }

    return chapters;
  }

  List<Chapter> _splitMarkdown(String text) {
    final String content = text.trim();
    if (content.isEmpty) {
      return <Chapter>[];
    }

    final List<RegExpMatch> matches =
        RegExp(r'^#{1,3}[ \t]+(.+)$', multiLine: true).allMatches(content).toList();
    if (matches.length < 2) {
      return _splitPlainChapters(content);
    }

    final List<Chapter> chapters = <Chapter>[];
    for (int index = 0; index < matches.length; index++) {
      final int end =
          index + 1 < matches.length ? matches[index + 1].start : content.length;
      final String rawBody = content.substring(matches[index].end, end);
      final String title = _stripMarkdown(matches[index].group(1)!).trim();
      final String body = _stripMarkdown(rawBody).trim();
      chapters.add(Chapter.fromText(title, body));
    }
    return chapters;
  }

  /// 按固定长度切块，切点尽量落在换行处，保证阅读时排版自然。
  List<Chapter> _splitByLength(
    String text,
    String baseTitle, {
    int chunkSize = 6000,
  }) {
    final String content = text.trim();
    if (content.isEmpty) {
      return <Chapter>[];
    }
    if (content.length <= chunkSize) {
      return <Chapter>[Chapter.fromText(baseTitle, content)];
    }

    final List<Chapter> chapters = <Chapter>[];
    int start = 0;
    int part = 1;

    while (start < content.length) {
      int end = start + chunkSize;
      if (end > content.length) {
        end = content.length;
      }
      if (end < content.length) {
        final int paragraphBreak = content.lastIndexOf('\n', end);
        if (paragraphBreak > start + chunkSize ~/ 2) {
          end = paragraphBreak;
        }
      }

      final String partText = content.substring(start, end).trim();
      if (partText.isNotEmpty) {
        chapters.add(Chapter.fromText('$baseTitle（$part）', partText));
      }
      start = end;
      part++;
    }

    return chapters;
  }

  // ---------------- DOCX ----------------

  Future<ParsedBook> _parseDocxBytes(
    Uint8List bytes,
    String displayName,
  ) async {
    final Archive archive = _decodeZip(bytes);
    final ArchiveFile? document = _findEntry(archive, 'word/document.xml');
    if (document == null) {
      throw BookParseException('DOCX 结构异常：缺少 word/document.xml');
    }

    String xml = _decodeText(_entryBytes(document));
    xml = xml.replaceAll(RegExp(r'</w:p>'), '\n\n');
    xml = xml.replaceAll(RegExp(r'<w:br\s*/?>'), '\n');
    xml = xml.replaceAll(RegExp(r'<w:tab\s*/?>'), '\t');

    String text = xml.replaceAll(RegExp(r'<[^>]+>'), '');
    text = _decodeEntities(text);
    text = text.replaceAll(RegExp(r'[ \t]+\n'), '\n');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    text = text.trim();

    if (text.isEmpty) {
      throw BookParseException('DOCX 中没有解析到正文内容');
    }

    return ParsedBook(
      title: _stripExtension(displayName),
      author: '佚名',
      chapters: _splitPlainChapters(text),
      sourceName: displayName,
    );
  }

  // ---------------- ZIP（多卷） ----------------

  Future<List<ParsedBook>> _parseZipBytes(
    Uint8List bytes,
    String displayName,
  ) async {
    final Archive archive = _decodeZip(bytes);
    final List<ParsedBook> books = <ParsedBook>[];

    for (final ArchiveFile file in archive.files) {
      if (file.name.endsWith('/')) {
        continue;
      }
      final String innerName = p.basename(file.name);
      final String extension =
          p.extension(innerName).replaceFirst('.', '').toLowerCase();
      if (!parseableExtensions.contains(extension) || extension == 'zip') {
        continue;
      }

      final Uint8List innerBytes = _entryBytes(file);
      if (innerBytes.isEmpty) {
        continue;
      }

      try {
        switch (extension) {
          case 'epub':
            books.add(await _parseEpubBytes(innerBytes, innerName));
            break;
          case 'docx':
            books.add(await _parseDocxBytes(innerBytes, innerName));
            break;
          default:
            books.add(await _parseTextBytes(innerBytes, innerName, extension));
        }
      } catch (_) {
        // 压缩包内单个文件坏了不影响其它卷。
        continue;
      }
    }

    if (books.isEmpty) {
      throw BookParseException('压缩包内没有可解析的书籍文件');
    }
    return books;
  }

  // ---------------- 压缩包与编码 ----------------

  Archive _decodeZip(Uint8List bytes) {
    try {
      return ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw BookParseException('压缩包解析失败：文件可能已损坏');
    }
  }

  /// 读取压缩包内文件字节；兼容 archive 3.x / 4.x 的 content 差异。
  Uint8List _entryBytes(ArchiveFile file) {
    try {
      final dynamic content = file.content;
      if (content is Uint8List) {
        return content;
      }
      if (content is List<int>) {
        return Uint8List.fromList(content);
      }
    } catch (_) {
      // 继续尝试 readBytes。
    }

    try {
      final dynamic dynamicFile = file;
      final dynamic read = dynamicFile.readBytes();
      if (read is Uint8List) {
        return read;
      }
      if (read is List<int>) {
        return Uint8List.fromList(read);
      }
    } catch (_) {
      // 忽略，返回空字节由调用方判断。
    }

    return Uint8List(0);
  }

  ArchiveFile? _findEntry(Archive archive, String path) {
    final String normalized = path
        .replaceAll('\\', '/')
        .replaceFirst(RegExp(r'^/+'), '')
        .toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }

    for (final ArchiveFile file in archive.files) {
      final String name = file.name
          .replaceAll('\\', '/')
          .replaceFirst(RegExp(r'^/+'), '')
          .toLowerCase();
      if (name == normalized) {
        return file;
      }
    }

    // 兜底：忽略目录前缀，只比对文件名（部分 EPUB 的 OPF 路径不规范）。
    final String baseName = p.basename(normalized);
    for (final ArchiveFile file in archive.files) {
      final String name = file.name.replaceAll('\\', '/').toLowerCase();
      if (name == baseName || name.endsWith('/$baseName')) {
        return file;
      }
    }
    return null;
  }

  /// 解码文本：优先 BOM，其次严格 UTF-8，最后 latin1 兜底。
  ///
  /// 注意：GBK 编码的 TXT 会被兜底成乱码——中文轻小说以 UTF-8 为主，
  /// 遇到乱码时界面提示用户转码后重新导入，而不是让程序崩溃。
  String _decodeText(Uint8List bytes) {
    if (bytes.isEmpty) {
      return '';
    }

    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return utf8.decode(bytes.sublist(3), allowMalformed: true);
    }
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return _decodeUtf16(bytes.sublist(2), littleEndian: true);
    }
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return _decodeUtf16(bytes.sublist(2), littleEndian: false);
    }

    try {
      return utf8.decode(bytes);
    } on FormatException {
      return latin1.decode(bytes);
    }
  }

  String _decodeUtf16(Uint8List bytes, {required bool littleEndian}) {
    final StringBuffer buffer = StringBuffer();
    for (int index = 0; index + 1 < bytes.length; index += 2) {
      final int codeUnit = littleEndian
          ? bytes[index] | (bytes[index + 1] << 8)
          : (bytes[index] << 8) | bytes[index + 1];
      buffer.writeCharCode(codeUnit);
    }
    return buffer.toString();
  }

  // ---------------- 文本清洗 ----------------

  String _htmlToText(String html) {
    String text = html;
    text = text.replaceAll(
      RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false),
      '',
    );
    text = text.replaceAll(
      RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false),
      '',
    );
    text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    text = text.replaceAll(
      RegExp(r'</(p|div|h[1-6]|li|tr|section)>', caseSensitive: false),
      '\n',
    );
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');
    text = _decodeEntities(text);

    final List<String> lines = text.split('\n').map((String line) {
      return line.replaceAll(RegExp(r'[ \t\u00A0]+'), ' ').trim();
    }).toList();

    final StringBuffer buffer = StringBuffer();
    int emptyRun = 0;
    for (final String line in lines) {
      if (line.isEmpty) {
        emptyRun++;
        if (emptyRun > 1) {
          continue;
        }
      } else {
        emptyRun = 0;
      }
      if (buffer.isNotEmpty) {
        buffer.write('\n');
      }
      buffer.write(line);
    }

    return buffer.toString().trim();
  }

  String? _htmlHeading(String html) {
    final RegExpMatch? match = RegExp(
      r'<h[1-3][^>]*>([\s\S]*?)</h[1-3]>',
      caseSensitive: false,
    ).firstMatch(html);
    if (match == null) {
      return null;
    }
    final String text =
        _decodeEntities(match.group(1)!.replaceAll(RegExp(r'<[^>]+>'), ''))
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
    return text.isEmpty ? null : text;
  }

  String _stripMarkdown(String text) {
    String result = text;
    result = result.replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), '');
    result = result.replaceAllMapped(
      RegExp(r'\[([^\]]*)\]\([^)]*\)'),
      (Match match) => match.group(1) ?? '',
    );
    result = result.replaceAll(RegExp(r'^\s*>\s?', multiLine: true), '');
    result = result.replaceAll(RegExp(r'[*_`~]{1,3}'), '');
    return result;
  }

  String _decodeEntities(String text) {
    String result = text;
    const Map<String, String> namedEntities = <String, String>{
      '&nbsp;': ' ',
      '&amp;': '&',
      '&lt;': '<',
      '&gt;': '>',
      '&quot;': '"',
      '&apos;': "'",
      '&ldquo;': '“',
      '&rdquo;': '”',
      '&mdash;': '—',
      '&hellip;': '…',
    };
    namedEntities.forEach((String entity, String value) {
      result = result.replaceAll(entity, value);
    });

    result = result.replaceAllMapped(RegExp(r'&#(\d{1,7});'), (Match match) {
      final int? code = int.tryParse(match.group(1)!);
      if (code == null) {
        return match.group(0)!;
      }
      return String.fromCharCode(code);
    });

    result = result.replaceAllMapped(
      RegExp(r'&#[xX]([0-9a-fA-F]{1,6});'),
      (Match match) {
        final int? code = int.tryParse(match.group(1)!, radix: 16);
        if (code == null) {
          return match.group(0)!;
        }
        return String.fromCharCode(code);
      },
    );

    return result;
  }

  String? _firstTagText(String xml, String tag) {
    final RegExp pattern = RegExp(
      '<$tag\\b[^>]*>([\\s\\S]*?)</$tag>',
      caseSensitive: false,
    );
    final RegExpMatch? match = pattern.firstMatch(xml);
    if (match == null) {
      return null;
    }
    final String text = _decodeEntities(
      match.group(1)!.replaceAll(RegExp(r'<[^>]+>'), ''),
    ).trim();
    return text.isEmpty ? null : text;
  }

  String? _attribute(String tag, String name) {
    final RegExpMatch? match =
        RegExp('$name\\s*=\\s*"([^"]*)"', caseSensitive: false).firstMatch(tag) ??
            RegExp("$name\\s*=\\s*'([^']*)'", caseSensitive: false)
                .firstMatch(tag);
    return match?.group(1);
  }

  String _directoryOf(String path) {
    final int index = path.lastIndexOf('/');
    if (index <= 0) {
      return '';
    }
    return path.substring(0, index);
  }

  /// 把 OPF 内的相对 href 解析为压缩包内绝对路径（处理 `../`）。
  String _resolvePath(String baseDirectory, String relative) {
    String target = relative.replaceAll('\\', '/');
    try {
      target = Uri.decodeFull(target);
    } catch (_) {
      // 非法转义保持原样。
    }

    final List<String> segments = <String>[];
    if (baseDirectory.isNotEmpty) {
      segments.addAll(baseDirectory.split('/').where((String item) => item.isNotEmpty));
    }
    for (final String segment in target.split('/')) {
      if (segment.isEmpty || segment == '.') {
        continue;
      }
      if (segment == '..') {
        if (segments.isNotEmpty) {
          segments.removeLast();
        }
        continue;
      }
      segments.add(segment);
    }
    return segments.join('/');
  }

  String _stripBom(String text) {
    if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) {
      return text.substring(1);
    }
    return text;
  }

  String _stripExtension(String fileName) {
    final String name = p.basenameWithoutExtension(fileName).trim();
    return name.isEmpty ? '未命名书籍' : name;
  }
}

/// OPF manifest 中的一条记录。
class _ManifestItem {
  const _ManifestItem({
    required this.href,
    required this.mediaType,
    required this.properties,
  });

  final String href;
  final String mediaType;
  final String properties;
}
