/// 本地存储键名集中定义。
///
/// 所有键统一加 `nw.` 前缀，避免与后续插件、第三方 SDK 写入的
/// SharedPreferences 键冲突。键名一经发布不再随意修改，
/// 否则会丢失老用户的本地数据。
class StorageKeys {
  const StorageKeys._();

  // ---------------- 首次启动 / 账号 ----------------

  /// 是否已经完成首次初始化（新建账号或导入备份任一即可置位）。
  static const String onboardingCompleted = 'nw.account.onboardingCompleted';

  /// 本地昵称。
  static const String userName = 'nw.account.userName';

  /// 本地头像的绝对路径（拷贝到应用私有目录之后的路径）。
  static const String userAvatarPath = 'nw.account.avatarPath';

  /// 账号创建时间（毫秒时间戳），用于统计入驻天数。
  static const String accountCreatedAt = 'nw.account.createdAt';

  // ---------------- 全局设置 ----------------

  /// 主题模式：system / light / dark。
  static const String themeMode = 'nw.settings.themeMode';

  /// 毛玻璃模糊程度：0~100。
  static const String glassBlur = 'nw.settings.glassBlur';

  /// 毛玻璃透明度：0~100。
  static const String glassOpacity = 'nw.settings.glassOpacity';

  /// 边框粗细档位：none / thin / thick。
  static const String glassBorder = 'nw.settings.glassBorder';

  /// 阅读字体模式（系统 / 宋体 / 楷体 / 自定义），阅读轮次使用。
  static const String readingFontMode = 'nw.settings.readingFontMode';

  /// 已导入的第三方字体文件路径（绝对路径，位于应用私有目录）。
  static const String customFontPath = 'nw.settings.customFontPath';

  /// 阅读水印开关。
  static const String watermarkEnabled = 'nw.settings.watermarkEnabled';

  /// 阅读水印类型：poem / english。
  static const String watermarkType = 'nw.settings.watermarkType';

  /// 装饰配色（第 3 轮）。
  static const String decorationTone = 'nw.settings.decorationTone';

  /// 帧率偏好档位：auto / system / hz30 ... hz120。
  static const String frameRate = 'nw.settings.frameRate';

  /// 是否减少动画。
  static const String reduceMotion = 'nw.settings.reduceMotion';

  // ---------------- 书籍数据 ----------------

  /// 全部书籍记录（JSON 数组字符串）。
  static const String books = 'nw.books.records';

  /// 导入页网站快捷小球列表（JSON 数组字符串，含隐藏的网址）。
  static const String importSites = 'nw.import.sites';

  // ---------------- 阅读 ----------------

  /// 阅读偏好（字号、行距、页边距、段落间距、翻页模式与操作开关）。
  static const String readingPreferences = 'nw.reading.preferences';

  /// 每本书的阅读背景（JSON 对象：书籍编号 → 背景 id）。
  static const String bookBackgrounds = 'nw.reading.bookBackgrounds';

  /// 用户上传过的阅读背景图库（JSON 数组，全局公共）。
  static const String readingBackgrounds = 'nw.reading.backgrounds';

  /// 摘抄库（JSON 数组）。
  static const String excerpts = 'nw.reading.excerpts';

  /// 书签库（JSON 数组，按书 + 章节位置存储，与阅读进度互不影响）。
  static const String bookmarks = 'nw.reading.bookmarks';

  /// 批注库（JSON 数组，原文片段 + 用户批注）。

  // ---------------- 阅读统计（我的页 / 打卡） ----------------

  /// 每日阅读秒数（JSON 对象：`yyyy-MM-dd` → 秒数）。
  static const String readingDailySeconds = 'nw.stats.readingDailySeconds';

  /// 累计阅读秒数（跨天累加，不与每日记录重复计算）。
  static const String readingTotalSeconds = 'nw.stats.readingTotalSeconds';

  /// 阅读标签权重（JSON 对象：标签 → 分值），雷达图数据源。
  static const String tagScores = 'nw.stats.tagScores';

  // ---------------- 版本更新 ----------------

  /// 上一次自动检测更新的时间戳（毫秒），用于 7 天冷却。
  static const String lastAutoUpdateCheckAt = 'nw.update.lastAutoCheckAt';

  /// 用户点过「稍后提醒」的版本代号：同一版本不再自动弹窗。
  static const String updateSkippedVersionCode = 'nw.update.skippedVersionCode';
}
