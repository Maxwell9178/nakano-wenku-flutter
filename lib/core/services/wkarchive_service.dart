import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../constants/app_constants.dart';
import '../constants/storage_keys.dart';
import '../models/book.dart';
import '../models/chapter.dart';
import '../models/excerpt.dart';
import '../models/import_site.dart';
import '../models/reading_preferences.dart';
import '../settings/app_settings.dart';
import '../sync/appwrite_sync.dart';
import 'book_repository.dart';
import 'chapter_repository.dart';
import 'excerpt_repository.dart';
import 'import_site_repository.dart';
import 'local_storage_service.dart';
import 'reading_preferences_repository.dart';
import 'reading_stats_repository.dart';
import 'user_profile_controller.dart';

/// 数据包（.wkarchive）相关异常，message 可以直接展示给用户。
class WkArchiveException implements Exception {
  const WkArchiveException(this.message);

  final String message;

  @override
  String toString() => 'WkArchiveException: $message';
}

/// 备份包内一本书的封面字节。
class WkArchiveCover {
  const WkArchiveCover({required this.bytes, required this.extension});

  final Uint8List bytes;
  final String extension;
}

/// 解析完成、尚未落盘的备份包内容。
class WkArchivePayload {
  const WkArchivePayload({
    required this.userName,
    required this.createdAt,
    required this.avatarBytes,
    required this.books,
    required this.chapters,
    required this.covers,
    required this.excerpts,
    required this.preferences,
    required this.dailySeconds,
    required this.totalSeconds,
    required this.importSites,
    required this.themeModeName,
    required this.glassBlur,
    required this.glassOpacity,
    required this.glassBorderName,
    required this.includeBooks,
    required this.exportedAt,
  });

  final String userName;
  final DateTime? createdAt;
  final Uint8List? avatarBytes;
  final List<Book> books;
  final Map<int, List<Chapter>> chapters;
  final Map<int, WkArchiveCover> covers;
  final List<Excerpt> excerpts;
  final ReadingPreferences preferences;
  final Map<String, int> dailySeconds;
  final int totalSeconds;
  final List<ImportSite> importSites;
  final String? themeModeName;
  final int? glassBlur;
  final int? glassOpacity;
  final String? glassBorderName;
  final bool includeBooks;
  final DateTime? exportedAt;

  bool get hasAvatar => avatarBytes != null && avatarBytes!.isNotEmpty;

  int get bookCount => books.length;
}

/// 导出结果。
class WkArchiveExportResult {
  const WkArchiveExportResult({
    required this.fileName,
    required this.sizeInBytes,
    required this.bookCount,
    required this.includeBooks,
  });

  final String fileName;
  final int sizeInBytes;
  final int bookCount;
  final bool includeBooks;

  String get sizeLabel {
    if (sizeInBytes >= 1024 * 1024) {
      return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
  }
}

/// 落盘结果（导入后用于提示）。
class WkArchiveApplyResult {
  const WkArchiveApplyResult({
    required this.bookCount,
    required this.overwrite,
    required this.hasAvatar,
  });

  final int bookCount;
  final bool overwrite;
  final bool hasAvatar;
}

/// `.wkarchive` 数据包的导出与导入。
///
/// 数据包本质是把 zip 改后缀：
/// ```
/// info.json                       # 账号、设置、书籍元数据、摘抄、统计、偏好
/// avatar.png                      # 头像原图（原样复制）
/// books/NW-0001/chapters.json     # 可选：章节正文
/// books/NW-0001/cover.jpg         # 可选：书籍封面
/// ```
/// 全程离线，不发起任何网络请求。
class WkArchiveService {
  const WkArchiveService({
    required BookRepository books,
    required ChapterRepository chapters,
    required ReadingPreferencesRepository readingPreferences,
    required ExcerptRepository excerpts,
    required ReadingStatsRepository stats,
    required ImportSiteRepository importSites,
    required UserProfileController profile,
    required AppSettingsController settings,
    required LocalStorageService storage,
  })  : _books = books,
        _chapters = chapters,
        _readingPreferences = readingPreferences,
        _excerpts = excerpts,
        _stats = stats,
        _importSites = importSites,
        _profile = profile,
        _settings = settings,
        _storage = storage;

  final BookRepository _books;
  final ChapterRepository _chapters;
  final ReadingPreferencesRepository _readingPreferences;
  final ExcerptRepository _excerpts;
  final ReadingStatsRepository _stats;
  final ImportSiteRepository _importSites;
  final UserProfileController _profile;
  final AppSettingsController _settings;
  final LocalStorageService _storage;

