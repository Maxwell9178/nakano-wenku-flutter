import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/models/app_update.dart';
import 'core/routing/app_router.dart';
import 'core/routing/app_routes.dart';
import 'core/services/account_data_service.dart';
import 'core/services/app_services.dart';
import 'core/services/backup_import_service.dart';
import 'core/services/book_import_service.dart';
import 'core/services/book_repository.dart';
import 'core/services/bookmark_repository.dart';
import 'core/services/reading_position_repository.dart';
import 'core/services/chapter_repository.dart';
import 'core/services/custom_font_service.dart';
import 'core/services/excerpt_repository.dart';
import 'core/services/import_site_repository.dart';
import 'core/services/local_file_scanner.dart';
import 'core/services/quote_repository.dart';
import 'core/services/reading_preferences_repository.dart';
import 'core/services/reading_stats_repository.dart';
import 'core/services/reading_time_service.dart';
import 'core/services/tag_repository.dart';
import 'core/services/tag_weight_repository.dart';
import 'core/services/update_service.dart';
import 'core/services/user_profile_controller.dart';
import 'core/services/wkarchive_service.dart';
import 'core/settings/app_settings.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_typography.dart';
import 'features/settings/widgets/update_dialog.dart';

/// 应用根组件。
///
/// 职责只有三件事：
/// 1. 把全局控制器注入 Provider；
/// 2. 绑定浅色 / 深色主题与全局路由；
/// 3. 主题切换时整棵树平滑重建（不做闪白过渡）。
class NakanoWenkuApp extends StatelessWidget {
  const NakanoWenkuApp({super.key});

  /// 冷启动更新检测在 MaterialApp.builder 层触发，那里位于 Navigator 之上，
  /// 无法直接用 `Navigator.of(context)` 弹窗，因此保留一个全局 Navigator 引用。
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    final AppServices services = AppServices.instance;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppSettingsController>.value(
          value: services.settings,
        ),
        ChangeNotifierProvider<UserProfileController>.value(
          value: services.profile,
        ),
        Provider<BackupImportService>.value(value: services.backup),
        Provider<BookRepository>.value(value: services.books),
        Provider<ChapterRepository>.value(value: services.chapters),
        Provider<ImportSiteRepository>.value(value: services.importSites),
        Provider<LocalFileScanner>.value(value: services.fileScanner),
        Provider<BookImportService>.value(value: services.importService),
        Provider<ReadingPreferencesRepository>.value(
          value: services.readingPreferences,
        ),
        Provider<ExcerptRepository>.value(value: services.excerpts),
        Provider<QuoteRepository>.value(value: services.quotes),
        Provider<ReadingStatsRepository>.value(value: services.readingStats),
        Provider<BookmarkRepository>.value(value: services.bookmarks),
        Provider<TagRepository>.value(value: services.tags),
        Provider<TagWeightRepository>.value(value: services.tagWeights),
        Provider<ReadingTimeService>.value(value: services.readingTime),
        Provider<ReadingPositionRepository>.value(
          value: services.readingPositions,
        ),
        Provider<AccountDataService>.value(value: services.accountData),
        Provider<WkArchiveService>.value(value: services.wkArchive),
        Provider<CustomFontService>.value(value: services.customFonts),
        Provider<UpdateService>.value(value: services.update),
      ],
      child: Consumer<AppSettingsController>(
        builder: (BuildContext context, AppSettingsController settings, _) {
          final ThemeData light = AppTypography.themeWithFont(
            AppTheme.light(),
            settings.fontFamilyOverride,
          );
          final ThemeData dark = AppTypography.themeWithFont(
            AppTheme.dark(),
            settings.fontFamilyOverride,
          );

          return MaterialApp(
            title: 'NakanoWenku',
            debugShowCheckedModeBanner: false,
            theme: light,
            darkTheme: dark,
            themeMode: settings.themeMode,
            initialRoute: AppRoutes.splash,
            navigatorKey: navigatorKey,
            onGenerateRoute: AppRouter.onGenerateRoute,
            builder: (BuildContext context, Widget? child) {
              // 「减少动画」：统一关闭系统级过渡动画，
              // 各页面自身的 Animated* 组件会读取该标志后缩短时长。
              final MediaQueryData media = MediaQuery.of(context);
              return MediaQuery(
                data: media.copyWith(
                  disableAnimations: settings.reduceMotion,
                ),
                // 冷启动时静默检查一次版本更新（7 天冷却，失败不打扰）。
                child: _UpdateBootstrap(
                  child: child ?? const SizedBox.shrink(),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// 冷启动版本检测外壳。
///
/// 只负责「什么时候查」，网络请求、7 天冷却、稍后提醒的记录都在
/// [UpdateService] 内部完成；这里不做任何 UI 布局。
class _UpdateBootstrap extends StatefulWidget {
  const _UpdateBootstrap({required this.child});

  final Widget child;

  @override
  State<_UpdateBootstrap> createState() => _UpdateBootstrapState();
}

class _UpdateBootstrapState extends State<_UpdateBootstrap> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleCheck());
  }

  Future<void> _scheduleCheck() async {
    // 等开屏稳定后再请求网络，避免与首帧渲染抢资源。
    await Future<void>.delayed(AppConstants.updateAutoCheckDelay);
    if (!mounted) {
      return;
    }
    final UserProfileController profile = context.read<UserProfileController>();
    final UpdateService update = context.read<UpdateService>();
    // 首次初始化还没完成时先不打扰使用者。
    if (!profile.onboardingCompleted) {
      return;
    }
    // 冷却期内（或用户勾了「稍后提醒」）直接跳过。
    if (!update.shouldAutoCheck()) {
      return;
    }
    final UpdateCheckResult result = await update.check();
    if (!mounted || !result.hasUpdate) {
      return;
    }
    final AppVersionInfo? info = result.info;
    if (info == null || update.isDismissed(info)) {
      return;
    }
    // builder 层位于 Navigator 之上，这里取 Navigator 内部的 overlay context。
    final BuildContext? dialogContext =
        NakanoWenkuApp.navigatorKey.currentState?.overlay?.context;
    if (dialogContext == null || !dialogContext.mounted) {
      return;
    }
    final UpdateDialogAction action =
        await showUpdateDialog(dialogContext, info);
    if (action == UpdateDialogAction.later) {
      await update.dismiss(info);
      return;
    }
    await update.openDownload(info);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
