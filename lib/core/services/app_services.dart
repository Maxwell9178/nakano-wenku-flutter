import 'package:flutter/foundation.dart';

import '../settings/app_settings.dart';
import 'account_data_service.dart';
import 'backup_import_service.dart';
import 'book_import_service.dart';
import 'book_repository.dart';
import 'chapter_repository.dart';
import 'custom_font_service.dart';
import 'excerpt_repository.dart';
import 'import_site_repository.dart';
import 'local_file_scanner.dart';
import 'local_storage_service.dart';
import 'quote_repository.dart';
import 'reading_preferences_repository.dart';
import 'reading_stats_repository.dart';
import 'update_service.dart';
import 'user_profile_controller.dart';
import 'wkarchive_service.dart';

/// 应用级服务容器。
///
/// 目的：把「一次性初始化」的服务集中到入口处创建，页面通过 Provider
/// 取用，避免各页面重复 new，也避免业务层直接依赖具体实现。
///
/// 注意：这里只承载基础服务，书籍、阅读进度等后续模块请新增独立控制器，
/// 不要把所有状态堆进同一个类。
class AppServices {
  AppServices._();

  static final AppServices instance = AppServices._();

  bool _ready = false;

  late final LocalStorageService storage;
  late final AppSettingsController settings;
  late final UserProfileController profile;
  late final BackupImportService backup;

  /// 书籍数据仓库：书架、详情、导入、阅读页共用同一实例。
  late final BookRepository books;

  /// 章节正文与封面文件读写。
  late final ChapterRepository chapters;

  /// 导入页网站快捷球球的本地仓库。
  late final ImportSiteRepository importSites;

  /// 本机文件扫描（只读，不申请额外权限）。
  late final LocalFileScanner fileScanner;

  /// 导入编排（解析 → 分组 → 落盘）。
  late final BookImportService importService;

  /// 阅读偏好（排版 / 操作）与背景图库。
  late final ReadingPreferencesRepository readingPreferences;

  /// 摘抄库。
  late final ExcerptRepository excerpts;

  /// 名言名句（随包 assets，只读）。
  late final QuoteRepository quotes;

  /// 阅读时长与打卡统计。
  late final ReadingStatsRepository readingStats;

  /// 删除账号：一次性清空账号资料与全部本地数据。
  late final AccountDataService accountData;

  /// `.wkarchive` 数据包导出 / 导入。
  late final WkArchiveService wkArchive;

  /// 第三方字体包的导入与运行时注册。
  late final CustomFontService customFonts;

  /// 版本更新检测（唯一允许发起网络请求的服务）。
  late final UpdateService update;

  bool get isReady => _ready;

  /// 应用启动时调用一次，完成本地存储与全局状态的初始化。
  Future<void> bootstrap() async {
    if (_ready) {
      return;
    }

    storage = await LocalStorageService.create();
    settings = AppSettingsController(storage)..load();
    profile = UserProfileController(storage)..load();
    backup = const BackupImportService();
    books = BookRepository(storage);
    chapters = ChapterRepository();
    importSites = ImportSiteRepository(storage);
    fileScanner = LocalFileScanner();
    importService = BookImportService(books: books, chapters: chapters);
    readingPreferences = ReadingPreferencesRepository(storage);
    excerpts = ExcerptRepository(storage);
    quotes = QuoteRepository();
    readingStats = ReadingStatsRepository(storage)..load();
    accountData = AccountDataService(
      storage: storage,
      books: books,
      chapters: chapters,
      profile: profile,
      settings: settings,
      stats: readingStats,
      excerpts: excerpts,
      readingPreferences: readingPreferences,
    );
    wkArchive = WkArchiveService(
      books: books,
      chapters: chapters,
      readingPreferences: readingPreferences,
      excerpts: excerpts,
      stats: readingStats,
      importSites: importSites,
      profile: profile,
      settings: settings,
      storage: storage,
    );
    customFonts = CustomFontService(storage);
    // 上次导入的第三方字体需要在启动阶段重新注册（注册不跨进程保留）。
    await customFonts.restoreSavedFont();

    update = UpdateService(storage);

    _ready = true;

    if (kDebugMode) {
      debugPrint(
        '[NakanoWenku] services ready · onboardingCompleted='
        '${profile.onboardingCompleted} · themeMode=${settings.themeMode}',
      );
    }
  }
}
