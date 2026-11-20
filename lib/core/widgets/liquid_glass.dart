import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../settings/app_settings.dart';
import '../theme/app_colors.dart';
import 'pressable_scale.dart';

/// 液态玻璃容器（全局公共组件）。
///
/// 视觉要素：
/// 1. BackdropFilter 背景模糊；
/// 2. 斜向的玻璃底色渐变（左上偏亮、右下偏暗）；
/// 3. 顶部反光 + 极细描边；
/// 4. 外层柔和投影，制造「浮起」的厚度感。
///
/// 模糊强度、透明度、边框粗细全部读取全局设置，保证一处调整、
/// 全应用一致；局部需要特殊材质时可用 [blurSigma] / [opacity] /
/// [borderWidth] 覆盖单次。
class LiquidGlass extends StatelessWidget {
  const LiquidGlass({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.tint,
    this.blurSigma,
    this.opacity,
    this.borderWidth,
    this.shadows = true,
    this.sheen = true,
  });

  final Widget child;

  /// 圆角半径。
  final double borderRadius;

  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  /// 提供后整个玻璃面变成可点击区域（自动套用内缩回弹反馈）。
  final VoidCallback? onTap;

  /// 玻璃底色，默认跟随主题。
  final Color? tint;

  // ---------------- 单次覆盖项 ----------------

  final double? blurSigma;
  final double? opacity;
  final double? borderWidth;

  final bool shadows;

  /// 是否绘制反光与描边。
  final bool sheen;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final bool isDark = brightness == Brightness.dark;

    // watch：设置页拖动模糊/透明度滑块时，玻璃组件即时刷新。
    final GlassSpec spec = context.watch<AppSettingsController>().glassSpec;

    final double sigma = blurSigma ?? spec.blurSigma;
    final double fillOpacity = opacity ?? spec.liquidTintOpacity;
    final double stroke = sheen ? (borderWidth ?? spec.borderWidth) : 0.0;

    final BorderRadius radius = BorderRadius.circular(borderRadius);
    final Color baseTint = tint ?? AppColors.glassTint(brightness);

    final Color fillTop = AppColors.alpha(baseTint, fillOpacity + 0.05);
    final Color fillBottom = AppColors.alpha(baseTint, fillOpacity * 0.55);

    // 深色模式下描边更亮，浅色模式下更接近「玻璃边缘的高光」。
    final Color borderColor = AppColors.alpha(
      Colors.white,
      isDark ? 0.26 : 0.72,
    );

    final Widget glassSurface = ClipRRect(
      borderRadius: radius,
      child: Stack(
        children: <Widget>[
          // 背景模糊
          if (sigma > 0.4)
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: const SizedBox.expand(),
              ),
            ),

          // 玻璃底色渐变
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[fillTop, fillBottom],
                ),
              ),
            ),
          ),

          // 斜向反光
          if (sheen)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        AppColors.alpha(Colors.white, isDark ? 0.10 : 0.30),
                        Colors.transparent,
                        AppColors.alpha(Colors.white, isDark ? 0.02 : 0.08),
                      ],
                      stops: const <double>[0.0, 0.42, 1.0],
                    ),
                  ),
                ),
              ),
            ),

          // 内容
          Padding(padding: padding, child: child),
        ],
      ),
    );

    Widget surface = Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: shadows
            ? <BoxShadow>[
                BoxShadow(
                  color: AppColors.alpha(
                    isDark ? Colors.black : const Color(0xFF4B4B45),
                    isDark ? 0.55 : 0.12,
                  ),
                  blurRadius: 26,
                  spreadRadius: -6,
                  offset: const Offset(0, 12),
                ),
              ]
            : null,
      ),
      // 边框画在内容之上，避免被半透明填充盖住。
      foregroundDecoration: stroke <= 0.01
          ? null
          : BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: borderColor, width: stroke),
            ),
      child: glassSurface,
    );

    if (onTap != null) {
      surface = PressableScale(
        onTap: onTap,
        pressedScale: 0.975,
        child: surface,
      );
    }

    if (margin == EdgeInsets.zero) {
      return surface;
    }
    return Padding(padding: margin, child: surface);
  }
}
