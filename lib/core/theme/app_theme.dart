import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// 全局主题构建。
///
/// 只在这里定义浅色 / 深色两套 ThemeData，页面不再自行写颜色，
/// 保证后续所有模块视觉统一。
class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;

    final Color accent = AppColors.accent(brightness);
    final Color secondary = AppColors.secondary(brightness);
    final Color background = AppColors.background(brightness);
    final Color surface = AppColors.surface(brightness);
    final Color textPrimary = AppColors.textPrimary(brightness);
    final Color textSecondary = AppColors.textSecondary(brightness);
    final Color divider = AppColors.divider(brightness);

    // 以 seed 生成基础 scheme，再把关键色覆盖为项目定制色，
    // 这样 Material 组件（SnackBar、输入框、进度条等）自动协调。
    final ColorScheme base = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
    );

    final ColorScheme scheme = base.copyWith(
      primary: accent,
      onPrimary: isDark ? const Color(0xFF1A1206) : const Color(0xFFFFFBF3),
      secondary: secondary,
      onSecondary: isDark ? const Color(0xFF07120F) : const Color(0xFFF6FFFC),
      surface: surface,
      onSurface: textPrimary,
      surfaceTint: Colors.transparent,
      error: AppColors.danger,
      onError: Colors.white,
      outline: divider,
      outlineVariant: AppColors.alpha(divider, 0.6),
    );

    final TextTheme textTheme = AppTypography.textTheme(brightness);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      // 全局关闭 Material 水波纹：所有按钮统一使用 PressableScale
      // 的「内缩回弹 + 液态玻璃」反馈，避免两套反馈叠加。
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      dividerColor: divider,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      iconTheme: IconThemeData(color: textPrimary, size: 22),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: textTheme.titleLarge,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.transparent,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.transparent,
              ),
      ),
      dividerTheme: DividerThemeData(
        color: divider,
        thickness: 0.8,
        space: 0.8,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: textPrimary,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          splashFactory: NoSplash.splashFactory,
          textStyle: textTheme.labelMedium,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.alpha(AppColors.panelFill(brightness), 0.55),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.textTertiary(brightness),
          letterSpacing: 0.6,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: divider, width: 0.8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: divider, width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: AppColors.alpha(accent, 0.85),
            width: 1.1,
          ),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: AppColors.alpha(accent, 0.18),
        thumbColor: accent,
        overlayColor: AppColors.alpha(accent, 0.12),
        trackHeight: 2.0,
        // 滑块保持纤细，按下时的放大与液态玻璃效果由页面自行包裹。
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.alpha(
          isDark ? const Color(0xFF1C1C1C) : const Color(0xFF232323),
          0.96,
        ),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 13.5,
          height: 1.4,
        ),
        elevation: 0,
        insetPadding: const EdgeInsets.fromLTRB(26, 0, 26, 26),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalBarrierColor: AppColors.alpha(Colors.black, isDark ? 0.55 : 0.28),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: AppColors.alpha(accent, 0.16),
      ),
      listTileTheme: ListTileThemeData(
        textColor: textPrimary,
        iconColor: textSecondary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18),
      ),
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}
