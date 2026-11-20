import 'dart:io';

import '../constants/storage_keys.dart';
import '../models/book.dart';
import '../settings/app_settings.dart';
import 'book_repository.dart';
import 'chapter_repository.dart';
import 'excerpt_repository.dart';
import 'local_storage_service.dart';
import 'reading_preferences_repository.dart';
import 'reading_stats_repository.dart';
import 'user_profile_controller.dart';

/// 删除账号：把这部份「只属于当前账号」的本地数据全部清干净。
///
/// 清理顺序刻意先删文件、再删记录：
/// 1. 章节正文与封面文件（按书籍编号）；
/// 2. 书籍记录；
/// 3. 摘抄、阅读偏好、自定义背景图、阅读统计；
/// 4. 账号资料（头像文件 + 昵称等键）；
/// 5. 全局外观设置复位。
///
/// 任意一步失败都不抛出：删除账号的目标是「尽可能清干净」，
/// 局部异常不应该把用户卡在确认弹窗里。
class AccountDataService {
  const AccountDataService({
    required LocalStorageService storage,
    required BookRepository books,
    required ChapterRepository chapters,
    required UserProfileController profile,
    required AppSettingsController settings,
    required ReadingStatsRepository stats,
    required ExcerptRepository excerpts,
    required ReadingPreferencesRepository readingPreferences,
  })  : _storage = storage,
        _books = books,
        _chapters = chapters,
        _profile = profile,
        _settings = settings,
        _stats = stats,
        _excerpts = excerpts,
        _readingPreferences = readingPreferences;

  final LocalStorageService _storage;
  final BookRepository _books;
  final ChapterRepository _chapters;
  final UserProfileController _profile;
  final AppSettingsController _settings;
  final ReadingStatsRepository _stats;
  final ExcerptRepository _excerpts;
  final ReadingPreferencesRepository _readingPreferences;

  /// 执行删除，返回是否全部顺利。
  Future<bool> deleteAccount() async {
    bool ok = true;

    for (final Book book in _books.loadAll()) {
      try {
        await _chapters.delete(book.number);
        await _chapters.deleteCover(book.coverPath);
      } catch (_) {
        ok = false;
      }
    }

    try {
      await _books.saveAll(const []);
    } catch (_) {
      ok = false;
    }

    try {
      await _excerpts.clear();
      await _readingPreferences.clearAll();
      await _stats.reset();
    } catch (_) {
      ok = false;
    }

    try {
      await _profile.clearAll();
    } catch (_) {
      ok = false;
    }

    try {
      await _settings.resetToDefaults();
    } catch (_) {
      ok = false;
    }

    // 兜底：把容易残留的键一并清掉（书籍键上面已单独处理）。
    try {
      await _storage.remove(StorageKeys.importSites);
    } catch (_) {
      // 忽略：快捷站点缺失不影响账号重建。
    }

    return ok;
  }

  /// 让调用方可以在删除后确认头像文件确实不在了（调试用）。
  static Future<bool> fileExists(String? path) async {
    if (path == null || path.isEmpty) {
      return false;
    }
    return File(path).exists();
  }
}
