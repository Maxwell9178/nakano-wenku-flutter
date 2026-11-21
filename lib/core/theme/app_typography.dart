import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 字体族定义。
///
/// 需求约定：
/// - 中文标题、软件名称：艺术宋体 / 正楷，营造复古书香质感；
/// - 英文标注、署名：衬线英文字体；
/// - 阅读正文、界面小字：跟随系统字体，兼容用户自装字体。
///
/// 说明：项目不内置字体文件（避免仓库体积膨胀与授权问题），
/// 这里使用系统衬线字体族 `serif` 并附带常见中文宋体回退链；
/// 用户后续可在「设置」中导入第三方字体包覆盖。
class AppFonts {
  const AppFonts._();

  /// 内置宋体（Noto Serif SC 子集，随包分发）。
  ///
  /// 用内置字族而不是泛型 `serif`：后者在不少国产 ROM 上会被解析成无衬线，
  /// 导致中文标题看起来像黑体。字形缺失时再回退到系统宋体链。
  static const String serif = 'NWSerif';

  /// 中文宋体回退链，覆盖内置字缺失字形与第三方 ROM 差异。
  static const List<String> serifFallback = <String>[
    'Noto Serif CJK SC',
    'Noto Serif SC',
    'Source Han Serif SC',
    'Songti SC',
    'STSong',
    'serif',
  ];
}

/// 全局文本样式。
class AppTypography {
  const AppTypography._();

  /// 构建一套完整 TextTheme。
  ///
  /// 标题类统一使用衬线字体；正文类保持 null 字体族（跟随系统）。
  static TextTheme textTheme(Brightness brightness) {
    final Color primary = AppColors.textPrimary(brightness);
    final Color secondary = AppColors.textSecondary(brightness);

    return TextTheme(
      // 开屏 / 关于页的软件名称
      displayLarge: TextStyle(
        fontFamily: AppFonts.serif,
        fontFamilyFallback: AppFonts.serifFallback,
        fontSize: 40,
        fontWeight: FontWeight.w700,
        letterSpacing: 8,
        height: 1.12,
        color: primary,
      ),
      // 页面中文大标题
      headlineLarge: TextStyle(
        fontFamily: AppFonts.serif,
        fontFamilyFallback: AppFonts.serifFallback,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.4,
        height: 1.2,
        color: primary,
      ),
      headlineMedium: TextStyle(
        fontFamily: AppFonts.serif,
        fontFamilyFallback: AppFonts.serifFallback,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.7,
        height: 1.25,
        color: primary,
      ),
      titleLarge: TextStyle(
        fontFamily: AppFonts.serif,
        fontFamilyFallback: AppFonts.serifFallback,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: primary,
      ),
      titleMedium: TextStyle(
        fontSize: 15.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: primary,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        height: 1.62,
        letterSpacing: 0.2,
        color: primary,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.55,
        letterSpacing: 0.2,
        color: primary,
      ),
      bodySmall: TextStyle(
        fontSize: 12.5,
        height: 1.5,
        letterSpacing: 0.3,
        color: secondary,
      ),
      // 英文标注（大写、宽字距）
      labelLarge: TextStyle(
        fontFamily: AppFonts.serif,
        fontFamilyFallback: AppFonts.serifFallback,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 2.0,
        color: secondary,
      ),
      labelMedium: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.0,
        color: secondary,
      ),
      labelSmall: TextStyle(
        fontFamily: AppFonts.serif,
        fontFamilyFallback: AppFonts.serifFallback,
        fontSize: 10.5,
        fontWeight: FontWeight.w500,
        letterSpacing: 3.2,
        color: secondary,
      ),
    );
  }

  /// 中文大标题（可与全局范式配合单独调用）。
  static TextStyle chineseTitle(Brightness brightness, {double fontSize = 22}) {
    return TextStyle(
      fontFamily: AppFonts.serif,
      fontFamilyFallback: AppFonts.serifFallback,
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      letterSpacing: 2.2,
      color: AppColors.textPrimary(brightness),
    );
  }

  /// 英文标注 / 署名。
  static TextStyle englishLabel(
    Brightness brightness, {
    double fontSize = 10.5,
    double letterSpacing = 3.2,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: AppFonts.serif,
      fontFamilyFallback: AppFonts.serifFallback,
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
      letterSpacing: letterSpacing,
      color: color ?? AppColors.textSecondary(brightness),
    );
  }

  /// 楷体回退链（设置页「楷体」选项使用）。
  static const List<String> kaiFallback = <String>[
    'Kaiti SC',
    'STKaiti',
    'KaiTi',
    '楷体',
    'Songti SC',
    'serif',
  ];

  /// 自定义字体缺字时的回退链：先宋体，再系统默认。
  static const List<String> customFallback = <String>[
    'Songti SC',
    'STSong',
    'Noto Serif CJK SC',
    'serif',
  ];

  /// 根据字体族返回配套的回退链。
  static List<String> fallbackFor(String family) {
    switch (family) {
      case AppFonts.serif:
        return AppFonts.serifFallback;
      case 'KaiTi':
        return kaiFallback;
      case 'NWCustomFont':
        return customFallback;
      default:
        return const <String>[];
    }
  }

  /// 把阅读字体偏好套用到整套主题上。
  ///
  /// 只覆盖阅读正文、界面小字这些「可被用户替换」的类别；
  /// 中文大标题（display/headline/titleLarge）与英文标注（labelLarge）
  /// 始终保留衬线体，避免用户导入的字体把标题也改掉。
  static ThemeData themeWithFont(ThemeData base, String? family) {
    if (family == null) {
      return base;
    }
    final List<String> fallback = fallbackFor(family);
    final TextTheme source = base.textTheme;
    return base.copyWith(
      textTheme: source.copyWith(
        // 标题类：显式写回衬线体，防止被外层 DefaultTextStyle 污染。
        displayLarge: _forceSerif(source.displayLarge),
        headlineLarge: _forceSerif(source.headlineLarge),
        headlineMedium: _forceSerif(source.headlineMedium),
        titleLarge: _forceSerif(source.titleLarge),
        labelLarge: _forceSerif(source.labelLarge),
        labelSmall: _forceSerif(source.labelSmall),
        bodyLarge: source.bodyLarge?.copyWith(
          fontFamily: family,
          fontFamilyFallback: fallback,
        ),
        bodyMedium: source.bodyMedium?.copyWith(
          fontFamily: family,
          fontFamilyFallback: fallback,
        ),
        bodySmall: source.bodySmall?.copyWith(
          fontFamily: family,
          fontFamilyFallback: fallback,
        ),
        // 书名小字跟随字体设置，这是需求明确允许的类别。
        titleMedium: source.titleMedium?.copyWith(
          fontFamily: family,
          fontFamilyFallback: fallback,
        ),
        labelMedium: source.labelMedium?.copyWith(
          fontFamily: family,
          fontFamilyFallback: fallback,
        ),
      ),
    );
  }

  static TextStyle? _forceSerif(TextStyle? style) {
    if (style == null) {
      return null;
    }
    return style.copyWith(
      fontFamily: AppFonts.serif,
      fontFamilyFallback: AppFonts.serifFallback,
    );
  }
}
