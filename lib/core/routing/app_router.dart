import 'package:flutter/material.dart';

import '../../features/book_detail/book_detail_page.dart';
import '../../features/bookmarks/bookmark_list_page.dart';
import '../../features/comic/comic_page.dart';
import '../../features/home/home_shell.dart';
import '../../features/import/import_page.dart';
import '../../features/onboarding/onboarding_page.dart';
import '../../features/reader/reader_arguments.dart';
import '../../features/reader/reader_page.dart';
import '../../features/settings/pages/about_author_page.dart';
import '../../features/settings/pages/document_page.dart';
import '../../features/settings/pages/version_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/splash/splash_page.dart';
import '../constants/app_constants.dart';
import '../models/book.dart';
import '../theme/app_typography.dart';
import '../widgets/ghost_button.dart';
import '../widgets/grid_background.dart';
import '../widgets/thin_divider.dart';
import 'app_routes.dart';
import 'soft_page_route.dart';

/// 全局路由工厂。
///
/// 统一走 [SoftPageRoute]，保证任何页面跳转动画一致；
/// 未注册的路由给一个安静的兜底页，而不是白屏或异常。
class AppRouter {
  const AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return SoftPageRoute<void>(
          settings: settings,
          builder: (BuildContext context) => const SplashPage(),
        );

      case AppRoutes.onboarding:
        return SoftPageRoute<void>(
          settings: settings,
          builder: (BuildContext context) => const OnboardingPage(),
        );

      case AppRoutes.home:
        return SoftPageRoute<void>(
          settings: settings,
          builder: (BuildContext context) => const HomeShell(),
        );

      case AppRoutes.bookDetail:
        // 详情页需要书籍对象；参数缺失时给兜底提示页而不是崩溃。
        final Object? arguments = settings.arguments;
        if (arguments is Book) {
          return SoftPageRoute<void>(
            settings: settings,
            builder: (BuildContext context) => BookDetailPage(book: arguments),
          );
        }
        return SoftPageRoute<void>(
          settings: settings,
          builder: (BuildContext context) =>
              UnknownRoutePage(routeName: settings.name),
        );

      case AppRoutes.importFiles:
        return SoftPageRoute<void>(
          settings: settings,
          builder: (BuildContext context) => const ImportPage(),
        );

      case AppRoutes.settings:
        return SoftPageRoute<void>(
          settings: settings,
          builder: (BuildContext context) => const SettingsPage(),
        );

      case AppRoutes.version:
        return SoftPageRoute<void>(
          settings: settings,
          builder: (BuildContext context) => const VersionPage(),
        );

      case AppRoutes.safetyNotice:
        return SoftPageRoute<void>(
          settings: settings,
          builder: (BuildContext context) => const AssetDocumentPage(
            title: '安全声明',
            english: 'SAFETY NOTICE',
            assetPath: AppConstants.safetyNoticeAsset,
          ),
        );

      case AppRoutes.techNotes:
        return SoftPageRoute<void>(
          settings: settings,
          builder: (BuildContext context) => const AssetDocumentPage(
            title: '技术说明',
            english: 'TECH NOTES',
            assetPath: AppConstants.techNotesAsset,
          ),
        );

      case AppRoutes.aboutAuthor:
        return SoftPageRoute<void>(
          settings: settings,
          builder: (BuildContext context) => const AboutAuthorPage(),
        );

      case AppRoutes.reader:
        // 阅读页支持两种入参：ReaderArguments（书 + 章节）或直接传 Book。
        final Object? readerArguments = settings.arguments;
        if (readerArguments is ReaderArguments) {
          return SoftPageRoute<void>(
            settings: settings,
            builder: (BuildContext context) => ReaderPage(
              book: readerArguments.book,
              chapterIndex: readerArguments.chapterIndex,
              chapterTitle: readerArguments.chapterTitle,
            ),
          );
        }
        if (readerArguments is Book) {
          return SoftPageRoute<void>(
            settings: settings,
            builder: (BuildContext context) =>
                ReaderPage(book: readerArguments),
          );
        }
        return SoftPageRoute<void>(
          settings: settings,
          builder: (BuildContext context) =>
              UnknownRoutePage(routeName: settings.name),
        );

      case AppRoutes.comic:
        final Object? comicArguments = settings.arguments;
        if (comicArguments is Book) {
          return SoftPageRoute<void>(
            settings: settings,
            builder: (BuildContext context) => ComicPage(book: comicArguments),
          );
        }
        return SoftPageRoute<void>(
          settings: settings,
          builder: (BuildContext context) =>
              UnknownRoutePage(routeName: settings.name),
        );

      case AppRoutes.bookmarks:
        final Object? bookmarkArguments = settings.arguments;
        if (bookmarkArguments is Book) {
          return SoftPageRoute<void>(
            settings: settings,
            builder: (BuildContext context) =>
                BookmarkListPage(book: bookmarkArguments),
          );
        }
        return SoftPageRoute<void>(
          settings: settings,
          builder: (BuildContext context) =>
              UnknownRoutePage(routeName: settings.name),
        );

      default:
        return SoftPageRoute<void>(
          settings: settings,
          builder: (BuildContext context) =>
              UnknownRoutePage(routeName: settings.name),
        );
    }
  }
}

/// 未注册路由兜底页面。
///
/// 正常流程不会出现，仅在开发期路由名写错时给出明确提示。
class UnknownRoutePage extends StatelessWidget {
  const UnknownRoutePage({super.key, this.routeName});

  final String? routeName;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;

    return Scaffold(
      body: GridBackground(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '页面不存在',
                    style: AppTypography.chineseTitle(brightness, fontSize: 24),
                  ),
                  const SizedBox(height: 12),
                  const ThinDivider(width: 42, thickness: 1.0),
                  const SizedBox(height: 12),
                  Text(
                    (routeName ?? 'unknown').toUpperCase(),
                    style: AppTypography.englishLabel(brightness),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    '该路由尚未注册，请返回书架重试。',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 20),
                  GhostButton(
                    label: '返回书架',
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.of(context).pushNamedAndRemoveUntil(
                      AppRoutes.home,
                      (Route<dynamic> route) => false,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
