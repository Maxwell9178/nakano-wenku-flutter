import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../settings/app_settings.dart';
import '../theme/app_colors.dart';
import 'pressable_scale.dart';

/// 液态玻璃容器（全局公共组件）。
///
/// 第一轮重写要点：
/// 1. 模糊区间放大到 0~28 sigma，滑块从头拖到尾差异肉眼可辨；
/// 2. 底色改为「斜向渐变 + 顶部高光 + 底部内阴影 + 二次描边」四层，
///    让玻璃有厚度，而不是一块半透明色块；
/// 3. 描边只用白色 / 浅灰，不再出现任何金色。
///
/// 模糊强度、透明度、边框粗细读取全局设置，一处调整、全应用一致；
/// 局部需要特殊材质时可用 [blurSigma] / [opacity] / [borderWidth] 覆盖。
class LiquidGlass extends StatelessWidget {
  const LiquidGlass({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.onLongPress,
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

  /// 可选的第二次交互（例如长按）。
  final VoidCallback? onLongPress;

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
    final double fillOpacity =
        (opacity ?? spec.liquidTintOpacity).clamp(0.0, 1.0).toDouble();
    final double stroke = sheen ? (borderWidth ?? spec.borderWidth) : 0.0;

    final BorderRadius radius = BorderRadius.circular(borderRadius);
    final Color baseTint = tint ?? AppColors.glassTint(brightness);

    // 斜向渐变：左上更亮、右下更薄，模拟玻璃在光下的折射。
    final Color fillTop = AppColors.alpha(baseTint, (fillOpacity + 0.10));
    final Color fillMid = AppColors.alpha(baseTint, fillOpacity);
    final Color fillBottom = AppColors.alpha(baseTint, fillOpacity * 0.48);

    // 描边：深色模式偏亮，浅色模式用近白高光。
    final Color borderColor = AppColors.alpha(
      Colors.white,
      isDark ? 0.30 : 0.80,
    );
    final Color innerEdge = AppColors.alpha(
      isDark ? Colors.black : Colors.white,
      isDark ? 0.35 : 0.55,
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
                  colors: <Color>[fillTop, fillMid, fillBottom],
                  stops: const <double>[0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),

          // 顶部高光带 + 底部内阴影：制造玻璃厚度。
          if (sheen)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        AppColors.alpha(Colors.white, isDark ? 0.16 : 0.42),
                        AppColors.alpha(Colors.white, isDark ? 0.02 : 0.10),
                        Colors.transparent,
                        AppColors.alpha(Colors.black, isDark ? 0.22 : 0.05),
                      ],
                      stops: const <double>[0.0, 0.12, 0.55, 1.0],
                    ),
                  ),
                ),
              ),
            ),

          // 斜向反光（第二层折射）
          if (sheen)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        AppColors.alpha(Colors.white, isDark ? 0.12 : 0.30),
                        Colors.transparent,
                        AppColors.alpha(Colors.white, isDark ? 0.03 : 0.10),
                      ],
                      stops: const <double>[0.0, 0.38, 1.0],
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
                    isDark ? Colors.black : const Color(0xFF3C3C38),
                    isDark ? 0.56 : 0.16,
                  ),
                  blurRadius: 28,
                  spreadRadius: -6,
                  offset: const Offset(0, 14),
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
      child: Stack(
        children: <Widget>[
          glassSurface,
          // 内圈描边：与外侧白边形成双线玻璃边缘。
          if (sheen && stroke > 0.01)
            Positioned.fill(
              child: IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.all(1.2),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        (borderRadius - 1.2).clamp(0.0, borderRadius),
                      ),
                      border: Border.all(color: innerEdge, width: 0.6),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (onTap != null || onLongPress != null) {
      surface = PressableScale(
        onTap: onTap,
        onLongPress: onLongPress,
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
