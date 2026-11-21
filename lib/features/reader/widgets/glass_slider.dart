import 'package:flutter/material.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_colors.dart';

/// 液态玻璃滑块（全局公共组件）。
///
/// 需求：可滑动控件按下时滑块放大，并呈现液态玻璃效果；
/// 拖动过程中参数变化必须肉眼可辨，不能「拖了没反应」。
///
/// 第一轮重写：
/// - 按下时滑块由 16 圆形「形变」为 30×22 的液态胶囊，松手回弹；
/// - 拖动时滑块外圈出现发光，轨道已选段加粗并带渐变；
/// - 关闭动画开关后形变立即到位，不做过渡。
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
  final ValueChanged<double>? onChanged;
  final Color? accent;
  final bool enabled;

  @override
  State<GlassSlider> createState() => _GlassSliderState();
}

class _GlassSliderState extends State<GlassSlider> {
  bool _pressed = false;

  double get _range =>
      (widget.max - widget.min).abs() < 0.0001 ? 1.0 : widget.max - widget.min;

  double get _ratio =>
      ((widget.value - widget.min) / _range).clamp(0.0, 1.0).toDouble();

  void _emit(double localX, double width) {
    if (!widget.enabled || widget.onChanged == null) {
      return;
    }
    const double thumbSize = 16;
    final double travel = (width - thumbSize).clamp(1.0, double.infinity);
    final double ratio = ((localX - thumbSize / 2) / travel).clamp(0.0, 1.0);
    widget.onChanged!(widget.min + ratio * _range);
  }

  void _setPressed(bool value) {
    if (_pressed == value || !widget.enabled) {
      return;
    }
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final bool isDark = brightness == Brightness.dark;
    final Color accent = widget.accent ?? AppColors.accent(brightness);
    final Color trackColor = AppColors.alpha(
      AppColors.textPrimary(brightness),
      0.12,
    );
    final Duration morph = AppSettingsController.disableMotion
        ? Duration.zero
        : const Duration(milliseconds: 180);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final double travel = (width - 16).clamp(1.0, double.infinity);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (TapDownDetails d) {
            _setPressed(true);
            _emit(d.localPosition.dx, width);
          },
          onTapUp: (TapUpDetails d) {
            _setPressed(false);
            _emit(d.localPosition.dx, width);
          },
          onTapCancel: () => _setPressed(false),
          onHorizontalDragStart: (DragStartDetails d) {
            _setPressed(true);
            _emit(d.localPosition.dx, width);
          },
          onHorizontalDragUpdate: (DragUpdateDetails d) =>
              _emit(d.localPosition.dx, width),
          onHorizontalDragEnd: (DragEndDetails d) => _setPressed(false),
          onHorizontalDragCancel: () => _setPressed(false),
          child: SizedBox(
            height: 34,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: <Widget>[
                // 轨道
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: trackColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // 已选进度：按下时更粗、更亮
                AnimatedContainer(
                  duration: morph,
                  curve: Curves.easeOutCubic,
                  width: 16 / 2 + travel * _ratio,
                  height: _pressed ? 6 : 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: LinearGradient(
                      colors: <Color>[
                        AppColors.alpha(accent, _pressed ? 0.95 : 0.78),
                        AppColors.alpha(accent, _pressed ? 0.65 : 0.45),
                      ],
                    ),
                    boxShadow: _pressed
                        ? <BoxShadow>[
                            BoxShadow(
                              color: AppColors.alpha(accent, 0.35),
                              blurRadius: 12,
                            ),
                          ]
                        : null,
                  ),
                ),
                // 液态滑块：按下时横向拉伸成胶囊
                Positioned(
                  left: travel * _ratio,
                  child: AnimatedContainer(
                    duration: morph,
                    curve: Curves.easeOutCubic,
                    width: _pressed ? 30 : 16,
                    height: _pressed ? 22 : 16,
                    transform: Matrix4.translationValues(
                      _pressed ? -7 : 0,
                      0,
                      0,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(_pressed ? 11 : 8),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          AppColors.alpha(Colors.white, isDark ? 0.95 : 0.98),
                          AppColors.alpha(accent, _pressed ? 0.95 : 0.75),
                        ],
                      ),
                      border: Border.all(
                        color: AppColors.alpha(
                          Colors.white,
                          isDark ? 0.55 : 0.95,
                        ),
                        width: 1.1,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: AppColors.alpha(
                            isDark ? Colors.black : const Color(0xFF3A3A36),
                            isDark ? 0.55 : 0.22,
                          ),
                          blurRadius: _pressed ? 16 : 10,
                          offset: const Offset(0, 4),
                        ),
                        if (_pressed)
                          BoxShadow(
                            color: AppColors.alpha(accent, 0.45),
                            blurRadius: 22,
                            spreadRadius: 1,
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
