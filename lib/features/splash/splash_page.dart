import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/routing/app_routes.dart';
import '../../core/services/user_profile_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/grid_background.dart';
import '../../core/widgets/thin_divider.dart';

/// 开屏启动页。
///
/// 设计要点（严格按需求）：
/// - 底色跟随主题：深色纯黑、浅色柔和白，两套都铺灰色方格纹理；
/// - 大号加粗、字距宽松的软件名；
/// - 大字与下方小字之间一条细分割线；
/// - 英文署名 MADE BY MAXWELL；
/// - 不提供跳过按钮，真实随机停留 3~5 秒后自动进入后续页面。
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _titleFade;
  late final Animation<double> _titleSlide;
  late final Animation<double> _signatureFade;
  late final Animation<double> _lineGrow;

  Timer? _timer;

  /// 真实的随机停留时长：3 秒起步，最多 5 秒。
  Duration _stayDuration = AppConstants.splashMinDuration;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _titleFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    );
    _titleSlide = Tween<double>(begin: 14, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );
    _lineGrow = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.28, 0.78, curve: Curves.easeOutCubic),
    );
    _signatureFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
    );

    _controller.forward();
    _scheduleExit();
  }

  void _scheduleExit() {
    final int spanMs = AppConstants.splashMaxDuration.inMilliseconds -
        AppConstants.splashMinDuration.inMilliseconds;
    final int extraMs = spanMs <= 0 ? 0 : math.Random().nextInt(spanMs + 1);
    _stayDuration = Duration(
      milliseconds: AppConstants.splashMinDuration.inMilliseconds + extraMs,
    );

    _timer = Timer(_stayDuration, _goNext);
  }

  /// 加载结束后自动跳转：未完成初始化 → 首次初始化页；否则 → 主框架。
  void _goNext() {
    if (!mounted) {
      return;
    }

    final UserProfileController profile = context.read<UserProfileController>();
    final String target =
        profile.onboardingCompleted ? AppRoutes.home : AppRoutes.onboarding;

    Navigator.of(context).pushReplacementNamed(target);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final bool isDark = brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: GridBackground(
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // 软件名：艺术宋体、加粗、宽字距。
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (BuildContext context, Widget? child) {
                        return Opacity(
                          opacity: _titleFade.value,
                          child: Transform.translate(
                            offset: Offset(0, _titleSlide.value),
                            child: child,
                          ),
                        );
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          // 软件名单行展示：窄屏自动等比缩小，绝不折行。
                          SizedBox(
                            width: double.infinity,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                AppConstants.appName,
                                maxLines: 1,
                                softWrap: false,
                                textAlign: TextAlign.center,
                                style: AppTypography.textTheme(brightness)
                                    .displayLarge
                                    ?.copyWith(
                                      fontSize: 36,
                                      letterSpacing: 3.2,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          // 大字与小字之间的分割线（可见的浅灰）。
                          AnimatedBuilder(
                            animation: _lineGrow,
                            builder: (BuildContext context, Widget? child) {
                              return SizedBox(
                                width: 132 * _lineGrow.value,
                                child: ThinDivider(
                                  thickness: 0.9,
                                  width: double.infinity,
                                  color: AppColors.alpha(
                                    isDark ? Colors.white : Colors.black,
                                    isDark ? 0.34 : 0.26,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 18),
                          FadeTransition(
                            opacity: _signatureFade,
                            child: Text(
                              AppConstants.signature.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: AppTypography.englishLabel(
                                brightness,
                                fontSize: 10.5,
                                letterSpacing: 3.4,
                                color: AppColors.textSecondary(brightness),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
