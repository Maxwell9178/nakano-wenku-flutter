import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'frosted_glass.dart';
import 'pressable_scale.dart';
import 'thin_divider.dart';

/// 毛玻璃弹窗的统一入口。
///
/// 需求规定弹窗也必须是毛玻璃质感，且动画柔和；如果每个页面各自
/// showDialog + AlertDialog，材质与动画会很快失控，因此统一收敛到这里。
///
/// 用法：
/// ```dart
/// await showGlassDialog<void>(
///   context: context,
///   builder: (BuildContext context) => GlassDialogCard(
///     title: '提示',
///     message: '……',
///     actions: <Widget>[ ... ],
///   ),
/// );
/// ```
Future<T?> showGlassDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool dismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: 'glass-dialog',
    barrierColor: AppColors.alpha(Colors.black, 0.42),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
    ) {
      return builder(context);
    },
    transitionBuilder: (
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
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.965, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// 毛玻璃弹窗卡片内容。
class GlassDialogCard extends StatelessWidget {
  const GlassDialogCard({
    super.key,
    required this.title,
    this.english,
    this.message,
    this.content,
    this.actions = const <Widget>[],
    this.maxWidth = 360,
  });

  /// 中文标题。
  final String title;

  /// 小号英文标注。
  final String? english;

  /// 纯文本正文（与 [content] 二选一）。
  final String? message;

  /// 自定义内容（例如选项列表）。
  final Widget? content;

  final List<Widget> actions;

  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Material(
            color: Colors.transparent,
            child: FrostedGlass(
              borderRadius: 24,
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
              shadows: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: AppTypography.chineseTitle(
                      brightness,
                      fontSize: 19,
                    ),
                  ),
                  if (english != null &&
                      english!.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 7),
                    Text(
                      english!.toUpperCase(),
                      style: AppTypography.englishLabel(
                        brightness,
                        fontSize: 9.5,
                        letterSpacing: 2.6,
                        color: AppColors.textTertiary(brightness),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const ThinDivider(thickness: 0.8),
                  const SizedBox(height: 14),
                  if (message != null)
                    Text(
                      message!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  if (content != null) content!,
                  if (actions.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        for (int i = 0; i < actions.length; i++) ...<Widget>[
                          if (i > 0) const SizedBox(height: 10),
                          actions[i],
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 弹窗内的胶囊按钮（毛玻璃卡片专用，保证弹窗风格自洽）。
class GlassDialogButton extends StatelessWidget {
  const GlassDialogButton({
    super.key,
    required this.label,
    this.onTap,
    this.primary = false,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final Color accent = danger
        ? AppColors.danger
        : (primary
            ? AppColors.accent(brightness)
            : AppColors.textPrimary(brightness));

    return PressableScale(
      onTap: onTap,
      pressedScale: 0.97,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: primary
              ? AppColors.alpha(accent, 0.12)
              : AppColors.alpha(accent, 0.04),
          border: Border.all(
            color: AppColors.alpha(accent, primary ? 0.55 : 0.28),
            width: 0.9,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: danger ? AppColors.danger : accent,
          ),
        ),
      ),
    );
  }
}
