import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// 阅读设置里使用的液态玻璃滑块。
///
/// 需求约定：可滑动控件在按下时滑块要放大并带液态玻璃质感，
/// 松手后回到常规大小。这里用渐变 + 高光 + 柔和阴影模拟玻璃，
/// 避免在滑块这种小控件上叠加 BackdropFilter 造成性能浪费。
class GlassSlider extends StatefulWidget {
  const GlassSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.accent,
    this.enabled = true,
  });

  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final Color? accent;
  final bool enabled;

  @override
  State<GlassSlider> createState() => _GlassSliderState();
}

class _GlassSliderState extends State<GlassSlider> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final Color accent = widget.accent ?? AppColors.accent(brightness);
    final Color trackColor = AppColors.alpha(
      AppColors.textPrimary(brightness),
      0.10,
    );
    final double range = widget.max - widget.min;
    final double ratio = range <= 0
        ? 0
        : ((widget.value - widget.min) / range).clamp(0.0, 1.0).toDouble();

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        const double thumbSize = 16;
        final double travel = (width - thumbSize).clamp(0.0, width).toDouble();

        void update(double dx) {
          if (!widget.enabled || width <= 0) {
            return;
          }
          final double nextRatio = (dx / width).clamp(0.0, 1.0).toDouble();
          final double next = widget.min + nextRatio * range;
          widget.onChanged(next);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (DragStartDetails details) {
            setState(() => _pressed = true);
            update(details.localPosition.dx);
          },
          onHorizontalDragUpdate: (DragUpdateDetails details) {
            update(details.localPosition.dx);
          },
          onHorizontalDragEnd: (DragEndDetails details) {
            setState(() => _pressed = false);
          },
          onHorizontalDragCancel: () {
            setState(() => _pressed = false);
          },
          onTapDown: (TapDownDetails details) {
            setState(() => _pressed = true);
            update(details.localPosition.dx);
          },
          onTapUp: (TapUpDetails details) {
            setState(() => _pressed = false);
          },
          onTapCancel: () {
            setState(() => _pressed = false);
          },
          child: SizedBox(
            height: 30,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: <Widget>[
                // 轨道
                Container(
                  height: 4,
                  margin: const EdgeInsets.only(right: 2),
                  decoration: BoxDecoration(
                    color: trackColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // 已选进度
                Container(
                  height: 4,
                  width: 2 + travel * ratio,
                  decoration: BoxDecoration(
                    color: AppColors.alpha(accent, 0.78),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // 玻璃滑块
                Positioned(
                  left: travel * ratio,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    width: _pressed ? thumbSize + 8 : thumbSize,
                    height: _pressed ? thumbSize + 8 : thumbSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          AppColors.alpha(Colors.white, 0.92),
                          AppColors.alpha(accent, 0.92),
                        ],
                      ),
                      border: Border.all(
                        color: AppColors.alpha(Colors.white, 0.75),
                        width: 1.1,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: AppColors.alpha(accent, 0.32),
                          blurRadius: _pressed ? 18 : 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
