/// 全局路由名集中定义。
///
/// 后续轮次新增页面（书籍详情、阅读页、导入页、设置页等）时，
/// 在这里追加常量，并在 AppRouter 中注册，避免字符串硬编码散落各处。
class AppRoutes {
  const AppRoutes._();

  /// 开屏启动页。
  static const String splash = '/';

  /// 首次启动初始化页（新建本地账号 / 导入备份）。
  static const String onboarding = '/onboarding';

  /// 底部导航主框架（书架 / 搜索 / 我的）。
  static const String home = '/home';

  // ---------------- 后续轮次预留 ----------------

  /// 书籍详情页（预留）。
  static const String bookDetail = '/book';

  /// 阅读页（预留）。
  static const String reader = '/reader';

  /// 漫画阅读页（CBX / CBZ 图片包）。
  static const String comic = '/comic';

  /// 书签列表页。
  static const String bookmarks = '/bookmarks';

  /// 批注列表页。

  /// 导入页面（预留）。
  static const String importFiles = '/import';

  /// 搜索页（预留，当前为底部标签占位）。
  static const String search = '/search';

  /// 设置页（预留）。
  static const String settings = '/settings';

  /// 关于作者页（预留）。
  static const String aboutAuthor = '/about-author';

  /// 版本设置页（预留）。
  static const String version = '/version';

  /// 安全声明与用户风险告知书。
  static const String safetyNotice = '/safety-notice';

  /// 技术说明。
  static const String techNotes = '/tech-notes';
}
