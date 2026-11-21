import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../settings/app_settings.dart';
import '../theme/app_colors.dart';

/// 毛玻璃面板（全局公共组件）。
///
/// 与 [LiquidGlass] 的区别：
/// - 液态玻璃偏「透明、反光、可点击」；
/// - 毛玻璃偏「厚实、可读」，用于卡片、弹窗、底部导航等承载文字的容器，
///   填充不透明度更高，保证深浅主题下的对比度。
class FrostedGlass extends StatelessWidget {
  const FrostedGlass({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.tint,
    this.blurSigma,
    this.opacity,
    this.borderWidth,
    this.shadows = false,
    this.blurMultiplier = 1.15,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  /// 面板底色，默认跟随主题。
  final Color? tint;

  // ---------------- 单次覆盖项 ----------------

  final double? blurSigma;
  final double? opacity;
  final double? borderWidth;

  final bool shadows;

  /// 面板通常比液态玻璃再模糊一点，层次更稳。
  final double blurMultiplier;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final bool isDark = brightness == Brightness.dark;
    final GlassSpec spec = context.watch<AppSettingsController>().glassSpec;

    final double sigma = blurSigma ?? spec.blurSigma * blurMultiplier;
    final double fillOpacity =
        (opacity ?? spec.panelOpacity).clamp(0.0, 1.0).toDouble();
    final double stroke = borderWidth ?? spec.borderWidth;

    final BorderRadius radius = BorderRadius.circular(borderRadius);
    final Color baseTint = tint ?? AppColors.panelFill(brightness);
    final Color fill = AppColors.alpha(baseTint, fillOpacity);

    final Color borderColor = AppColors.alpha(
      Colors.white,
      isDark ? 0.20 : 0.62,
    );

    Widget surface = ClipRRect(
      borderRadius: radius,
      child: Stack(
        children: <Widget>[
          if (sigma > 0.4)
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: const SizedBox.expand(),
              ),
            ),
          Positioned.fill(
            child: DecoratedBox(decoration: BoxDecoration(color: fill)),
          ),
          // 极轻的顶部高光：让厚面板也有玻璃边缘，而不是纯色块。
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      AppColors.alpha(Colors.white, isDark ? 0.08 : 0.22),
                      Colors.transparent,
                      AppColors.alpha(Colors.black, isDark ? 0.10 : 0.02),
                    ],
                    stops: const <double>[0.0, 0.35, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );

    surface = Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: shadows
            ? <BoxShadow>[
                BoxShadow(
                  color: AppColors.alpha(
                    Colors.black,
                    isDark ? 0.45 : 0.10,
                  ),
                  blurRadius: 22,
                  spreadRadius: -8,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      foregroundDecoration: stroke <= 0.01
          ? null
          : BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: borderColor, width: stroke),
            ),
      child: surface,
    );

    if (margin == EdgeInsets.zero) {
      return surface;
    }
    return Padding(padding: margin, child: surface);
  }
}
