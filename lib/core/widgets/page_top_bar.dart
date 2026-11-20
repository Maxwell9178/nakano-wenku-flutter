import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'pressable_scale.dart';
import 'thin_divider.dart';

/// 内页统一顶栏：返回按钮 + 中文标题 + 小号英文标注 + 细分割线。
///
/// 与书架的 [AppTopBar]（软件名 + 署名）区分：这里是二级页面的顶栏。
class PageTopBar extends StatelessWidget {
  const PageTopBar({
    super.key,
    required this.title,
    required this.english,
    this.trailing,
    this.onBack,
    this.padding = const EdgeInsets.fromLTRB(24, 10, 24, 0),
  });

  final String title;
  final String english;
  final Widget? trailing;
  final VoidCallback? onBack;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;

    return Padding(
      padding: padding,
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              PressableScale(
                pressedScale: 0.92,
                onTap: onBack ?? () => Navigator.of(context).maybePop(),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.alpha(AppColors.divider(brightness), 0.9),
                      width: 0.8,
                    ),
                    color: AppColors.alpha(
                        AppColors.surface(brightness), 0.35),
                  ),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    size: 18,
                    color: AppColors.textPrimary(brightness),
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.chineseTitle(brightness)
                          .copyWith(fontSize: 17, letterSpacing: 0.4),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      english.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.englishLabel(brightness, fontSize: 8.2)
                          .copyWith(color: AppColors.textTertiary(brightness)),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          ThinDivider(
            thickness: 0.8,
            color: AppColors.alpha(AppColors.divider(brightness), 0.85),
          ),
        ],
      ),
    );
  }
}
