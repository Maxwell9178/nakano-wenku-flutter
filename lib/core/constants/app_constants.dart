/// NakanoWenku 全局常量。
///
/// 这里只存放「不随业务变化」的固定值：品牌信息、署名、外链、书籍编号规则、
/// 支持的格式、开屏时长等。集中管理可以避免魔法字符串散落在各个业务模块中。
class AppConstants {
  const AppConstants._();

  // ---------------- 品牌信息 ----------------

  /// 软件名称（开屏大字、顶部栏、关于页统一使用）。
  static const String appName = 'NakanoWenku';

  /// 开屏小字署名。
  static const String signature = 'MADE BY MAXWELL';

  /// 作者信息。
  static const String author = 'Maxwell9178';
  static const String authorUrl = 'https://github.com/Maxwell9178';
  static const String repoUrl =
      'https://github.com/Maxwell9178/nakano-wenku-flutter';

  /// 交流 Q 群号（版本页、关于作者页展示，可一键复制）。
  static const String qqGroup = '1126557550';

  // ---------------- 版本信息 ----------------

  /// 需与 pubspec.yaml 的 version 保持一致。
  static const String versionName = '1.0.0';
  static const int versionCode = 1;

  // ---------------- 版本更新 ----------------

  /// 主源：Gitee Pages 上托管的静态 version.json。
  ///
  /// 部署方式见工程根目录「打包与发布说明.md」：
  /// 仓库开启 Pages 后，把 version.json 与 app-release.apk 放在部署目录根下，
  /// 这里的地址就是 Pages 给出的公开链接。
  static const String updateManifestUrl =
      'https://maxwell9178.gitee.io/nakano-wenku-flutter/version.json';

  /// 主源兜底：仓库 raw 文件（Pages 未部署或尚未刷新时仍能读到）。
  static const String updateRawManifestUrl =
      'https://gitee.com/Maxwell9178/nakano-wenku-flutter/raw/master/version.json';

  /// 备用源：GitHub Releases 最新发布接口。
  static const String updateApiUrl =
      'https://api.github.com/repos/Maxwell9178/nakano-wenku-flutter/releases/latest';

  /// GitHub 仓库 raw 清单（main 分支根目录的 version.json）。
  ///
  /// 这条不需要 GitHub Pages、也不需要 Releases：只要把 version.json 推到 main 分支，
  /// 立刻就能读到，是最省事的一路源。
  static const String updateGithubRawManifestUrl =
      'https://raw.githubusercontent.com/Maxwell9178/nakano-wenku-flutter/main/version.json';

  /// GitHub 仓库 raw 的 APK 直链（清单里没有 downloadUrl 时用它）。
  static const String updateGithubRawApkUrl =
      'https://raw.githubusercontent.com/Maxwell9178/nakano-wenku-flutter/main/dist/app-release.apk';

  /// 第二静态源：jsDelivr 代理 GitHub 仓库，国内多数网络可直连。
  static const String updateMirrorUrl =
      'https://cdn.jsdelivr.net/gh/Maxwell9178/nakano-wenku-flutter@main/version.json';

  /// 兜底下载页：用户点「立即下载」但清单里没有直链时打开这里。
  static const String updateReleasesPage =
      'https://github.com/Maxwell9178/nakano-wenku-flutter/releases';

  /// Gitee Pages 上的 APK 直链，与 version.json 里的 downloadUrl 保持一致。
  static const String updateApkUrl =
      'https://maxwell9178.gitee.io/nakano-wenku-flutter/app-release.apk';

  /// 兜底 APK 直链：清单里没给 downloadUrl 时，按顺序换这些地址试。
  static const List<String> updateApkFallbackUrls = <String>[
    'https://github.com/Maxwell9178/nakano-wenku-flutter/releases/download/1.0.0/app-release.apk',
    'https://github.com/Maxwell9178/nakano-wenku-flutter/releases/latest/download/app-release.apk',
    'https://raw.githubusercontent.com/Maxwell9178/nakano-wenku-flutter/main/dist/app-release.apk',
  ];

  /// 冷启动自动检测的冷却天数（手动检测不受限制）。
  static const int updateCheckCooldownDays = 7;

  /// 冷启动后延迟多久再发起检测，避开开屏与首帧。
  static const Duration updateAutoCheckDelay = Duration(seconds: 6);

  // ---------------- 书籍编号规则 ----------------

  /// 书籍编号前缀，完整形态如「NW-0001」。
  static const String bookIdPrefix = 'NW-';
  static const int bookIdMin = 1;
  static const int bookIdMax = 9999;

  /// 将数字编号格式化为 NW-XXXX。
  static String formatBookId(int number) {
    final safe = number.clamp(bookIdMin, bookIdMax);
    return '$bookIdPrefix${safe.toString().padLeft(4, '0')}';
  }

  // ---------------- 支持的文件格式 ----------------

  /// 导入页面展示与筛选使用的后缀（EPUB 优先级最高）。
  static const List<String> importableExtensions = <String>[
    'epub',
    'txt',
    'pdf',
    'doc',
    'docx',
    'md',
    'zip',
    'cbx',
    'cbz',
  ];

  /// 备份包后缀（zip 改名）。
  static const String backupExtension = 'wkarchive';

  // ---------------- 书籍标签 ----------------

  /// 内置标签，用户还可以自定义追加。
  static const List<String> presetTags = <String>[
    '文学',
    '热血',
    '科幻',
    '恋爱',
    '运动',
    '悬疑',
  ];

  // ---------------- 时间与动效 ----------------

  /// 开屏真实停留时长区间：3~5 秒随机。
  static const Duration splashMinDuration = Duration(seconds: 3);
  static const Duration splashMaxDuration = Duration(seconds: 5);

  /// 全局页面转场时长，保证柔和。
  static const Duration pageTransitionDuration = Duration(milliseconds: 460);

  // ---------------- 内置资源 ----------------

  static const String appIconAsset = 'assets/images/app_icon.png';
  static const String donateQrAsset = 'assets/images/donate_qr.jpg';
  static const String quotesAsset = 'assets/data/quotes.txt';
  static const String authorWordsAsset = 'assets/data/author_words.txt';
  static const String safetyNoticeAsset = 'assets/data/safety_notice.txt';
  static const String techNotesAsset = 'assets/data/tech_notes.txt';

  // ---------------- 兜底文案 ----------------

  /// 备份包未提供用户名时的兜底昵称。
  static const String defaultUserName = '书友';

  /// 默认空白头像的语义名称（实际界面使用内置图标绘制）。
  static const String defaultAvatarLabel = '默认空白头像';
}
