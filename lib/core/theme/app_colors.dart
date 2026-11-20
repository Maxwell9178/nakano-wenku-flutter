import 'package:flutter/material.dart';

/// 全局配色。
///
/// 设计约束（来自项目需求）：
/// 1. 浅色模式为「柔和白」，刻意避开偏黄的奶白；
/// 2. 深色模式为「纯深黑」；
/// 3. 两种模式都存在灰色网格纹理；
/// 4. 配色需要有层次，不能只有黑白，因此额外提供复古金（accent）
///    与墨青（secondary）两个辅助色，用于高亮、分割线、选中态。
class AppColors {
  const AppColors._();

  // ---------------- 浅色模式 ----------------

  /// 柔和白底色（略灰，非奶白）。
  static const Color lightBackground = Color(0xFFF4F4F1);

  /// 背景的次级层，用于渐变收边。
  static const Color lightBackgroundDeep = Color(0xFFE8E8E3);

  /// 卡片/面板基底。
  static const Color lightSurface = Color(0xFFFDFDFC);

  static const Color lightTextPrimary = Color(0xFF131313);
  static const Color lightTextSecondary = Color(0xFF5F5F59);
  static const Color lightTextTertiary = Color(0xFF94948D);

  // ---------------- 深色模式 ----------------

  /// 纯深黑底色。
  static const Color darkBackground = Color(0xFF000000);

  static const Color darkBackgroundDeep = Color(0xFF0C0C0C);
  static const Color darkSurface = Color(0xFF121212);

  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFB2B2AC);
  static const Color darkTextTertiary = Color(0xFF6F6F69);

  // ---------------- 辅助色 ----------------

  /// 复古暗金：高亮、分割线、选中态。
  static const Color accentLight = Color(0xFF8A6A3C);
  static const Color accentDark = Color(0xFFC9A66B);

  /// 墨青：次级高亮，避免配色单调。
  static const Color secondaryLight = Color(0xFF3F5F5A);
  static const Color secondaryDark = Color(0xFF7FA8A0);

  /// 危险操作（删除账号等）使用。
  static const Color danger = Color(0xFFB3261E);

  // ---------------- 玻璃材质基色 ----------------

  static const Color lightGlassTint = Color(0xFFFFFFFF);
  static const Color darkGlassTint = Color(0xFF262626);

  /// 毛玻璃面板填充色。
  static const Color lightPanelFill = Color(0xFFFFFFFF);
  static const Color darkPanelFill = Color(0xFF151515);

  // ---------------- 工具方法 ----------------

  /// 统一的透明度工具。
  ///
  /// 使用 withAlpha 而不是已弃用的 withOpacity，兼容新老 Flutter 版本。
  static Color alpha(Color color, double opacity) {
    final int value = (opacity.clamp(0.0, 1.0) * 255).round();
    return color.withAlpha(value);
  }

  /// 网格线条颜色：极浅，仅提供纹理感，不干扰阅读。
  static Color gridLine(Brightness brightness) {
    return brightness == Brightness.dark
        ? alpha(Colors.white, 0.075)
        : alpha(Colors.black, 0.055);
  }

  /// 细分割线颜色。
  static Color divider(Brightness brightness) {
    return brightness == Brightness.dark
        ? alpha(Colors.white, 0.14)
        : alpha(Colors.black, 0.11);
  }

  static Color background(Brightness brightness) => brightness == Brightness.dark
      ? darkBackground
      : lightBackground;

  static Color backgroundDeep(Brightness brightness) =>
      brightness == Brightness.dark ? darkBackgroundDeep : lightBackgroundDeep;

  static Color surface(Brightness brightness) =>
      brightness == Brightness.dark ? darkSurface : lightSurface;

  static Color textPrimary(Brightness brightness) =>
      brightness == Brightness.dark ? darkTextPrimary : lightTextPrimary;

  static Color textSecondary(Brightness brightness) =>
      brightness == Brightness.dark ? darkTextSecondary : lightTextSecondary;

  static Color textTertiary(Brightness brightness) =>
      brightness == Brightness.dark ? darkTextTertiary : lightTextTertiary;

  static Color accent(Brightness brightness) =>
      brightness == Brightness.dark ? accentDark : accentLight;

  static Color secondary(Brightness brightness) =>
      brightness == Brightness.dark ? secondaryDark : secondaryLight;

  static Color glassTint(Brightness brightness) =>
      brightness == Brightness.dark ? darkGlassTint : lightGlassTint;

  static Color panelFill(Brightness brightness) =>
      brightness == Brightness.dark ? darkPanelFill : lightPanelFill;
}
