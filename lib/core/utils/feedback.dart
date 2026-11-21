import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../settings/app_settings.dart';
import '../theme/app_colors.dart';

/// 统一的轻量提示（浮动提示条，从屏幕顶部滑入）。
///
/// 需求：提示弹窗此前从底部弹出，需要改为「顶部滑入 + 平滑下滑」，
/// 禁止瞬间闪现；项目同时要求「网络差/失败不要弹报错弹窗打扰用户」，
/// 因此所有可恢复的提示都走这个入口，保持克制。
OverlayEntry? _currentToast;
Timer? _currentTimer;

void showSoftMessage(BuildContext context, String message) {
  final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) {
    return;
  }

  _dismissCurrentToast();

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (BuildContext ctx) => _TopToast(
      message: message,
      onDone: () {
        if (_currentToast == entry) {
          _currentToast = null;
        }
        if (entry.mounted) {
          entry.remove();
        }
      },
    ),
  );

  _currentToast = entry;
  overlay.insert(entry);

  // 兜底：即使动画回调异常，也要在 4 秒后回收，避免提示条永久停留。
  _currentTimer =
      Timer(const Duration(milliseconds: 4000), _dismissCurrentToast);
}

void _dismissCurrentToast() {
  _currentTimer?.cancel();
  _currentTimer = null;
  final OverlayEntry? entry = _currentToast;
  _currentToast = null;
  if (entry != null && entry.mounted) {
    entry.remove();
  }
}

class _TopToast extends StatefulWidget {
  const _TopToast({required this.message, required this.onDone});

  final String message;
  final VoidCallback onDone;

  @override
  State<_TopToast> createState() => _TopToastState();
}

class _TopToastState extends State<_TopToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppSettingsController.disableMotion
        ? const Duration(milliseconds: 120)
        : const Duration(milliseconds: 360),
    reverseDuration: AppSettingsController.disableMotion
        ? const Duration(milliseconds: 100)
        : const Duration(milliseconds: 260),
  );

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, -1.4),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );

  Timer? _holdTimer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller.forward().whenComplete(() {
      _holdTimer = Timer(const Duration(milliseconds: 2100), _close);
    });
  }

  Future<void> _close() async {
    if (_closing) {
      return;
    }
    _closing = true;
    await _controller.reverse();
    widget.onDone();
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final bool isDark = brightness == Brightness.dark;
    final double topInset = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topInset + 10,
      left: 20,
      right: 20,
      child: IgnorePointer(
        child: SlideTransition(
          position: _slide,
          child: FadeTransition(
            opacity: _fade,
            child: Material(
              color: Colors.transparent,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.alpha(
                          isDark ? const Color(0xFF1B1B1B) : Colors.white,
                          isDark ? 0.92 : 0.97,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.alpha(
                            isDark ? Colors.white : Colors.black,
                            isDark ? 0.24 : 0.10,
                          ),
                          width: 0.8,
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: AppColors.alpha(Colors.black, 0.18),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.info_outline_rounded,
                            size: 15,
                            color: AppColors.alpha(
                              AppColors.textSecondary(brightness),
                              0.9,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              widget.message,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.35,
                                letterSpacing: 0.2,
                                color: AppColors.textPrimary(brightness),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
