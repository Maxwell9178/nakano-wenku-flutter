import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 灰色网格纹理绘制器。
///
/// 全局所有页面底色都叠加这层网格：线条极细、对比度极低，
/// 只提供纸质纹理感，不干扰文字阅读。
class GridPainter extends CustomPainter {
  const GridPainter({
    required this.lineColor,
    this.step = 28,
    this.strokeWidth = 1.0,
  });

  final Color lineColor;
  final double step;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (step <= 1) {
      return;
    }
    final Paint paint = Paint()
      ..color = lineColor
      ..strokeWidth = strokeWidth
      ..isAntiAlias = false;

    // 以画布中心为原点向两侧铺开：中心永远落着一条线，
    // 页面左右/上下留白因此始终对称（之前从 0 开始画，右边和下边会
    // 剩下一条不到一格的空边，看起来就是「网格偏心」）。
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    final int cols = (size.width / (2 * step)).ceil() + 1;
    final int rows = (size.height / (2 * step)).ceil() + 1;

    for (int i = -cols; i <= cols; i++) {
      // +0.5 让 1px 线落在像素中心，避免发虚。
      final double x = centerX + i * step + 0.5;
      if (x < 0 || x > size.width) {
        continue;
      }
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (int j = -rows; j <= rows; j++) {
      final double y = centerY + j * step + 0.5;
      if (y < 0 || y > size.height) {
        continue;
      }
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor ||
        oldDelegate.step != step ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

/// 带网格纹理的页面背景容器。
///
/// 用法：作为页面最底层容器包裹内容即可，颜色自动跟随主题。
class GridBackground extends StatelessWidget {
  const GridBackground({
    super.key,
    required this.child,
    this.step = 28,
    this.showWash = true,
  });

  final Widget child;

  /// 网格间距（逻辑像素）。
  final double step;

  /// 是否叠加极淡的辅助色光晕，用于制造色彩层次。
  final bool showWash;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;

    return Stack(
      children: <Widget>[
        // 1. 底色
        Positioned.fill(
          child: ColoredBox(color: AppColors.background(brightness)),
        ),

        // 2. 顶部/底部光晕，避免大块纯色显得单调
        if (showWash)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      AppColors.alpha(
                        AppColors.secondary(brightness),
                        brightness == Brightness.dark ? 0.05 : 0.045,
                      ),
                      Colors.transparent,
                      AppColors.alpha(
                        AppColors.accent(brightness),
                        brightness == Brightness.dark ? 0.05 : 0.04,
                      ),
                    ],
                    stops: const <double>[0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          ),

        // 3. 网格纹理
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: GridPainter(
                  lineColor: AppColors.gridLine(brightness),
                  step: step,
                ),
              ),
            ),
          ),
        ),

        // 4. 页面内容
        Positioned.fill(child: child),
      ],
    );
  }
}
