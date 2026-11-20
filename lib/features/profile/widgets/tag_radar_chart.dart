import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// 阅读偏好雷达图（六维）。
///
/// 维度固定为内置六个标签：文学 / 热血 / 科幻 / 恋爱 / 运动 / 悬疑，
/// 数值是「带该标签的书籍数量 ÷ 全部藏书数量」，范围 0~1。
/// 用 CustomPaint 直接绘制，不引入任何图表依赖。
class TagRadarChart extends StatelessWidget {
  const TagRadarChart({
    super.key,
    required this.ratios,
    this.size = 236,
  });

  /// 维度名称 → 占比（0~1），顺序即绘制顺序。
  final Map<String, double> ratios;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RadarPainter(
          ratios: ratios,
          size: size,
          brightness: brightness,
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.ratios,
    required this.size,
    required this.brightness,
  });

  final Map<String, double> ratios;
  final double size;
  final Brightness brightness;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final List<MapEntry<String, double>> entries = ratios.entries.toList();
    if (entries.isEmpty) {
      return;
    }

    final Offset center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    // 留出四边文字空间，半径只占画布的 32%。
    final double radius = canvasSize.shortestSide * 0.32;
    final int count = entries.length;
    final double step = math.pi * 2 / count;

    final Color accent = AppColors.accent(brightness);
    final Color grid = AppColors.alpha(AppColors.divider(brightness), 0.9);

    // 1. 同心多边形网格（四层，从内到外逐渐变淡）。
    for (int ring = 1; ring <= 4; ring++) {
      final double ratio = ring / 4;
      final Path path = Path();
      for (int i = 0; i < count; i++) {
        final double angle = -math.pi / 2 + step * i;
        final Offset point = center +
            Offset(math.cos(angle), math.sin(angle)) * (radius * ratio);
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = ring == 4 ? 0.9 : 0.6
          ..color = AppColors.alpha(grid, ring == 4 ? 0.85 : 0.5),
      );
    }

    // 2. 轴线。
    final Paint axisPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = AppColors.alpha(grid, 0.6);
    for (int i = 0; i < count; i++) {
      final double angle = -math.pi / 2 + step * i;
      canvas.drawLine(
        center,
        center + Offset(math.cos(angle), math.sin(angle)) * radius,
        axisPaint,
      );
    }

    // 3. 数据多边形。
    final Path dataPath = Path();
    final List<Offset> points = <Offset>[];
    for (int i = 0; i < count; i++) {
      final double value = entries[i].value.clamp(0.0, 1.0);
      final double angle = -math.pi / 2 + step * i;
      // 最小留 2% 让「零数据」也能看出图形位置，不会缩成一个点。
      final double length = radius * (0.02 + value * 0.98);
      final Offset point =
          center + Offset(math.cos(angle), math.sin(angle)) * length;
      points.add(point);
      if (i == 0) {
        dataPath.moveTo(point.dx, point.dy);
      } else {
        dataPath.lineTo(point.dx, point.dy);
      }
    }
    dataPath.close();

    canvas.drawPath(
      dataPath,
      Paint()..color = AppColors.alpha(accent, 0.16),
    );
    canvas.drawPath(
      dataPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = AppColors.alpha(accent, 0.82),
    );

    // 4. 顶点小圆点。
    for (final Offset point in points) {
      canvas.drawCircle(
        point,
        2.2,
        Paint()..color = AppColors.alpha(accent, 0.92),
      );
    }

    // 5. 维度文字：标签 + 百分比。
    for (int i = 0; i < count; i++) {
      final double angle = -math.pi / 2 + step * i;
      final Offset anchor =
          center + Offset(math.cos(angle), math.sin(angle)) * (radius + 20);

      final TextPainter painter = TextPainter(
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        text: TextSpan(
          children: <InlineSpan>[
            TextSpan(
              text: entries[i].key,
              style: TextStyle(
                fontSize: 9.5,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary(brightness),
              ),
            ),
            TextSpan(
              text: '\n${(entries[i].value * 100).round()}%',
              style: TextStyle(
                fontSize: 8.5,
                letterSpacing: 0.3,
                color: AppColors.textTertiary(brightness),
              ),
            ),
          ],
        ),
      )..layout(maxWidth: 64);

      painter.paint(
        canvas,
        Offset(anchor.dx - painter.width / 2, anchor.dy - painter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) {
    if (oldDelegate.size != size || oldDelegate.brightness != brightness) {
      return true;
    }
    if (oldDelegate.ratios.length != ratios.length) {
      return true;
    }
    for (final String key in ratios.keys) {
      if (oldDelegate.ratios[key] != ratios[key]) {
        return true;
      }
    }
    return false;
  }
}
