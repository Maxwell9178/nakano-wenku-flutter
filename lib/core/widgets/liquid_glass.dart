import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../settings/app_settings.dart';
import '../theme/app_colors.dart';
import 'pressable_scale.dart';

/// 液态玻璃容器（全局公共组件）。
///
/// 这一版的材质拆成五层，目标是「看起来真的是一块玻璃」，而不是一块
/// 半透明色块：
///
/// 1. **背景模糊**：BackdropFilter 按设置里的模糊值放大到 0~36 sigma；
/// 2. **玻璃本体**：斜向三层渐变（左上薄、右下厚），叠一层装饰色调膜；
/// 3. **折射高光**：左上角一团柔和的镜面高光 + 一道很淡的斜向光带，
///    模拟玻璃边缘把环境光「折」进来的感觉；
/// 4. **厚边**：外沿 1px 白边由亮到暗做渐变描边，内侧再收一圈细边，
///    形成真实玻璃那种「双线边缘」；
/// 5. **投影**：底部大范围柔和阴影，让玻璃浮在页面上而不是贴上去。
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
    final Color fillTop = AppColors.alpha(baseTint, fillOpacity + 0.12);
    final Color fillMid = AppColors.alpha(baseTint, fillOpacity);
    final Color fillBottom = AppColors.alpha(baseTint, fillOpacity * 0.42);

    final Widget glassSurface = ClipRRect(
      borderRadius: radius,
      child: Stack(
        children: <Widget>[
          // 1. 背景模糊
          if (sigma > 0.4)
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: const SizedBox.expand(),
              ),
            ),

          // 2. 玻璃本体渐变
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[fillTop, fillMid, fillBottom],
                  stops: const <double>[0.0, 0.42, 1.0],
                ),
              ),
            ),
          ),

          // 3. 折射高光：左上角的镜面光团 + 斜向光带
          if (sheen)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.72, -0.92),
                      radius: 1.05,
                      colors: <Color>[
                        AppColors.alpha(Colors.white, isDark ? 0.20 : 0.55),
                        AppColors.alpha(Colors.white, isDark ? 0.05 : 0.16),
                        Colors.transparent,
                      ],
                      stops: const <double>[0.0, 0.34, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          if (sheen)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        AppColors.alpha(Colors.white, isDark ? 0.10 : 0.26),
                        Colors.transparent,
                        Colors.transparent,
                        AppColors.alpha(Colors.white, isDark ? 0.04 : 0.12),
                      ],
                      stops: const <double>[0.0, 0.30, 0.72, 1.0],
                    ),
                  ),
                ),
              ),
            ),

          // 4. 顶部厚度高光 + 底部内阴影
          if (sheen)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        AppColors.alpha(Colors.white, isDark ? 0.18 : 0.50),
                        Colors.transparent,
                        Colors.transparent,
                        AppColors.alpha(Colors.black, isDark ? 0.26 : 0.06),
                      ],
                      stops: const <double>[0.0, 0.14, 0.70, 1.0],
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
                    isDark ? 0.55 : 0.15,
                  ),
                  blurRadius: 32,
                  spreadRadius: -8,
                  offset: const Offset(0, 16),
                ),
              ]
            : null,
      ),
      child: Stack(
        children: <Widget>[
          glassSurface,

          // 5. 玻璃边缘：外侧亮到暗的渐变描边 + 内侧细边
          if (sheen && stroke > 0.01)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _GlassEdgePainter(
                    cornerRadius: borderRadius,
                    stroke: stroke,
                    isDark: isDark,
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

/// 玻璃边缘：外圈用「左上亮白 → 右下灰白」的渐变描边，
/// 内圈再补一条更细的暗边，形成真实玻璃的双线厚度。
class _GlassEdgePainter extends CustomPainter {
  const _GlassEdgePainter({
    required this.cornerRadius,
    required this.stroke,
    required this.isDark,
  });

  final double cornerRadius;
  final double stroke;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    // 外圈贴边描边，内圈再往里收一圈，形成双线玻璃边缘。
    final RRect outer = RRect.fromRectAndRadius(
      rect.deflate(stroke / 2),
      Radius.circular((cornerRadius - stroke / 2).clamp(0.0, 999.0)),
    );

    // 外圈：亮 → 暗
    final Paint outerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          AppColors.alpha(Colors.white, isDark ? 0.62 : 0.96),
          AppColors.alpha(Colors.white, isDark ? 0.22 : 0.55),
          AppColors.alpha(Colors.white, isDark ? 0.08 : 0.30),
        ],
        stops: const <double>[0.0, 0.46, 1.0],
      ).createShader(rect);

    canvas.drawRRect(
      outer.deflate(stroke / 2),
      outerPaint,
    );

    // 内圈：反方向的暗边，让厚度更明显
    final double innerInset = stroke + 0.9;
    if (size.width > innerInset * 2 + 2 && size.height > innerInset * 2 + 2) {
      final RRect inner = RRect.fromRectAndRadius(
        rect.deflate(innerInset + 0.3),
        Radius.circular((cornerRadius - innerInset).clamp(0.0, 999.0)),
      );
      final Paint innerPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..shader = LinearGradient(
          begin: Alignment.bottomRight,
          end: Alignment.topLeft,
          colors: <Color>[
            AppColors.alpha(Colors.white, isDark ? 0.16 : 0.34),
            AppColors.alpha(Colors.black, isDark ? 0.30 : 0.05),
          ],
        ).createShader(rect);
      canvas.drawRRect(inner, innerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GlassEdgePainter oldDelegate) {
    return oldDelegate.cornerRadius != cornerRadius ||
        oldDelegate.stroke != stroke ||
        oldDelegate.isDark != isDark;
  }
}
