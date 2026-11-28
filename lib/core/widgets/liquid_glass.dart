import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../settings/app_settings.dart';
import '../theme/app_colors.dart';
import 'pressable_scale.dart';

/// 液态玻璃容器（全局公共组件）。
///
/// 目标是「一块真的玻璃」，而不是半透明色块，所以材质按真实玻璃的光路分层：
///
/// 1. **背景模糊**：BackdropFilter，强度由设置里的模糊值决定（0~36 sigma）；
/// 2. **边缘折射带**：贴着圆角内缘再叠一层更强模糊 + 提亮，
///    模拟厚玻璃边缘把背景「折弯」的感觉 —— 这是液态感的主要来源；
/// 3. **玻璃本体**：斜向渐变 + 装饰色调膜，左上薄、右下厚；
/// 4. **液面反光**：左上水滴状高光、斜向流动光带、右下冷反射、
///    以及沿圆角的月牙形镜面（`_LiquidSheenPainter`）；
/// 5. **厚度**：顶部窄高光 + 底部内阴影 + 双层描边（外亮内暗）；
/// 6. **投影**：底部大范围柔和阴影，让玻璃浮起来。
///
/// 模糊、透明度、边框粗细读取全局设置，一处调整全应用一致；
/// 局部可用 [blurSigma] / [opacity] / [borderWidth] 覆盖。
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
    // 液态强度：0 时只剩一层平面玻璃，越大边缘折射与液面反光越明显。
    final double intensity =
        (sheen ? spec.liquidLevel : 0.0).clamp(0.0, 1.0).toDouble();

    final BorderRadius radius = BorderRadius.circular(borderRadius);
    final Color baseTint = tint ?? AppColors.glassTint(brightness);

    // 斜向渐变：左上更亮、右下更薄，模拟玻璃在光下的折射。
    final Color fillTop = AppColors.alpha(baseTint, fillOpacity + 0.14);
    final Color fillMid = AppColors.alpha(baseTint, fillOpacity);
    final Color fillBottom = AppColors.alpha(baseTint, fillOpacity * 0.38);

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

          // 3. 边缘折射：沿内缘再糊一层，背景在边框附近被「放大」的错觉
          if (sheen && sigma > 0.4 && intensity > 0.02)
            Positioned.fill(
              child: IgnorePointer(
                child: ClipPath(
                  clipper: _GlassEdgeBandClipper(
                    radius: borderRadius,
                    bandWidth: (borderRadius * 0.22).clamp(5.0, 16.0) *
                        (0.45 + 1.05 * intensity),
                  ),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(
                      sigmaX: sigma * (1.05 + 1.7 * intensity),
                      sigmaY: sigma * (1.05 + 1.7 * intensity),
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[
                            AppColors.alpha(
                              Colors.white,
                              isDark ? 0.16 : 0.34,
                            ),
                            AppColors.alpha(
                              Colors.white,
                              isDark ? 0.03 : 0.14,
                            ),
                            AppColors.alpha(
                              Colors.black,
                              isDark ? 0.10 : 0.03,
                            ),
                          ],
                          stops: const <double>[0.0, 0.55, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // 4. 液态反光：光团 + 流动光带 + 月牙镜面
          //
          // 强度来自设置里的「液态效果」，线性映射到这一层的可见度：
          // 每挪动一点滑块，反光和边缘的厚度都会跟着变。
          if (sheen && intensity > 0.02)
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: (0.25 + 0.75 * intensity).clamp(0.0, 1.0),
                  child: CustomPaint(
                    painter: _LiquidSheenPainter(
                      isDark: isDark,
                      // 反光永远用中性白/黑，不掺装饰色，
                      // 避免玻璃边缘被染色成「金边/黄边」。
                      accent: isDark ? Colors.white : Colors.black,
                      cornerRadius: borderRadius,
                    ),
                  ),
                ),
              ),
            ),

          // 5. 顶部厚度高光 + 底部内阴影
          if (sheen)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        AppColors.alpha(Colors.white, isDark ? 0.20 : 0.54),
                        Colors.transparent,
                        Colors.transparent,
                        AppColors.alpha(Colors.black, isDark ? 0.30 : 0.07),
                      ],
                      stops: const <double>[0.0, 0.12, 0.68, 1.0],
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

          // 6. 玻璃边缘：外侧亮到暗的渐变描边 + 内侧细边
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

/// 只保留「边缘一条带」的裁剪器（圆角矩形挖掉中间），
/// 用来把更强模糊的折射层限制在玻璃内缘。
class _GlassEdgeBandClipper extends CustomClipper<Path> {
  const _GlassEdgeBandClipper({required this.radius, required this.bandWidth});

  final double radius;
  final double bandWidth;

  @override
  Path getClip(Size size) {
    final RRect outer = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final RRect inner = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        bandWidth,
        bandWidth,
        (size.width - bandWidth * 2).clamp(0.0, double.infinity),
        (size.height - bandWidth * 2).clamp(0.0, double.infinity),
      ),
      Radius.circular((radius - bandWidth).clamp(0.0, radius)),
    );
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addRRect(outer)
      ..addRRect(inner);
  }

  @override
  bool shouldReclip(covariant _GlassEdgeBandClipper oldClipper) {
    return oldClipper.radius != radius || oldClipper.bandWidth != bandWidth;
  }
}