  static const String fileExtension = 'wkarchive';
  static const String infoFileName = 'info.json';
  static const String avatarFileName = 'avatar.png';
  static const String formatTag = 'nwakarchive';
  static const int formatVersion = 1;

  /// 带书籍导出时的总上限：512MB（需求硬性约束）。
  static const int maxArchiveBytes = 512 * 1024 * 1024;

  // ------------------------------------------------------------ 导出

  /// 导出备份包，并唤起系统「保存位置」选择器。
  ///
  /// [includeBooks] 为 false 时只导出基础数据；
  /// [selectedNumbers] 非空时只导出这些编号的书籍文件（基础数据里仍保留
  /// 全部书籍记录，方便恢复后重新导入文件）。
  ///
  /// 返回 null 表示用户在保存弹窗里取消。
  Future<WkArchiveExportResult?> exportArchive({
    required bool includeBooks,
    Set<int>? selectedNumbers,
  }) async {
    final List<Book> allBooks = _books.loadAll();
    final List<Book> fileBooks = selectedNumbers == null
        ? allBooks
        : allBooks
            .where((Book book) => selectedNumbers.contains(book.number))
            .toList(growable: false);

    // 先算体积：目录只有元数据，体积主要来自章节 JSON 与封面。
    int estimatedBytes = 0;
    final Map<int, Uint8List> chapterPayloads = <int, Uint8List>{};
    final Map<int, File> coverFiles = <int, File>{};

    if (includeBooks) {
      for (final Book book in fileBooks) {
        final List<Chapter> chapters = await _chapters.load(book.number);
        final Uint8List bytes = Uint8List.fromList(
          utf8.encode(
            jsonEncode(
              chapters.map((Chapter item) => item.toJson()).toList(),
            ),
          ),
        );
        chapterPayloads[book.number] = bytes;
        estimatedBytes += bytes.length;

        final String? coverPath = book.coverPath;
        if (coverPath != null && coverPath.isNotEmpty) {
          final File cover = File(coverPath);
          if (await cover.exists()) {
            coverFiles[book.number] = cover;
            estimatedBytes += await cover.length();
          }
        }

        if (estimatedBytes > maxArchiveBytes) {
          throw const WkArchiveException('所选书籍超过 512MB 上限，请减少选中的书籍');
        }
      }
    }

    final Map<String, dynamic> info = _buildInfo(
      allBooks: allBooks,
      includeBooks: includeBooks,
      fileBookNumbers: includeBooks
          ? fileBooks.map((Book book) => book.number).toList()
          : const <int>[],
    );

    final Archive archive = Archive();
    final List<int> infoBytes = utf8.encode(jsonEncode(info));
    archive.addFile(
      ArchiveFile(infoFileName, infoBytes.length, infoBytes),
    );

    final String? avatarPath = _profile.avatarPath;
    if (avatarPath != null && avatarPath.isNotEmpty) {
      final File avatar = File(avatarPath);
      if (await avatar.exists()) {
        final Uint8List bytes = await avatar.readAsBytes();
        archive.addFile(
          ArchiveFile(avatarFileName, bytes.length, bytes),
        );
      }
    }

    if (includeBooks) {
      chapterPayloads.forEach((int number, Uint8List bytes) {
        final String id = AppConstants.formatBookId(number);
        archive.addFile(
          ArchiveFile('books/$id/chapters.json', bytes.length, bytes),
        );
      });
      for (final MapEntry<int, File> entry in coverFiles.entries) {
        final String id = AppConstants.formatBookId(entry.key);
        final String ext = _normalizedImageExtension(
          p.extension(entry.value.path),
        );
        final Uint8List bytes = await entry.value.readAsBytes();
        archive.addFile(
          ArchiveFile('books/$id/cover$ext', bytes.length, bytes),
        );
      }
    }

    final List<int>? encoded = ZipEncoder().encode(archive);
    if (encoded == null) {
      throw const WkArchiveException('打包失败，请稍后重试');
    }

    final Uint8List zipBytes = Uint8List.fromList(encoded);
    if (zipBytes.length > maxArchiveBytes) {
      throw const WkArchiveException('备份包超过 512MB 上限，请减少选中的书籍');
    }

    final String fileName = _defaultFileName();
    final String? savedPath;
    try {
      savedPath = await FilePicker.platform.saveFile(
        dialogTitle: '保存数据包',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: <String>[fileExtension],
        bytes: zipBytes,
      );
    } catch (_) {
      throw const WkArchiveException('无法打开系统保存位置，请检查存储权限');
    }

    if (savedPath == null) {
      return null;
    }

    // 部分平台不会写入字节，这里再兜底写一次（已存在则覆盖）。
    try {
      final File target = File(savedPath);
      if (!await target.exists() || await target.length() != zipBytes.length) {
        await target.writeAsBytes(zipBytes, flush: true);
      }
    } catch (_) {
      // 系统已经写入成功时忽略，避免误报失败。
    }

    return WkArchiveExportResult(
      fileName: fileName,
      sizeInBytes: zipBytes.length,
      bookCount: includeBooks ? fileBooks.length : allBooks.length,
      includeBooks: includeBooks,
    );
  }

