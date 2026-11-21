import 'package:flutter/material.dart';

/// 全局配色。
///
/// 设计约束（来自项目需求）：
/// 1. 浅色模式为「柔和白」，刻意避开偏黄的奶白；
/// 2. 深色模式为「纯深黑」；
/// 3. 两种模式都存在灰色网格纹理；
/// 4. 所有分割线、图标线条只用白色 / 浅灰色，不再出现金色系。
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

  /// 高亮 / 选中态 / 装饰线：中性灰，浅色模式用深灰保证可见，
  /// 深色模式用近白灰，彻底移除此前的复古金。
  static const Color accentLight = Color(0xFF5C5C56);
  static const Color accentDark = Color(0xFFE7E7E2);

  /// 次级高亮：同样收敛为中性灰，避免抢主色。
  static const Color secondaryLight = Color(0xFF8C8C86);
  static const Color secondaryDark = Color(0xFFBFBFB9);

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

  /// 细分割线颜色：需要肉眼可辨，因此不再压到极低透明度。
  static Color divider(Brightness brightness) {
    return brightness == Brightness.dark
        ? alpha(Colors.white, 0.22)
        : alpha(Colors.black, 0.18);
  }

  static Color background(Brightness brightness) =>
      brightness == Brightness.dark ? darkBackground : lightBackground;

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

  /// 装饰配色（第 3 轮新增）。
  ///
  /// 仅作为附加装饰效果，不修改深浅模式的原生底色；
  /// 为空时使用默认灰阶强调色。
  static Color? decoration;

  static Color accent(Brightness brightness) =>
      decoration ?? (brightness == Brightness.dark ? accentDark : accentLight);

  static Color secondary(Brightness brightness) =>
      brightness == Brightness.dark ? secondaryDark : secondaryLight;

  static Color glassTint(Brightness brightness) {
    final Color? tone = decoration;
    final Color base =
        brightness == Brightness.dark ? darkGlassTint : lightGlassTint;
    if (tone == null) {
      return base;
    }
    // 装饰色只给毛玻璃染一层薄膜，底色仍是原来的黑白灰。
    return Color.alphaBlend(
      alpha(tone, brightness == Brightness.dark ? 0.22 : 0.16),
      base,
    );
  }

  static Color panelFill(Brightness brightness) =>
      brightness == Brightness.dark ? darkPanelFill : lightPanelFill;
}