/// 液态反光层：几段高斯模糊的水滴形高光 + 一段流动光带 + 一弯月牙镜面，
/// 模拟液体在玻璃表面流动时「边缘亮、中间透」的折射。
class _LiquidSheenPainter extends CustomPainter {
  const _LiquidSheenPainter({
    required this.isDark,
    required this.accent,
    required this.cornerRadius,
  });

  final bool isDark;
  final Color accent;
  final double cornerRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    canvas.save();
    canvas.clipRect(rect);

    // 1. 左上角的水滴状光团：最大最亮的一团。
    final Offset poolCenter = Offset(size.width * 0.16, size.height * 0.02);
    final double poolRadius = size.shortestSide * 1.05;
    final Paint pool = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          AppColors.alpha(Colors.white, isDark ? 0.30 : 0.72),
          AppColors.alpha(Colors.white, isDark ? 0.10 : 0.26),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.38, 1.0],
      ).createShader(
        Rect.fromCircle(center: poolCenter, radius: poolRadius),
      );
    canvas.drawCircle(poolCenter, poolRadius, pool);

    // 2. 斜向流动光带：被模糊过的窄条，像液体流动的痕迹。
    final double bandY = size.height * 0.52;
    final Path band = Path()
      ..moveTo(-size.width * 0.12, bandY)
      ..quadraticBezierTo(
        size.width * 0.44,
        bandY - size.height * 0.34,
        size.width * 1.12,
        bandY - size.height * 0.02,
      );
    final Paint bandPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.height * 0.16
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, size.height * 0.09)
      ..shader = LinearGradient(
        colors: <Color>[
          AppColors.alpha(Colors.white, 0),
          AppColors.alpha(Colors.white, isDark ? 0.16 : 0.42),
          AppColors.alpha(Colors.white, 0),
        ],
        stops: const <double>[0.0, 0.5, 1.0],
      ).createShader(rect);
    canvas.drawPath(band, bandPaint);

    // 3. 沿圆角的月牙镜面：贴内缘走一圈，只亮左上那一段，
    //    这是「液体表面张力」最直观的一笔。
    final RRect rim = RRect.fromRectAndRadius(
      rect.deflate(1.4),
      Radius.circular((cornerRadius - 1.4).clamp(0.0, cornerRadius)),
    );
    final Paint rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, 2.2)
      ..shader = SweepGradient(
        startAngle: -2.6,
        endAngle: 1.2,
        colors: <Color>[
          AppColors.alpha(Colors.white, 0),
          AppColors.alpha(Colors.white, isDark ? 0.34 : 0.78),
          AppColors.alpha(Colors.white, 0),
        ],
        stops: const <double>[0.0, 0.42, 1.0],
        transform: GradientRotation(-0.4),
      ).createShader(rect);
    canvas.drawRRect(rim, rimPaint);

    // 4. 右下角的一点冷反射：带一点装饰色调，让玻璃有「厚度」。
    final Offset cornerCenter = Offset(
      size.width * 0.94,
      size.height * 0.96,
    );
    final double cornerRadiusValue = size.shortestSide * 0.8;
    final Paint corner = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          AppColors.alpha(accent, isDark ? 0.26 : 0.20),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(center: cornerCenter, radius: cornerRadiusValue),
      );
    canvas.drawCircle(cornerCenter, cornerRadiusValue, corner);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LiquidSheenPainter oldDelegate) {
    return oldDelegate.isDark != isDark ||
        oldDelegate.accent != accent ||
        oldDelegate.cornerRadius != cornerRadius;
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
          AppColors.alpha(Colors.white, isDark ? 0.86 : 1.0),
          AppColors.alpha(Colors.white, isDark ? 0.26 : 0.62),
          AppColors.alpha(Colors.white, isDark ? 0.08 : 0.32),
        ],
        stops: const <double>[0.0, 0.46, 1.0],
      ).createShader(rect);

    canvas.drawRRect(outer, outerPaint);

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
            AppColors.alpha(Colors.white, isDark ? 0.18 : 0.36),
            AppColors.alpha(Colors.black, isDark ? 0.34 : 0.06),
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
