import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 通用细分割线。
///
/// 需求规定：页面分割元素统一使用细线条，部分位置可酌情增加装饰线。
/// 因此所有分割线都走这个组件，保证线宽、颜色、渐变规则一致。
class ThinDivider extends StatelessWidget {
  const ThinDivider({
    super.key,
    this.width,
    this.thickness = 0.8,
    this.color,
    this.margin = EdgeInsets.zero,
    this.gradient,
  });

  /// 渐变装饰线（两端淡出），用于标题下方的短线。
  const ThinDivider.gradient({
    super.key,
    this.width,
    this.thickness = 0.8,
    this.color,
    this.margin = EdgeInsets.zero,
    this.gradient,
  });

  /// 线宽；为 null 时占满父级宽度。
  final double? width;

  /// 线粗，默认 0.8（发丝线）。
  final double thickness;

  /// 线条颜色；为 null 时取主题分割线颜色。
  final Color? color;

  final EdgeInsetsGeometry margin;

  /// 渐变填充，优先于 [color]。
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final Color lineColor = color ?? AppColors.divider(brightness);

    return Padding(
      padding: margin,
      child: Container(
        width: width,
        height: thickness,
        decoration: BoxDecoration(
          color: gradient == null ? lineColor : null,
          gradient: gradient,
        ),
      ),
    );
  }
}

/// 标题下方的装饰短线：中间实、两端淡出。
class AccentShortLine extends StatelessWidget {
  const AccentShortLine({
    super.key,
    this.width = 38,
    this.thickness = 1.0,
    this.alignment = Alignment.centerLeft,
  });

  final double width;
  final double thickness;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final Color accent = AppColors.accent(brightness);

    return Align(
      alignment: alignment,
      child: Container(
        width: width,
        height: thickness,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              AppColors.alpha(accent, 0.9),
              AppColors.alpha(accent, 0.15),
            ],
          ),
        ),
      ),
    );
  }
}
