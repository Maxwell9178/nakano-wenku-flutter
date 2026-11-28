import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_colors.dart';

/// 书架底部的手动滑动条。
///
/// 3D 书架一次最多滑三本，书多了要滑很多次才能转一圈；这条滑动条让
/// 用户可以直接把书架拖到任意位置。书架本身是无限循环的，所以滑块
/// 滑到最右端松手后会回卷到最左侧（视觉上仍是同一本书，位置从 0 开始）。
///
/// 材质沿用全局液态玻璃：轨道是磨砂玻璃，滑块是带高光与投影的胶囊，
/// 按下时略微放大并有轻微高光增强，松手回弹。
class ShelfScrubber extends StatefulWidget {
  const ShelfScrubber({
    super.key,
    required this.fraction,
    required this.onScrub,
    required this.onWrap,
  });

  /// 书架当前在一轮里的位置（0~1），由书架回调驱动。
  final double fraction;

  /// 拖动过程中实时回调（0~1）。
  final ValueChanged<double> onScrub;

  /// 滑到最右端松手：让书架回卷到开头。
  final VoidCallback onWrap;

  @override
  State<ShelfScrubber> createState() => _ShelfScrubberState();
}

class _ShelfScrubberState extends State<ShelfScrubber> {
  static const double _thumbWidth = 34;
  static const double _thumbHeight = 18;
  static const double _trackHeight = 10;

  /// 拖动中的临时值；为 null 表示未拖动，跟随外部 [ShelfScrubber.fraction]。
  double? _dragging;

  bool _pressed = false;

  double get _value => (_dragging ?? widget.fraction).clamp(0.0, 1.0);

  void _handleDrag(double dx, double travel) {
    if (travel <= 0) {
      return;
    }
    final double raw = ((dx - _thumbWidth / 2) / travel).clamp(0.0, 1.0);
    setState(() => _dragging = raw);
    widget.onScrub(raw);
  }

  void _handleEnd() {
    final double value = _value;
    final bool wrap = value >= 0.985;
    setState(() {
      _dragging = null;
      _pressed = false;
    });
    if (wrap) {
      HapticFeedback.mediumImpact();
      widget.onWrap();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final bool isDark = brightness == Brightness.dark;
    final Color accent = AppColors.accent(brightness);
    final Duration morph = AppSettingsController.motion(180);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final double travel = (width - _thumbWidth).clamp(0.0, double.infinity);
        final double thumbLeft = travel * _value;

        return SizedBox(
          height: 34,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (DragStartDetails details) {
              setState(() => _pressed = true);
              HapticFeedback.selectionClick();
              _handleDrag(details.localPosition.dx, travel);
            },
            onHorizontalDragUpdate: (DragUpdateDetails details) {
              _handleDrag(details.localPosition.dx, travel);
            },
            onHorizontalDragEnd: (DragEndDetails details) => _handleEnd(),
            onHorizontalDragCancel: _handleEnd,
            onTapDown: (TapDownDetails details) {
              setState(() => _pressed = true);
              _handleDrag(details.localPosition.dx, travel);
            },
            onTapUp: (TapUpDetails details) => _handleEnd(),
            onTapCancel: _handleEnd,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: <Widget>[
                // 轨道：磨砂玻璃 + 内嵌细线，两端留出滑块半径的空白。
                Positioned(
                  left: _thumbWidth / 2,
                  right: _thumbWidth / 2,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: SizedBox(
                      height: _trackHeight,
                      child: Stack(
                        children: <Widget>[
                          if (AppSettingsController.disableMotion == false)
                            Positioned.fill(
                              child: BackdropFilter(
                                filter: ui.ImageFilter.blur(
                                  sigmaX: 14,
                                  sigmaY: 14,
                                ),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppColors.alpha(
                                  isDark ? Colors.white : Colors.black,
                                  isDark ? 0.10 : 0.07,
                                ),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  width: 0.8,
                                  color: AppColors.alpha(
                                    Colors.white,
                                    isDark ? 0.24 : 0.55,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // 已走过的一段：淡淡的高亮，提示当前位置。
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            width: (width - _thumbWidth) * _value + 2,
                            child: ColoredBox(
                              color: AppColors.alpha(accent, 0.30),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 滑块：胶囊玻璃，按下放大并加高光。
                Positioned(
                  left: thumbLeft,
                  child: AnimatedContainer(
                    duration: morph,
                    curve: Curves.easeOutCubic,
                    width: _thumbWidth,
                    height: _pressed ? _thumbHeight + 6 : _thumbHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          AppColors.alpha(Colors.white, isDark ? 0.92 : 1.0),
                          AppColors.alpha(accent, 0.88),
                        ],
                      ),
                      border: Border.all(
                        width: 1,
                        color: AppColors.alpha(Colors.white, 0.85),
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: AppColors.alpha(
                            Colors.black,
                            isDark ? 0.45 : 0.22,
                          ),
                          blurRadius: _pressed ? 16 : 10,
                          offset: const Offset(0, 3),
                        ),
                        BoxShadow(
                          color:
                              AppColors.alpha(accent, _pressed ? 0.45 : 0.26),
                          blurRadius: _pressed ? 18 : 10,
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