  Map<String, dynamic> _buildInfo({
    required List<Book> allBooks,
    required bool includeBooks,
    required List<int> fileBookNumbers,
  }) {
    final int finished = allBooks.where((Book book) => book.isFinished).length;

    return <String, dynamic>{
      'format': formatTag,
      'formatVersion': formatVersion,
      'exportedAt': DateTime.now().millisecondsSinceEpoch,
      'includeBooks': includeBooks,
      'bookFiles': fileBookNumbers,
      'app': <String, dynamic>{
        'name': AppConstants.appName,
        'versionName': AppConstants.versionName,
        'versionCode': AppConstants.versionCode,
      },
      'account': <String, dynamic>{
        'userName': _profile.userName,
        'createdAt': _profile.createdAt?.millisecondsSinceEpoch,
      },
      'settings': <String, dynamic>{
        'themeMode': _settings.themeMode.name,
        'glassBlur': _settings.glassBlur,
        'glassOpacity': _settings.glassOpacity,
        'glassBorder': _settings.glassBorder.name,
        'readingFontMode':
            _storage.getString(StorageKeys.readingFontMode) ?? 'system',
      },
      'books': allBooks.map((Book book) => book.toJson()).toList(),
      // 顶层汇总一份标签，方便恢复时快速还原筛选栏；书籍自身仍保留各自标签。
      'tags': SyncSnapshotBuilder.collectTags(allBooks),
      'counts': <String, dynamic>{
        'total': allBooks.length,
        'finished': finished,
        'unfinished': allBooks.length - finished,
      },
      'readingPreferences': _readingPreferences.load().toJson(),
      'excerpts':
          _excerpts.loadAll().map((Excerpt item) => item.toJson()).toList(),
      'readingStats': <String, dynamic>{
        'dailySeconds': _stats.dailySeconds,
        'totalSeconds': _stats.totalSeconds,
      },
      'importSites':
          _importSites.load().map((ImportSite item) => item.toJson()).toList(),
    };
  }

  String _defaultFileName() {
    final DateTime now = DateTime.now();
    final String stamp = '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    return 'NakanoWenku_$stamp.$fileExtension';
  }

  // ------------------------------------------------------------ 导入

  /// 选择备份文件并解析，取消返回 null。
  Future<WkArchivePayload?> pickAndRead() async {
    FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: <String>[fileExtension],
        allowMultiple: false,
        withData: true,
      );
    } catch (_) {
      throw const WkArchiveException('无法打开文件选择器，请检查存储权限');
    }

    if (picked == null || picked.files.isEmpty) {
      return null;
    }

