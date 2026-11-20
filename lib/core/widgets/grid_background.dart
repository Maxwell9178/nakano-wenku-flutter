import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 灰色网格纹理绘制器。
///
/// 全局所有页面底色都叠加这层网格：线条极细、对比度极低，
/// 只提供纸质纹理感，不干扰文字阅读。
class GridPainter extends CustomPainter {
  const GridPainter({
    required this.lineColor,
    this.step = 46,
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

    double x = 0;
    while (x <= size.width) {
      // +0.5 让 1px 线落在像素中心，避免发虚。
      canvas.drawLine(Offset(x + 0.5, 0), Offset(x + 0.5, size.height), paint);
      x += step;
    }

    double y = 0;
    while (y <= size.height) {
      canvas.drawLine(Offset(0, y + 0.5), Offset(size.width, y + 0.5), paint);
      y += step;
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
    this.step = 46,
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
