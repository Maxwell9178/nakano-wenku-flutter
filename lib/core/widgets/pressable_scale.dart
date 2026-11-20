import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 全局按钮点击反馈。
///
/// 需求：按钮被点击时先向内微缩，随后回弹，再执行页面跳转等业务逻辑；
/// 可滑动控件按下时滑块放大并呈现液态玻璃效果。
///
/// 这里把「内缩 + 回弹 + 轻触觉反馈」封装成通用包装器，
/// 后续所有自定义按钮、卡片、列表条目统一使用，避免交互手感不一致。
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.94,
    this.enabled = true,
    this.hapticFeedback = true,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// 按下时缩小到的比例（1.0 为不缩放）。
  final double pressedScale;

  final bool enabled;

  /// 是否触发轻微震动反馈。
  final bool hapticFeedback;

  final HitTestBehavior behavior;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _handleTapDown(TapDownDetails details) {
    if (!widget.enabled) {
      return;
    }
    setState(() => _pressed = true);
    if (widget.hapticFeedback) {
      HapticFeedback.lightImpact();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (!_pressed) {
      return;
    }
    setState(() => _pressed = false);
  }

  void _handleTapCancel() {
    if (!_pressed) {
      return;
    }
    setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final bool interactive =
        widget.enabled && (widget.onTap != null || widget.onLongPress != null);

    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: interactive ? _handleTapDown : null,
      onTapUp: interactive ? _handleTapUp : null,
      onTapCancel: interactive ? _handleTapCancel : null,
      onTap: interactive ? widget.onTap : null,
      onLongPress: interactive ? widget.onLongPress : null,
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        // 按下快、回弹慢且带一点过冲，形成「液态」手感。
        duration: _pressed
            ? const Duration(milliseconds: 110)
            : const Duration(milliseconds: 320),
        curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}