    final PlatformFile file = picked.files.first;
    Uint8List? bytes = file.bytes;
    if (bytes == null) {
      final String? path = file.path;
      if (path == null || path.isEmpty) {
        throw const WkArchiveException('无法读取所选文件');
      }
      bytes = await File(path).readAsBytes();
    }
    return parseArchive(bytes);
  }

  /// 解析备份包字节。
  Future<WkArchivePayload> parseArchive(Uint8List bytes) async {
    if (bytes.isEmpty) {
      throw const WkArchiveException('备份包为空，无法导入');
    }

    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: true);
    } catch (_) {
      throw const WkArchiveException('这不是有效的 .wkarchive 数据包');
    }

    final ArchiveFile? infoEntry = _findEntry(archive, infoFileName);
    if (infoEntry == null) {
      throw const WkArchiveException('备份包缺少 info.json');
    }

    Map<String, dynamic> info;
    try {
      final dynamic decoded = jsonDecode(
        utf8.decode(_readBytes(infoEntry), allowMalformed: true),
      );
      if (decoded is! Map) {
        throw const FormatException('info.json 结构异常');
      }
      info = Map<String, dynamic>.from(decoded);
    } catch (_) {
      throw const WkArchiveException('info.json 解析失败，备份包可能已损坏');
    }

    // 书籍元数据
    final List<Book> books = <Book>[];
    final dynamic rawBooks = info['books'];
    if (rawBooks is List) {
      for (final dynamic item in rawBooks) {
        if (item is Map) {
          try {
            books.add(Book.fromJson(Map<String, dynamic>.from(item)));
          } catch (_) {
            // 单本坏数据跳过，不影响其它书。
          }
        }
      }
    }
    books.sort((Book a, Book b) => a.number.compareTo(b.number));

    // 章节与封面
    final Map<int, List<Chapter>> chapters = <int, List<Chapter>>{};
    final Map<int, WkArchiveCover> covers = <int, WkArchiveCover>{};
    for (final Book book in books) {
      final String id = AppConstants.formatBookId(book.number);
      final ArchiveFile? chapterEntry =
          _findEntry(archive, 'books/$id/chapters.json') ??
              _findEntry(archive, 'chapters.json', folderHint: id);
      if (chapterEntry != null) {
        chapters[book.number] = _parseChapters(chapterEntry);
      }

      final ArchiveFile? coverEntry = _findCoverEntry(archive, id);
      if (coverEntry != null) {
        covers[book.number] = WkArchiveCover(
          bytes: _readBytes(coverEntry),
          extension: _normalizedImageExtension(p.extension(coverEntry.name)),
        );
      }
    }

    // 头像：缺失时使用默认空白头像，绝不报错。
    Uint8List? avatarBytes;
    final ArchiveFile? avatarEntry = _findEntry(archive, avatarFileName);
    if (avatarEntry != null && avatarEntry.size > 0) {
      avatarBytes = _readBytes(avatarEntry);
    }

    final Map<String, dynamic> account = _asMap(info['account']);
    final Map<String, dynamic> settings = _asMap(info['settings']);
    final Map<String, dynamic> stats = _asMap(info['readingStats']);
    final bool includeBooks =
        info['includeBooks'] == true || chapters.isNotEmpty;

    return WkArchivePayload(
      userName: _asString(account['userName']) ?? '未命名书友',
      createdAt: _asDateTime(account['createdAt']),
      avatarBytes: avatarBytes,
      books: books,
      chapters: chapters,
      covers: covers,
      excerpts: _parseExcerpts(info['excerpts']),
      preferences: _parsePreferences(info['readingPreferences']),
      dailySeconds: _asIntMap(stats['dailySeconds']),
      totalSeconds: _asInt(stats['totalSeconds']) ?? 0,
      importSites: _parseSites(info['importSites']),
      themeModeName: _asString(settings['themeMode']),
      glassBlur: _asInt(settings['glassBlur']),
      glassOpacity: _asInt(settings['glassOpacity']),
      glassBorderName: _asString(settings['glassBorder']),
      includeBooks: includeBooks,
      exportedAt: _asDateTime(info['exportedAt']),
    );
  }

  /// 把备份包写入本地。
  ///
  /// [overwrite] 为 true：清空现有书籍与章节后整体替换；
  /// 为 false：保留现有数据，书籍编号冲突时自动分配新编号。
  Future<WkArchiveApplyResult> apply(
    WkArchivePayload payload, {
    required bool overwrite,
  }) async {
    if (overwrite) {
      await _applyOverwrite(payload);
      return WkArchiveApplyResult(
        bookCount: payload.books.length,
        overwrite: true,
        hasAvatar: payload.hasAvatar,
      );
    }

    final int added = await _applyMerge(payload);
    return WkArchiveApplyResult(
      bookCount: added,
      overwrite: false,
      hasAvatar: payload.hasAvatar,
    );
  }

  Future<void> _applyOverwrite(WkArchivePayload payload) async {
    // 1. 清空现有书籍文件与记录
    for (final Book book in _books.loadAll()) {
      try {
        await _chapters.delete(book.number);
        await _chapters.deleteCover(book.coverPath);
      } catch (_) {
        // 单个文件删除失败不阻断整体覆盖。
      }
    }

    // 2. 写入书籍元数据
    await _books.saveAll(payload.books);

    // 3. 写入章节与封面
    for (final Book book in payload.books) {
      final List<Chapter>? chapters = payload.chapters[book.number];
      if (chapters != null && chapters.isNotEmpty) {
        await _chapters.save(book.number, chapters);
      }
      final WkArchiveCover? cover = payload.covers[book.number];
      if (cover != null) {
        await _chapters.saveCoverBytes(
          book.number,
          cover.bytes,
          cover.extension,
        );
      }
    }

    // 4. 摘抄 / 偏好 / 统计 / 快捷站点
    await _excerpts.saveAll(payload.excerpts);
    await _readingPreferences.save(payload.preferences);
    await _stats.replaceAll(
      dailySeconds: payload.dailySeconds,
      totalSeconds: payload.totalSeconds,
    );
    if (payload.importSites.isNotEmpty) {
      await _importSites.save(payload.importSites);
    }

    // 5. 外观设置
    await _applySettings(payload);

    // 6. 账号资料（头像缺失时回落到默认空白头像）
    await _profile.applyImportedAccount(
      userName: payload.userName,
      avatarBytes: payload.avatarBytes,
      createdAt: payload.createdAt,
    );
  }

  Future<int> _applyMerge(WkArchivePayload payload) async {
    final List<Book> existing = _books.loadAll();
    final Set<int> usedNumbers =
        existing.map((Book book) => book.number).toSet();
    final Set<String> existingTitles =
        existing.map((Book book) => '${book.title}|${book.author}').toSet();

    int cursor = _books.nextNumber(existing);
    int added = 0;

    for (final Book source in payload.books) {
      final String signature = '${source.title}|${source.author}';
      if (existingTitles.contains(signature)) {
        // 同名同作者视为同一本，合并模式不重复入库。
        continue;
      }

      int number = source.number;
      if (usedNumbers.contains(number)) {
        while (usedNumbers.contains(cursor)) {
          cursor = cursor >= AppConstants.bookIdMax
              ? AppConstants.bookIdMin
              : cursor + 1;
        }
        number = cursor;
      }

      final Book target = source.copyWith(number: number);
      existing.add(target);
      usedNumbers.add(number);
      existingTitles.add(signature);
      added++;

      final List<Chapter>? chapters = payload.chapters[source.number];
      if (chapters != null && chapters.isNotEmpty) {
        await _chapters.save(number, chapters);
      }
      final WkArchiveCover? cover = payload.covers[source.number];
      if (cover != null) {
        await _chapters.saveCoverBytes(number, cover.bytes, cover.extension);
      }
    }

    existing.sort((Book a, Book b) => a.number.compareTo(b.number));
    await _books.saveAll(existing);

    // 摘抄：按「书名 + 正文」去重后合并。
    final List<Excerpt> mergedExcerpts = _excerpts.loadAll();
    final Set<String> seen = mergedExcerpts
        .map((Excerpt item) => '${item.bookTitle}|${item.text}')
        .toSet();
    bool excerptChanged = false;
    for (final Excerpt item in payload.excerpts) {
      if (seen.add('${item.bookTitle}|${item.text}')) {
        mergedExcerpts.add(item);
        excerptChanged = true;
      }
    }
    if (excerptChanged) {
      mergedExcerpts.sort(
        (Excerpt a, Excerpt b) => b.createdAt.compareTo(a.createdAt),
      );
      await _excerpts.saveAll(mergedExcerpts);
    }

    // 阅读统计：同一日期取较大值，总时长直接相加。
    await _stats.mergeFrom(
      dailySeconds: payload.dailySeconds,
      totalSeconds: payload.totalSeconds,
    );

    // 快捷站点：按网址合并。
    if (payload.importSites.isNotEmpty) {
      final List<ImportSite> sites = _importSites.load();
      final Set<String> urls = sites.map((ImportSite item) => item.url).toSet();
      bool changed = false;
      for (final ImportSite site in payload.importSites) {
        if (urls.add(site.url)) {
          sites.add(site);
          changed = true;
        }
      }
      if (changed) {
        await _importSites.save(sites);
      }
    }

    // 本地还没有完成初始化时，用备份里的账号资料补位。
    if (!_profile.onboardingCompleted) {
      await _profile.applyImportedAccount(
        userName: payload.userName,
        avatarBytes: payload.avatarBytes,
        createdAt: payload.createdAt,
      );
    }

    return added;
  }

  Future<void> _applySettings(WkArchivePayload payload) async {
    final String? mode = payload.themeModeName;
    if (mode == 'light') {
      await _settings.setThemeMode(ThemeMode.light);
    } else if (mode == 'dark') {
      await _settings.setThemeMode(ThemeMode.dark);
    } else if (mode == 'system') {
      await _settings.setThemeMode(ThemeMode.system);
    }

    final int? blur = payload.glassBlur;
    if (blur != null) {
      await _settings.setGlassBlur(blur);
    }
    final int? opacity = payload.glassOpacity;
    if (opacity != null) {
      await _settings.setGlassOpacity(opacity);
    }
    final String? border = payload.glassBorderName;
    if (border != null) {
      await _settings.setGlassBorder(glassBorderLevelFromStorage(border));
    }
  }

  // ------------------------------------------------------------ 解析辅助

  List<Chapter> _parseChapters(ArchiveFile entry) {
    try {
      final dynamic decoded = jsonDecode(
        utf8.decode(_readBytes(entry), allowMalformed: true),
      );
      if (decoded is! List) {
        return <Chapter>[];
      }
      final List<Chapter> chapters = <Chapter>[];
      for (final dynamic item in decoded) {
        if (item is Map) {
          chapters.add(Chapter.fromJson(Map<String, dynamic>.from(item)));
        }
      }
      return chapters;
    } catch (_) {
      return <Chapter>[];
    }
  }

  List<Excerpt> _parseExcerpts(dynamic raw) {
    if (raw is! List) {
      return <Excerpt>[];
    }
    final List<Excerpt> list = <Excerpt>[];
    for (final dynamic item in raw) {
      if (item is Map) {
        try {
          list.add(Excerpt.fromJson(Map<String, dynamic>.from(item)));
        } catch (_) {
          // 单条摘抄损坏时跳过。
        }
      }
    }
    return list;
  }

  ReadingPreferences _parsePreferences(dynamic raw) {
    if (raw is Map) {
      try {
        return ReadingPreferences.fromJson(Map<String, dynamic>.from(raw));
      } catch (_) {
        // 落到默认偏好。
      }
    }
    return const ReadingPreferences();
  }

  List<ImportSite> _parseSites(dynamic raw) {
    if (raw is! List) {
      return <ImportSite>[];
    }
    final List<ImportSite> list = <ImportSite>[];
    for (final dynamic item in raw) {
      if (item is Map) {
        try {
          list.add(ImportSite.fromJson(Map<String, dynamic>.from(item)));
        } catch (_) {
          // 单个站点损坏时跳过。
        }
      }
    }
    return list;
  }

  ArchiveFile? _findEntry(
    Archive archive,
    String name, {
    String? folderHint,
  }) {
    final String target = name.toLowerCase();
    for (final ArchiveFile file in archive.files) {
      if (file.isFile != true) {
        continue;
      }
      final String lower = file.name.toLowerCase();
      if (folderHint != null) {
        if (lower.endsWith('/$target') &&
            lower.contains(folderHint.toLowerCase())) {
          return file;
        }
        continue;
      }
      if (lower == target || lower.endsWith('/$target')) {
        return file;
      }
    }
    return null;
  }

  ArchiveFile? _findCoverEntry(Archive archive, String bookId) {
    final String prefix = 'books/${bookId.toLowerCase()}/cover';
    for (final ArchiveFile file in archive.files) {
      if (file.isFile != true) {
        continue;
      }
      if (file.name.toLowerCase().startsWith(prefix)) {
        return file;
      }
    }
    return null;
  }

  Uint8List _readBytes(ArchiveFile file) {
    final dynamic content = file.content;
    if (content is Uint8List) {
      return content;
    }
    if (content is List<int>) {
      return Uint8List.fromList(content);
    }
    return Uint8List(0);
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  Map<String, int> _asIntMap(dynamic value) {
    if (value is! Map) {
      return <String, int>{};
    }
    final Map<String, int> result = <String, int>{};
    value.forEach((dynamic key, dynamic item) {
      if (key is String && item is num) {
        result[key] = item.toInt();
      }
    });
    return result;
  }

  static String? _asString(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  static int? _asInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static String _normalizedImageExtension(String extension) {
    final String lower = extension.toLowerCase();
    if (lower == '.jpg' ||
        lower == '.jpeg' ||
        lower == '.png' ||
        lower == '.webp') {
      return lower;
    }
    return '.png';
  }
}
