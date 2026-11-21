import 'package:flutter/material.dart';

import '../settings/app_settings.dart';

/// 统一的页面转场。
///
/// 需求：所有页面切换必须平缓柔和，禁止生硬跳变。
/// 这里使用「淡入 + 轻微上移」的组合，没有横向滑动，观感更安静。
///
/// 「减少动画」开启时转场时长压到 0，页面直接呈现；
/// 30Hz 帧率下转场放慢，让低帧率设备上的位移更连续。
class SoftPageRoute<T> extends PageRouteBuilder<T> {
  SoftPageRoute({
    required WidgetBuilder builder,
    super.settings,
  }) : super(
          // 全项目都是普通页面推入，不需要系统「全屏对话框」样式。
          fullscreenDialog: false,
          transitionDuration: AppSettingsController.motion(460),
          reverseTransitionDuration: AppSettingsController.motion(320),
          pageBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) {
            return builder(context);
          },
          transitionsBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child,
          ) {
            final Animation<double> curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );

            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.035),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        );
}
